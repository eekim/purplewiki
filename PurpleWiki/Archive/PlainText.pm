# PurpleWiki::SVNDatabase::Pages
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Pages.pm 506 2004-09-22 07:31:44Z gerry $
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
$VERSION = sprintf("%d", q$Id: DefaultArchive.pm 506 2004-09-22 07:31:44Z gerry $ =~ /\s(\d+)\s/);

package PurpleWiki::Archive::PlainText;

use Fcntl ':mode';
use IO::Dir;
use IO::File;
use File::Path;

use PurpleWiki::Config;
use PurpleWiki::Search::Result;
use PurpleWiki::Parser::WikiText;

sub new {
  my $proto = shift;
  my $config = shift;
  die "No config\n" unless $config;
  my %args = @_;
  my $class = ref($proto) || $proto;
  my $self = {};

  $self->{script} = $config->ScriptName;
  my $loc = $config->DataDir;
  substr($loc,-1) = '' if (substr($loc,-1) eq '/');
  if ($args{create} && !-d $loc) {
      mkdir $loc;
  } elsif (!-d $loc) {
      die "No datadir $loc\n";
  }
  $self->{datadir} = $loc;
  bless $self, $class;
  $self;
}

sub getPage {
  my $self = shift;
  my $id = shift;
  my $rev = shift;
  $id =~ s|/|\+|g;

  PurpleWiki::Archive::PlainTextPage->new(id => $id, revision => $rev,
                                          datadir => $self->{datadir});
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
  my %props = ();
  my $tree = $args{tree};
  return "No data" unless (defined($tree));
  my $contents = $tree->view('wikitext');
  $contents .= "\n"  unless (substr($contents, -1, "\n"));

  my $id = $args{pageId};
#for (keys %args) { print STDERR "PP:$_ = $args{$_}\n"; }
  $id =~ s|/|\+|g;
  my $now = time;
  my $page = PurpleWiki::Archive::PlainTextPage->new(id => $id,
                                                 datadir => $self->{datadir});
  return "Lock Failed" unless ($page->_requestLock());
  my $old_contents = $page->_getText();

  if ($contents eq $old_contents) {
      $page->_releaseLock();
      return "";
  }

  my $rev = $page->getRevision();
  my $oldrev = $args{oldrev};
  if ($oldrev && $rev != $oldrev) {
      $page->_releaseLock();
      return "Conflict";
  }

  $page->{revision} = $rev+1;
  $page->_writePage($contents);

  $args{host} = $ENV{REMOTE_ADDR} unless ($args{host});
  for my $pname ('userId', 'host', 'changeSummary' ) {
      my $pval = $args{$pname};
      $props{$pname} = (defined($pval)) ? $pval : $page->{$pname};
  }
  $page->_writeMeta(\%props);
#print STDERR "putPage($props{id}, $props{revision}\n";

  $page->_releaseLock();
  return "";
}

sub deletePage {
  my $self = shift;
  my $id = shift;
  $id =~ s|/|\+|;
  my $datadir = $self->{datadir};
  my $idSub = ($id =~ /^[A-Z]/i) ? uc($&) : 'misc';
  for my $revSub (1..9) {
    if (-d "$datadir/$revSub") {
      my $path = "$datadir/$revSub/$idSub/$id";
      my %dir;
      if (tie(%dir, IO::Dir, $path)) {
        for my $rev (keys %dir) {
          unlink "$path/$rev";
        }
        untie %dir;
        rmdir $path;
      }
    }
  }
  unlink "$datadir/$idSub/$id.txt";
}

sub _find_txt {
  my $dir = shift;
  my $array_ref = shift;
  my $oldest = shift;
  my %dir;
#print STDERR "_find_txt($dir, $#{$array_ref}, $oldest)\n";
  if (tie %dir, IO::Dir, $dir) {
    for my $entry (keys %dir) {
      next if (substr($entry,0,1) eq '.');
      my $a = $dir{$entry};
      next unless ref($a);
      my ($mode, $mtime) = ($a->mode, $a->mtime);
      if (S_ISDIR($mode)) {
        _find_txt("$dir/$entry", $array_ref);
      } elsif (S_ISREG($mode)) {
#print STDERR "$oldest :: $mtime ($entry)\n" if (!$oldest && $entry =~ /\.txt$/);
        push @$array_ref, "$dir/$entry"
          if ((!$oldest || $mtime > $oldest) && $entry =~ /\.txt$/);
      }
    }
    untie %dir;
  } else { print STDERR "Error reading dir $dir\nError: $!\n"; }
}

sub allPages {
  my $self = shift;
  my $a_ref = [];
  my %ids = ();
  _find_txt($self->{datadir}, $a_ref);
  for (@$a_ref) {
    if (m|/([^/]+)/[^/]+\.txt$|) {
      my $id = $1;
      $id =~ s|\+|/|g;
      $ids{$id}++;
    }
  }
  (sort keys %ids);
}

# pages->recentChanges($starttime)
sub recentChanges {
  my $self = shift;
  my $starttime = shift;
  my %pages = ();
  # find $self->{datadir} -type f -name \*.txt -newer $starttime
  my $a_ref = [];
  _find_txt($self->{datadir}, $a_ref, $starttime);
  for (@$a_ref) {
    if (m|/([^/]+)/[^/]+\.txt$|) {
      my $id = $1;
      my $page = $self->getPage($id);
      my $pageTime = $page->getTime;
      if ($pages{$id} && $pages{$id}->{timeStamp} > $pageTime) {
          $pages{$id}->{numChanges}++;
      } else {
          if ($pages{$id}) {
              $pages{$id}->{numChanges}++;
          } else {
              $pages{$id} = { numChanges => 1, pageId => $id }
          }
          $pages{$id}->{timeStamp} = $pageTime;
          my $summary = $page->{changeSummary};
          $pages{$id}->{changeSummary} = (!$summary || $summary eq '*') ? ''
                                   : $page->{changeSummary};
          $pages{$id}->{userId} = $page->getUserID || '';
          $pages{$id}->{host} = $page->{host} || '';
      }
    }
  }
  [ map( $pages{$_},
         ( sort { $pages{$b}->{timeStamp} <=> $pages{$a}->{timeStamp}; }
           (keys %pages) ) ) ];
}

# $pages->diff($id, $from_revision, $to_revision)
# if $from_revision is not supplied, try to use the previous version
sub diff {
  my ($self, $id, $diffRevision, $goodRevision) = @_;
  my $to = $self->getPage($id, $goodRevision)->_getText();

  my $fromrev = $diffRevision || $goodRevision - 1;
  my $from = $self->getPage($id, $fromrev)->_getText();

  require Text::Diff;
  Text::Diff::diff(\$from, \$to, {STYLE => "OldStyle"});
}

sub pageExists {
    my ($self, $id) = @_;
    my $file = $self->getPage($id)->_revPath(). '.txt';
    (-e $file);
}

sub getName {
    shift;
    my $pageName = shift;
    $pageName =~ s/_/ /g;
    $pageName;
}

# $pages->getRevisions($id)
sub getRevisions {
    my $self = shift;
    my $id = shift;
    $id =~ s|/|\+|;
    my $maxcount = shift || 0;
    my $count = 1;
    my @pageHistory = ();
    my $datadir = $self->{datadir};
    my @revs = ();
    my $idSub = ($id =~ /^[A-Z]/i) ? uc($&) : 'misc';
    for my $revSub (1..9) {
      if (-d "$datadir/$revSub") {
        my $path = "$datadir/$revSub/$idSub/$id";
        my %dir;
        if (tie(%dir, IO::Dir, $path)) {
          for my $rev (keys %dir) {
            push(@revs, $`+0) if ($rev =~ /\.txt$/);
          }
          untie %dir;
        }
      }
    }
    @revs = (sort { $b <=> $a } @revs);
    $maxcount = $#revs if (!$maxcount || $#revs < $maxcount);
    my @revisions = ();
    for my $rev (@revs[0..$maxcount]) {
      my $page = $self->getPage($id, $rev);
      my ($pageUrl, $diffUrl, $editUrl);

      # FIXME this is really ugly, we shouldn't be creating all these URLs here
      if ($page->_getCurrentRev() == $rev) {
          $pageUrl = $self->{script} . "?$id";
      } else {
          $pageUrl = $self->{script} .
            "?action=browse&amp;id=$id&amp;revision=$rev";
          $diffUrl = $self->{script} .
              "?action=browse&amp;diff=1&amp;id=$id&amp;diffrevision=$rev";
          $editUrl = $self->{script} .
              "?action=edit&amp;id=$id&amp;revision=$rev";
      }
      my $pageTime = $page->getTime();
      my $summary = $page->{changeSummary};
      push( @revisions,
            { revision => $rev,
              dateTime => UseModWiki::TimeToText($pageTime),
              host => $page->{host},
              user => $page->getUserID(),
              summary => ($summary && ($summary ne "*"))
                          ? UseModWiki::QuoteHtml($summary) : '',
              pageUrl => $pageUrl,
              diffUrl => $diffUrl,
              editUrl => $editUrl } );
    }
    @revisions;
}

package PurpleWiki::Archive::PlainTextPage;

# PurpleWiki Page Data Access

# $Id: Pages.pm 506 2004-09-22 07:31:44Z gerry $

use strict;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = { @_ };
    if (!$self->{id}) {
       use Carp;
       Carp::confess;
#for (keys %$self) { print STDERR "newP:$_ = $$self{$_}\n"; }
    }
    bless ($self, $class);
    return $self;
}

sub getUserID {
    my $self = shift;
    $self->_readMeta();
    $self->{userId};
}

# Returns the revision of this Page.
sub getRevision {
    my $self = shift;
    $self->_readMeta();
    my $rev = $self->{revision};
    $rev || 0;
}

# Gets the timestamp of this Page. 
sub getTime {
    my $self = shift;
    $self->_readMeta();
    my $file = $self->_revPath() . '.txt';
    (stat($file))[9];
}

#
# page->_getText([revision])
#
sub _getText {
    my $self = shift;
    (defined($self->_readPage())) ? $self->{text}
                                 : 'Describe the new page here.';
}

sub getTree {
  my $self = shift;
  my $tree = $self->{tree};
  return $tree if $tree;
  my $parser = new PurpleWiki::Parser::WikiText;
  my $text = $self->_getText();
  $parser->parse($text, 'add_node_ids' => 0);
}

# Retrieves the page id.
sub getID {
  my $id = shift->{id};
  $id =~ s|\+|/|g;
  $id;
}

sub _readPage {
  my $self = shift;
  return "" if (defined($self->{text}));
 
  my $file = $self->_revPath() . '.txt';
#print STDERR "_readPage($file)\n";
  my $fh = IO::File->new($file);
  return undef unless (defined($fh));
  $self->{text} = join("", (<$fh>));
  undef $fh;
  "";
}

sub _readMeta {
  my $self = shift;
  return if (defined($self->{changeSummary}));
  my $rev = $self->{revision};
  $self->{revision} = $rev = $self->_getCurrentRev unless $rev;
 
  my $file = $self->_revPath() . '.meta';
#print STDERR "_readMeta($file)\n";
  my $fh = IO::File->new($file);
  if ($fh) {
    while (<$fh>) {
      chomp();
      my ($k, $v) = split("=", $_, 2);
#print STDERR "RM:$k -> $v\n";
      $self->{$k} = $v;
    }
    undef $fh;
  }
}

sub _writePage {
  my $self = shift;
  my $file = $self->_revPath() . '.txt';
  my $dir = $file;
  $dir =~ s|/[^/]*$||;
  File::Path::mkpath($dir);
#print STDERR "File mkpath: $file\n",join("\n", File::Path::mkpath($dir)),"\n";
  my $fh = IO::File->new(">$file");
  if ($fh) {
    print $fh $_[0];
    undef $fh
  } else {
    print STDERR "_writePage:$file\nError:$!\n";
  }
  $self->_linkCurrent();
}

sub _linkCurrent {
  my $self = shift;
  my $revfile = $self->_revPath() . '.txt';
  my $curfile = $self->_curPath() . '.txt';
  if ($revfile ne $curfile) {
      my $relpath = $revfile;
      my $datadir = $self->{datadir};
      $relpath =~ s/$datadir/../;
      unlink $curfile if (-e $curfile);
      symlink($relpath, $curfile);
  }
}

sub _getCurrentRev {
  my $self = shift;
  my $link = $self->_curPath() . '.txt';
  return '' unless (-l $link);
  my $dest = readlink($link);
#print STDERR "_getCurrentRev($dest)\n";
  ($dest =~ m|/([^/\.]+)\.txt$|) ? $1 : '';
}

sub _writeMeta {
  my $self = shift;
  my $hashref = shift;
  my $file = $self->_revPath() . '.meta';
  my $text = "";
  my $fh = IO::File->new(">$file");
  if ($fh) {
    for (sort keys %$hashref) {
        print $fh "$_=$$hashref{$_}\n";
    }
    undef $fh
  }
}

sub _requestLock {
  my $self = shift;
  my $lock = $self->_curPath() . '.lck';
  my $lockdir = $lock;
  $lockdir =~ s|/[^/]*$||;
#print STDERR "No dir: " unless ($self->{datadir});
#print STDERR "_requestLock($lock)\n";
  # 10 tries, 3 second wait, die on error
  my ($tries, $wait, $errorDie) = (10, 3, 1);
  my $n = 0;

  File::Path::mkpath($lockdir);
#print STDERR "mkpath $lockdir\n",join("\n", File::Path::mkpath($lockdir)),"\n";
  while (mkdir($lock, 0555) == 0) {
    if ($! != 17) {
      die("can not make $lock: $!\n")  if $errorDie;
      return 0;
    }
    my $now = time;
    my $lockAge = (stat($lock))[9] - $now;
    # FIXME should get stale threshold be configable (default 2 min.)
    if ($lockAge > $tries*$wait*4) {
      utime $now, $now, $lock;  # give it to us, starting now
      # assume that we got it if the time changed with utime
      # otherwise we failed to break the oldlock ...
      return ((stat($lock))[9] != $now);
    }
    return 0  if ($n++ >= $tries);
    sleep($wait);
  }
  return 1;
}

sub _releaseLock {
  my $self = shift;
  my $lock = $self->_curPath() . '.lck';
  rmdir($lock);
}

sub _revPath {
  my $self = shift;
  my $id = $self->{id};
  unless ($self->{id}) {
    for (keys %$self) { print STDERR "rP:$_ = $$self{$_}\n"; }
  }
  my $idSub = ($id =~ /^[A-Za-z]/) ? uc($&) : 'misc';
  my $rev = $self->{revision};
  my $datadir = $self->{datadir};
  return "$datadir/$idSub/$id" unless $rev;
  my $revSub = substr($rev, 0, 1);
  "$datadir/$revSub/$idSub/$id/$rev";
}

sub _curPath {
  my $self = shift;
  my $id = $self->{id};
  unless ($self->{id}) {
    for (keys %$self) { print STDERR "rP:$_ = $$self{$_}\n"; }
  }
  my $idSub = ($id =~ /^[A-Za-z]/) ? uc($&) : 'misc';
  my $datadir = $self->{datadir};
  "$datadir/$idSub/$id";
}

#
# Filesystem structure:
# /[1-9]/[A-Z]/<id+>/<rev>.txt   Wikitext revisions
# /[1-9]/[A-Z]/<id+>/<rev>.meta  MetaData revisions
# /[A-Z]/<id+>.txt               Wikitext Current (symlink to revision)
# /[A-Z]/<id+>.lck               Individual page lock
#

1;
