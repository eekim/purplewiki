# PurpleWiki::Database::Page
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

package PurpleWiki::Database::Pages;

use PurpleWiki::Database;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  my $config = (@_) ? shift : PurpleWiki::Config->instance();
  $self->{script} = $config->ScriptName;
  $self->{fs1} = $config->FS1;
  $self->{fs2} = $config->FS2;
  $self->{fs3} = $config->FS3;
  $self->{fs} = $config->FS;
  $self->{pagedir} = $config->PageDir;
  $self->{usediff} = $config->UseDiff;
  $self->{rcfile} = $config->RcFile;
  $self->{keepdays} = $config->KeepDays;
  bless $self, $class;
  $self;
}

sub newPageId {
  my $self = shift;
  my $id = shift;
  PurpleWiki::Database::Page->new(id => $id, pages => $self);
}

sub newPageText {
  my ($self, $id, $wikitext) = @_;
  PurpleWiki::Database::Page->new(id => $id,
                                  pages => $self,
                                  wikitext => $wikitext);
}

sub newPage {
  my $self = shift;

  my $page = PurpleWiki::Database::Page->new(pages => $self, @_);
  $self->_newRevision($page) if (defined($page->{wikitext}));
  $page;
}

sub _newRevision {
my ($self, $page) = @_;
  use PurpleWiki::Database::KeptRevision;
  my $fsexp = $self->{fs};
  my $keptRevision = new PurpleWiki::Database::KeptRevision(id => $page->{id});
  $page->_openPage();
  my $text = $page->_getText();
  my $section = $page->getSection();
  my $old = $text->getText();
  my $oldrev = $section->getRevision();
  my $pgtime = $page->getTS();
  my $now = $page->{timestamp};

  $page->{wikitext} =~ s/$fsexp//g;
  my $wikitext = $page->{wikitext};
  $self->{summary} =~ s/$fsexp//g;
  if ($self->{usediff}) {
    # FIXME: how many args does it take to screw a pooch?
    PurpleWiki::Database::UpdateDiffs($page, $keptRevision, $id,
        $now, $old, $string, 0, $page->{newauthor});
  }
  $text->setText($wikitext);
  $text->setNewAuthor($page->{newauthor});
  $text->setSummary($page->{summary});
  $section->setHost($page->{host});
  $section->setRevision($section->getRevision() + 1);
  $section->setTS($now);
  $section->setUsername($self->{username});
  $section->setUserID($self->{userid});
  $keptRevision->addSection($section, $now);
  $keptRevision->trimKepts($now - ($self->{keepdays} * 24 * 60 * 60))
      if ($self->{keepdays});
  $keptRevision->save();
  $page->setRevision($section->getRevision());
  $page->{ts} = $now;
  $self->_WriteRcLog($page->{id}, $page->{summary}, $now,
                    $self->{username}, $page->{host} || $page->{ip});
}

sub allPages {
  my $self = shift;
  (PurpleWiki::Database::AllPagesList());
}

# pages->recentChanges(backto => $starttime, count => $count)
sub recentChanges {
  my $self = shift;
  my $config = $self->{config} || PurpleWiki::Config->instance();
  my %params = @_;
  my $starttime = 0;
  $starttime = $params{backto} if ($params{backto});
  PurpleWiki::Database::recentChanges($config, $starttime);
}

sub releaseLock {
  PurpleWiki::Database::ReleaseLock;
}

sub requestLock {
  PurpleWiki::Database::RequestLock;
}

sub forceReleaseLock {
  PurpleWiki::Database::ForceReleaseLock;
}

# Note: all diff and recent-list operations should be done within locks.
sub _WriteRcLog {
  my ($self, $id, $summary, $editTime, $name, $rhost) = @_;
  my ($extraTemp, %extra);

  %extra = ();
  $extra{'id'} = $user->id  if ($user);
  $extra{'name'} = $name  if ($name ne "");
  $extraTemp = join($self->{fs2}, %extra);
  # The two fields at the end of a line are kind and extension-hash
  my $rc_line = join($self->{fs3}, $editTime, $id, $summary,
                     0, $rhost, "0", $extraTemp);
  my $rc_file = $self->{rcfile};
  if (!open(OUT, ">>$rc_file")) {
    die("Recent Changes log error($rc_file): $!");
  }
  print OUT  $rc_line . "\n";
  close(OUT);
}

package PurpleWiki::Database::Page;


# PurpleWiki Page Data Access

# $Id$

use strict;
use PurpleWiki::Config;
use PurpleWiki::Database;
use PurpleWiki::Database::Section;
use PurpleWiki::Database::Text;
use PurpleWiki::Database::KeptRevision;
use PurpleWiki::Search::Result;
use PurpleWiki::Parser::WikiText;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

# defaults for Text Based data structure
my $DATA_VERSION = 3;            # the data format version

# Creates a new page reference, may be a
# a new one or an existing one. Expects args of
# at least 'id', will also take 'now' for the time of
# the current CGI request and 'userID' and 'username' to
# be passed to Section for the creation of new Text.
#
# page->new ( named parameters )
#    id        => Page Identifier, the database key for reading and writing
#    wikitext  => If present, this is the source, not the DB
#    newauthor => New author flag 
#    summary   => The change description
#    host      => Hostname of the post request
#    username  => User's name
#    userid    => User's Identifier
#    now       => Update time (time integer)
#    pages     => The database service object
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = { @_ };
    bless ($self, $class);
    return $self;
}

# page->getIP()
sub getIP {
  my $self = shift;
  $self->_openPage() unless ($self->{open});
  $self->{ip};
}

# page->getLockState()
sub getLockState {
    return (-f shift->getLockedPageFile());
}

# page->getUserID()
sub getUserID {
    my $self = shift;
    $self->_openPage() unless ($self->{open});
    $self->{userID};
}


# A shim to facillitate other callers
sub pageExists {
    my $self = shift;
    return (-f $self->getPageFile());
}

# Causes an error because the data in the 
# Returns true if the page file associated with this
# page exists.
sub pageFileExists {
    my $self = shift;

    return (-f $self->getPageFile());
}

# Returns the revision of this Page.
sub getRevision {
    my $self = shift;
    my $rev = $self->{selectrevision};
    return $rev if $rev;
    $self->_openPage() unless ($self->{open});
    return $self->getSection()->getRevision();
}

# Sets the revision of this Page.
sub setRevision {
    my $self = shift;
    my $revision = shift;
    $self->{revision} = $revision;
}

sub getTime { shift->getTS(); }

# Gets the timestamp of this Page. 
sub getTS {
    my $self = shift;
    $self->_openPage() unless ($self->{open});
    return $self->getSection()->getTS();
}

# Gets one of a few different cache data items for this Page.
sub getPageCache {
    my $self = shift;
    my $cache = shift;
    
    return $self->{"cache_$cache"};
}

# Sets one of a few different cache data items for this Page
# to the provided value.
sub setPageCache {
    my $self = shift;
    my $cache = shift;
    my $revision = shift;

    $self->{"cache_$cache"} = $revision;
}

# Opens the page file associated with the id of this
# Page.
sub _openPage {
    my $self = shift;
    return if ($self->{open});

    if ($self->pageFileExists()) {
        my $filename = $self->getPageFile();
        # FIXME: there should be a utility class of some kind
        my $data = PurpleWiki::Database::ReadFileOrDie($filename);
        $self->_parseData($data);
    } else {
        $self->{version} = $DATA_VERSION;
        $self->{revision} = 0;
    }

    if ($self->{version} != $DATA_VERSION) {
        $self->_updatePageVersion();
    }
    $self->{open} = 1;
}

sub _getText {
    my $self = shift;
    my $section = $self->getSection();
    return $section->getText();
}

sub hasRevision {
    my $self = shift;
    my $rev = shift;
    return 1 unless $rev;  # current rev always exists

    $self->_openPage() unless ($self->{open});
    return 1 if ($self->getSection->getRevision() == $rev);

    my $krev = new PurpleWiki::Database::KeptRevision(id => $self->{id});
    for my $section ($krev->getSections()) {
        return 1 if ($rev == $section->getRevision());
    }
    return 0;  # no revision found
}

# Returns the text of the version previous to the selected one (or current)
sub getPrev {
    my $self = shift;
    my $rev = "";
    my $prev = 0;
    my $psection;
    $rev = ((@_) ? shift : $self->getRevision()) - 1;
    $self->_openPage() unless ($self->{open});
    my $krev = new PurpleWiki::Database::KeptRevision(id => $self->{id});
    for my $section ($krev->getSections()) {
        my $thisrev = $section->getRevision();
        if ($thisrev <= $rev && $thisrev > $prev) {
            $prev = $thisrev;
            $psection = $section;
            last if ($rev == $thisrev);
        }
    }
    return "" unless $prev;
    my $text = $psection->getText();
    return (ref($text)) ? $text->getText() : $text;
}

#
# page->getText([revision])
#
# Return the content string for the selected 'revision' or the current
# revision.  Also sets the selected revision of the page, so if you do
# another 'getText' or 'getRevision' that's what you get.
#
sub getText {
    my $self = shift;
    my $selectrevision = $self->{selectrevision};
    $self->{selectrevision} = $selectrevision = shift if @_;
    $self->_openPage() unless ($self->{open});
    if ($selectrevision && ($selectrevision != $self->{revision})) {
        my $krev = new PurpleWiki::Database::KeptRevision(id => $self->{id});
        for my $section ($krev->getSections()) {
            if ($selectrevision == $section->getRevision()) {
                my $text = $section->getText();
                return (ref($text)) ? $text->getText() : $text;
            }
        }
        return "";  # no revision found
    } else {
        my $section = $self->getSection();
        my $text = $section->getText();
        return (ref($text)) ? $text->getText() : $text;
    }
}

# page->getWikiHTML()
#
# format the page for HTML output
#
sub getWikiHTML {
    my $self = shift;
    my $id = shift;

    my $url = $self->{pages}->{script} . '?' . $id;
    my $parser = PurpleWiki::Parser::WikiText->new();
    my $wiki = $parser->parse($self->getText(),
                   add_node_ids => 0,
                   url => $url,
               );
    return $wiki->view('wikihtml', url => $url);
}

# Retrieves the default text data by getting the
# Section and then the text in that Section.
# page->getPageNode($Id, $nid)
#
# get just one node
#
sub getPageNode {
  my ($self, $id, $nid) = @_;
  my $parser = new PurpleWiki::Parser::WikiText;
  if ($self->pageExists()) {
    my $tree = $parser->parse($self->getText(), 'add_node_ids' => 0);
    return $tree->view('subtree', 'nid' => uc($nid));
  } 
  ""
}

# page->searchResult([string])
sub searchResult {
    my $self = shift;
    my $string = shift || $self->getText();
    my $name = $self->getID();

    my $result = new PurpleWiki::Search::Result();
    $result->title($name);
    $result->modifiedTime($self->getTS());
    $result->url($self->getWikiWordLink($name));
    $result->summary(substr($string, 0, 99) . '...');

    return $result;
}

sub getRevisions {
    my $self = shift;
    my $maxcount = shift || 0;
    my $count = 1;
    my @pageHistory = ();
    $self->_openPage() unless ($self->{open});
    my $id = $self->{id};

    push @pageHistory, $self->_getRevisionHistory($id, $self->getSection, 1);
    my $krev = new PurpleWiki::Database::KeptRevision(id => $id);
    foreach my $section ( sort {-($a->getRevision() <=> $b->getRevision())}
                               $krev->getSections() ) {
        # If KeptRevision == Current Revision don't print it. - matthew
        if ($section->getRevision() != $self->getSection()->getRevision()) {
            push @pageHistory, $self->_getRevisionHistory($id, $section, 0);
        }
        last if ($maxcount && ++$count >= $maxcount);
    }
    (@pageHistory);
}

sub _getRevisionHistory {
    my ($self, $id, $section, $isCurrent) = @_;
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

    if ($isCurrent) {
        $pageUrl = $self->{pages}->{script} . "?$id";
    }
    else {
        $pageUrl = $self->{pages}->{script} .
          "?action=browse&amp;id=$id&amp;revision=$rev";
        $diffUrl = $self->{pages}->{script} .
            "?action=browse&amp;diff=1&amp;id=$id&amp;diffrevision=$rev";
        $editUrl = $self->{pages}->{script} .
            "?action=edit&amp;id=$id&amp;revision=$rev";
    }
    if (defined($summary) && ($summary ne "") && ($summary ne "*")) {
        $summary = UseModWiki::QuoteHtml($summary);
    }
    else {
        $summary = '';
    }
    return { revision => $rev,
             dateTime => UseModWiki::TimeToText($ts),
             host => $host,
             user => $user,
             summary => $summary,
             pageUrl => $pageUrl,
             diffUrl => $diffUrl,
             editUrl => $editUrl };
}
# Retrieves the Section if it already
# exists. If not a new one is created
# and returned.
sub getSection {
    my $self = shift;

    if (ref($self->{text_default})) {
        return $self->{text_default};
    } else {
        $self->{text_default} =
            new PurpleWiki::Database::Section('data' => $self->{text_default},
                                              'userID' => $self->{userID},
                                              'username' => $self->{username});
        return $self->{text_default};
    }
}

# Retrives the version of this page.
sub getVersion {
    my $self = shift;

    return $self->{version};
}

# Retrieves the page id.
sub getID {
    my $self = shift;
    $self->_openPage() unless ($self->{open});
    return $self->{id};
}

# Determines the filename of the page with this id.
sub getPageFile {
    my $self = shift;

    return $self->{pages}->{pagedir} . '/' . $self->getPageDirectory() . '/' .
        $self->{id} . '.db';
}

# Determines the directory of this Page.
sub getPageDirectory {
    my $self = shift;

    my $directory = 'other';

    if ($self->{id} =~ /^([a-zA-Z])/) {
        $directory = uc($1);
    }

    return $directory;
}

# Page file is out of date.
sub _updatePageVersion {
    my $self = shift;

    # FIXME: ugly, but quick
    die('Bad page version (or corrupt page)');
}

# Parses the data read in from a page file.
# FIXME: the profiler considers this sub
# somewhat more expensive than some others. Can
# the multi step name be collapsed?
sub _parseData {
    my $self = shift;
    my $data = shift;

    my $regexp = $self->{pages}->{fs1};
    my %tempHash = split(/$regexp/, $data, -1);
    
    foreach my $key (keys(%tempHash)) {
        $self->{$key} = $tempHash{$key};
    }

    $self->{text_default} = $self->getSection();
}

# page->save();
#
# Saves the Page by serialize it and its constituent parts to
# a string and then writing to disk.
sub save {
    my $self = shift;

    my $data = $self->serialize();

    $self->_createPageDir();
    PurpleWiki::Database::WriteStringToFile($self->getPageFile(), $data);
}

# Gets the path and filename for the lock file for 
# this page.
sub getLockedPageFile {
    my $self = shift;
    my $id = $self->{id};
    return $self->{pages}->{pagedir} . '/' . $self->getPageDirectory() . "/$id.lck";
}

# Creates the directory where this Page is stored.
sub _createPageDir {
    my $self = shift;
    my $id = $self->{id};
    my $dir = $self->{pages}->{pagedir};
    my $subdir;

    PurpleWiki::Database::CreateDir($dir);  # Make sure main page exists
    $subdir = $dir . '/' . $self->getPageDirectory();
    PurpleWiki::Database::CreateDir($subdir);

    if ($id =~ m|([^/]+)/|) {
        $subdir = $subdir . '/' . $1;
        PurpleWiki::Database::CreateDir($subdir);
    }
}

# Serializes the data structure to a string. Calls serialize
# on Section which in turns calls serialize on Text.
sub serialize {
    my $self = shift;

    my $sectionData = $self->getSection()->serialize();

    my $separator = $self->{pages}->{fs1};

    my $data = join($separator, map {$_ . $separator . ($self->{$_} || '')} 
        ('version', 'revision', 'cache_oldmajor', 'cache_oldauthor',
         'cache_diff_default_major', 'cache_diff_default_minor',
         'ts_create', 'ts'));

    $data .= $separator . 'text_default' . $separator . $sectionData;

    return $data;
}

1;
