# PurpleWiki::Archive::UseMod
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2003.  All rights reserved.
#
# This file is part of PurpleWiki.  PurpleWiki is derived from:
#
#   UseModWiki v0.92          (c) Clifford A. Adams 2000-2001
#   AtisWiki v0.3             (c) Markus Denker 1998
#   CVWiki CVS-patches        (c) Peter Merel 1997
#   The Original WikiWikiWeb  (c) Ward Cunningham
#
# PurpleWiki is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

package PurpleWiki::Archive::UseMod;

use strict;
use base 'PurpleWiki::Archive::Base';

use PurpleWiki::Misc;
use PurpleWiki::UseMod::Database;
use PurpleWiki::Config;
use PurpleWiki::UseMod::Section;
use PurpleWiki::UseMod::KeptRevision;
use PurpleWiki::Search::Result;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Archive::Sequence;

# defaults for Text Based data structure
my $DATA_VERSION = 3;            # the data format version

our $fs = "\xb3";
our $fs1 = "\xb31";
our $fs2 = "\xb32";
our $fs3 = "\xb33";

sub new {
  my $proto = shift;
  my $config;
  $config = shift if (ref($_[0]) eq "PurpleWiki::Config");
  my %args = @_;
  my $class = ref($proto) || $proto;
  my $self = {};

  my $datadir;
  if ($config) {
    $datadir = $config->DataDir;
    $self->{pagedir} = $config->PageDir;
    $self->{rcfile} = $config->RcFile;
    $self->{keepdays} = $config->KeepDays;
    $self->{keepdir} = $config->KeepDir;
    $self->{tempdir} = $config->TempDir;
    $self->{lockdir} = $config->LockDir;
    $self->{sequrl} = $config->RemoteSequenceURL;
    $self->{seqdir} = $config->LocalSequenceDir;
  } else {
    my $x;
    $datadir = $args{DataDir};
    $self->{seqdir} = (defined($x=$args{SequenceDir})) ? $x : $datadir;
  }
  $self->{pagedir} = $args{PageDir} || "$datadir/page"
      unless defined($self->{pagedir});
  $self->{keepdir} = $args{KeepDir} || "$datadir/keep"
      unless defined($self->{keepdir});
  $self->{rcfile} = $args{RcFile} || "$datadir/rclog"
      unless defined($self->{rcfile});
  $self->{tempdir} = $args{TempDir} || "$datadir/temp"
      unless defined($self->{tempdir});
  $self->{lockdir} = $args{LockDir} || "$self->{tempdir}/lock"
      unless defined($self->{lockdir});
  $self->{seqdir} = $datadir unless ($self->{seqdir});

  if ($args{create} && !-d $datadir) {
      mkdir $datadir;
  }
  if (!-d $datadir) {
      use Carp;
      Carp::confess "No datadir $datadir\n";
  }

  bless $self, $class;
  $self;
}

sub getPage {
  my $self = shift;
  my $id = shift;
  my $rev = shift;
  my $page = $self->_openPage($id);
  $page->{pages} = $self;
  $page->{selectrevision} = $rev if $rev;
  $page;
}

# $pages->putPage(<named args>)
# The following named args are expected:
#   pageId             Page idendifier for database (no spaces, '/' ok)
#   tree               Parsed representation of the wikitext
#   userId             User who made the change
#   changeSummary      Comment on the change
#   host               Host that made the change
#   oldrev (optional)  The revision this change was based on, if present it
#                      can fail (return "Conflict") if it doesn't match the
#                      current revision.
#   
sub putPage {
  my $self = shift;
  my %args = @_;
  my $tree = $args{tree};
  return "No Data" unless (defined($tree));
  my $contents = $tree->view('wikitext');
  $contents .= "\n"  unless (substr($contents, -1) eq "\n");
  my $host = $args{host} || $ENV{REMOTE_ADDR};

  my $id = $args{pageId};
  my $now = time;
  $self->_requestLock();

  # Success, but don't do anything if no change
  my $page = $self->_openPage($id);
  my $old = $page->_getText();
  return "" if ($old eq $contents);

  # Fail on detecting edit conflicts
  if (($page->getRevision > 0) && ($args{oldrev} != $page->getRevision())) {
    # conflict detected, release the lock and exit with negative status
    $self->_releaseLock();
#print STDERR "Conflict $id\n";
    return "Conflict";
  }
  my $section = $page->_getSection();
  my $userId = $args{userId};

  $page = PurpleWiki::Archive::ModPage->new(
                 pages => $self,
                 id => $id,
                 ts => $now,
                 text_default => $section,
                 userid => $userId );

  my $keptRevision = new PurpleWiki::UseMod::KeptRevision($self, id => $id);
  my $text = $section->getText();

  my $url = $args{url};
  if ($url) {
      &PurpleWiki::Archive::Sequence::updateNIDs($self, $url, $tree)
      && ($contents = $tree->view('wikitext'));
  }

  $contents =~ s/$fs//g;
  $args{changeSummary} ||= '';
  $args{changeSummary} =~ s/$fs//g;
  $text->setText($contents);
  $text->setNewAuthor(1);
  $text->setSummary($args{changeSummary});
  $section->setHost($host);
  my $newRev = $page->getRevision() + 1;
#print STDERR "putPage($id, $newRev, $now)\n";
  $section->setRevision($newRev);
  $section->setTS($now);
  $section->setUserID($self->{userid});
  $keptRevision->addSection($section, $now);
  $keptRevision->trimKepts($now - ($self->{keepdays} * 24 * 60 * 60))
      if ($self->{keepdays});
  $keptRevision->save();
  $page->{revision} = $newRev;
  $self->_WriteRcLog($args{pageId}, $args{changeSummary}, $now, $userId,
                     $host);

  $self->_save($page);
  $self->_releaseLock();
  return "";
}

sub deletePage {
  my $self = shift;
  my $id = shift;
  my $filename = $self->_getPageFile($id);
  my $keepfile = $self->{keepdir}.'/'._getPageDirectory($id)."/$id.kp";
  unlink($filename, $keepfile);
}

sub allPages {
  my $self = shift;
  my @l = (PurpleWiki::UseMod::Database::AllPagesList($self->{pagedir}));
  grep(s|\+|/|g, @l);
  @l;
}

# pages->recentChanges($starttime)
sub recentChanges {
  my $self = shift;
  my $starttime = shift;
  my $config = PurpleWiki::Config->instance();
  my %params = @_;
  $starttime = 0 unless $starttime;
  PurpleWiki::UseMod::Database::recentChanges($config, $starttime);
}

sub _releaseLock {
  PurpleWiki::UseMod::Database::ReleaseLock(shift->{lockdir});
}

sub _requestLock {
    my $self = shift;

    # need to add code to force it when the lock is stale
    PurpleWiki::UseMod::Database::RequestLock($self->{lockdir},
                                              $self->{tempdir});
}

sub _WriteRcLog {
  my ($self, $id, $summary, $editTime, $userId, $rhost) = @_;
  my ($extraTemp, %extra);

  # The two fields at the end of a line are kind and extension-hash
  my $rc_line = join($fs3, $editTime, $id, $summary, 0, $rhost, "0", 
                     join($fs2, (id => $userId, name => '')));
  my $rc_file = $self->{rcfile};
  if (!open(OUT, ">>$rc_file")) {
    die("Recent Changes log error($rc_file): $!");
  }
  print OUT  $rc_line . "\n";
  close(OUT);
}

# $pages->diff($id, $from_revision, $to_revision)
# if $from_revision is not supplied, try to use the previous version
sub diff {
  my ($self, $id, $diffRevision, $goodRevision) = @_;
  my $page = $self->getPage($id, $goodRevision);
  my $to = $page->_getText();

  $page->{selectrevision} = $diffRevision || $goodRevision - 1;
  my $from = $page->_getText();

  require Text::Diff;
  Text::Diff::diff(\$from, \$to, {STYLE => "OldStyle"});
}

sub getName {
    shift;
    my $pageName = shift;
    $pageName =~ s/_/ /g;
    $pageName;
}

sub pageExists {
    my ($self, $id) = @_;
    return (-f $self->_getPageFile($id));
}

# Determines the filename of the page with this id.
sub _getPageFile {
    my $self = shift;
    my $id = shift;
    my $base = $self->{pagedir} . '/' . _getPageDirectory($id);
    return "$base/$id.db";
}

sub _getPageDirectory {
    my $id = shift;
    return ($id =~ /^([a-zA-Z])/) ? uc($1) : 'other';
}

# $pages->_save($page, $id);
#
# Saves the Page by serialize it and its constituent parts to
# a string and then writing to disk.
sub _save {
    my $self = shift;
    my $page = shift;
    my $id = $page->{id};

    my $data = $self->_serialize($page);

    $self->_createPageDir($id);
    PurpleWiki::Misc::WriteStringToFile($self->_getPageFile($id), $data);
}

# Serializes the data structure to a string. Calls serialize
# on Section which in turns calls serialize on Text.
sub _serialize {
    my $self = shift;
    my $page = shift;

    my $sectionData = $page->_getSection()->serialize();

    my $separator = $fs1;

    my $data = join($separator, map {$_ . $separator . ($page->{$_} || '')}
        ('version', 'revision', 'cache_oldmajor', 'cache_oldauthor',
         'cache_diff_default_major', 'cache_diff_default_minor',
         'ts_create', 'ts'));

    $data .= $separator . 'text_default' . $separator . $sectionData;

    return $data;
}

# Creates the directory where this Page is stored.
sub _createPageDir {
    my $self = shift;
    my $id = shift;
    my $dir = $self->{pagedir};

    PurpleWiki::Misc::CreateDir($dir);
    $dir .= ('/' . _getPageDirectory($id));
    PurpleWiki::Misc::CreateDir($dir);
    if ($id =~ m|/|) {  # Make sure main page exists
        $dir .= "/$`";
        PurpleWiki::Misc::CreateDir($dir);
    }
}

sub _openPage {
    my $self = shift;
    my $id = shift;
    my $page = PurpleWiki::Archive::ModPage->new(id => $id);

    my $filename;
    if (-f ($filename = $self->_getPageFile($id))) {
        # FIXME: there should be a utility class of some kind
        my $data = PurpleWiki::Misc::ReadFileOrDie($filename);
        $self->_parseData($page, $data);
#print STDERR "Exists($id) $page->{version}\n";
    } else {
        $page->{version} = $DATA_VERSION;
        $page->{revision} = 0;
    }

    if ($page->{version} != $DATA_VERSION) {
        die("Bad page version (or corrupt page): $page->{version}:$DATA_VERSION:\n");
    }
    $page;
}

# Parses the data read in from a page file.
# FIXME: the profiler considers this sub
# somewhat more expensive than some others. Can
# the multi step name be collapsed?
sub _parseData {
    my ($self, $page, $data) = @_;

#print STDERR "_parseData()\n"; for (keys %$page) { print STDERR " $_ -> $page->{$_}\n"; }
    my %data = (split(/$fs1/o, $data, -1));
    while (my ($k, $v) = each(%data)) { $page->{$k} = $v; }
#print STDERR ">>\n"; for (keys %$page) { print STDERR " $_ -> $page->{$_}\n"; }
    $page->{text_default} = $page->_getSection();
}

# $pages->getRevisions($id)
sub getRevisions {
    my $self = shift;
    my $id = shift;
    my $maxcount = shift || 0;
    my $count = 1;
    my @pageHistory = ();
    my $page = $self->_openPage($id);

    my $currentSection = $page->_getSection();
    push @pageHistory, $self->_getRevisionHistory($id, $currentSection);
    my $krev = new PurpleWiki::UseMod::KeptRevision($self, id => $id);
    foreach my $section ( sort {($b->getRevision() <=> $a->getRevision())}
                               $krev->getSections() ) {
        # If KeptRevision == Current Revision don't print it. - matthew
        if ($section->getRevision() != $currentSection->getRevision()) {
            push @pageHistory, $self->_getRevisionHistory($id, $section);
        }
        last if ($maxcount && ++$count >= $maxcount);
    }
    (@pageHistory);
}

sub _getRevisionHistory {
    my ($self, $id, $section) = @_;
    my ($rev, $summary, $host, $user, $uid, $ts, $pageUrl, $diffUrl, $editUrl);

    my $text = $section->getText();
    $rev = $section->getRevision();
    $summary = $text->getSummary();
    if ((defined($section->getHost())) && ($section->getHost() ne '')) {
        $host = $section->getHost();
    } else {
        $host = $section->getIP();
        $host =~ s/\d+$/xxx/;      # Be somewhat anonymous (if no host)
    }
    $user = $section->getUsername();
    $uid = $section->getUserID();
    $ts = $section->getTS();

    if (defined($summary) && ($summary ne "") && ($summary ne "*")) {
        $summary = UseModWiki::QuoteHtml($summary);
    }
    else {
        $summary = '';
    }
    return { revision => $rev,
             dateTime => UseModWiki::TimeToText($ts),
             host => $host,
             userId => $uid,
             summary => $summary };
}

package PurpleWiki::Archive::ModPage;

# PurpleWiki Page Data Access

# $Id$

use strict;
use base 'PurpleWiki::Page';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = { @_, version => $DATA_VERSION };
    bless ($self, $class);
    return $self;
}

# page->getIP()
sub getIP {
  my $self = shift;
  $self->{ip};
}

# page->getUserID()
sub getUserID {
    my $self = shift;
    $self->{userID};
}

# Returns the revision of this Page.
sub getRevision {
    my $self = shift;
    my $rev = $self->{selectrevision};
    return $rev if $rev;
    return $self->_getSection()->getRevision();
}

# Gets the timestamp of this Page. 
sub getTime {
    my $self = shift;
    my $section = $self->_revSection();
    return ($section && $section->getTS());
}

sub _revSection {
    my $self = shift;
    my $section = $self->{section};
    return $section if $section;
    if ($self->{selectrevision}) {
        $self->_getText();
        $self->{section};
    } else {
        $self->_getSection();
    }
}

sub getHost {
    my $self = shift;
    my $section = $self->_revSection();
    return ($section && $section->getHome());
}

sub getSummary {
    my $self = shift;
    my $section = $self->_revSection();
    return ($section && $section->getSummary());
}

#
# page->_getText([revision])
#
sub _getText {
    my $self = shift;
    my $selectrevision = $self->{selectrevision};
    my $section = $self->_getSection();
    my $crev = $section->getRevision();
    if ($selectrevision && ($selectrevision != $crev)) {
        my $krev = new PurpleWiki::UseMod::KeptRevision($self->{pages},
                                                        id=>$self->{id});
        for my $section ($krev->getSections()) {
            if ($selectrevision == $section->getRevision()) {
                $self->{section} = $section;
                my $text = $section->getText();
                return (ref($text)) ? $text->getText() : $text;
            }
        }
        return "";  # no revision found
    } else {
        my $text = $section->getText();
        $self->{revision} = $crev;
        return (ref($text)) ? $text->getText() : $text;
    }
}

sub getTree {
  my $self = shift;
  my $tree = $self->{tree};
  return $tree if $tree;
  my $text = $self->_getText();
  return undef unless $text;
  my $parser = new PurpleWiki::Parser::WikiText;
  return $parser->parse($text, 'add_node_ids' => 0);
}

# exists. If not a new one is created
# and returned.
sub _getSection {
    my $self = shift;

    if (ref($self->{text_default})) {
        return $self->{text_default};
    } else {
        $self->{text_default} =
            new PurpleWiki::UseMod::Section('data' => $self->{text_default},
                                            'userID' => $self->{userID},
                                            'username' => $self->{username});
        return $self->{text_default};
    }
}

# Retrieves the page id.
sub getID {
    return shift->{id};
}

1;
