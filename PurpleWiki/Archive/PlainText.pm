# PurpleWiki::Archive::PlainText
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

use strict;
use base 'PurpleWiki::Archive::Base';

use Fcntl ':mode';
use IO::Dir;
use IO::File;
use File::Path;
use PurpleWiki::Config;
use PurpleWiki::Search::Result;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Archive::Sequence;

sub new {
  my $proto = shift;
  my $config = undef;
  $config = shift if (ref($_[0]) eq "PurpleWiki::Config");
  my %args = @_;
  my $class = ref($proto) || $proto;
  my $self = {};

  my $datadir;
  if ($config) {
    $datadir = $config->DataDir;
    $self->{sequrl} = $config->RemoteSequenceURL;
    $self->{seqdir} = $config->LocalSequenceDir;
  } else {
    my $x;
    $datadir = $x if (defined($x=$args{DataDir}));
    $self->{seqdir} = (defined($x=$args{SequenceDir})) ? $x : $datadir;
  }
    die "No config or data dir defined\n" unless $datadir;
  substr($datadir,-1) = '' if (substr($datadir,-1) eq '/');
  if ($args{create} && !-d $datadir) {
      mkdir $datadir;
  } elsif (!-d $datadir) {
      die "No datadir $datadir\n";
  }
  $self->{datadir} = $datadir;
  $self->{seqdir} = $datadir unless ($self->{seqdir});
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
  $contents .= "\n"  unless (substr($contents, -1) eq "\n");

  my $id = $args{pageId};
#for (keys %args) { print STDERR "PP:$_ = $args{$_}\n"; }
  $id =~ s|/|\+|g;
  my $page = PurpleWiki::Archive::PlainTextPage->new(id => $id,
                                                 datadir => $self->{datadir});
  $page->{timeStamp} = $args{timeStamp} || time;
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

  my $url = $args{url};
  if ($url) {
      &PurpleWiki::Archive::Sequence::updateNIDs($self, $url, $tree)
      && ($contents = $tree->view('wikitext'));
  }

  $page->{revision} = $rev+1;
  $page->_writePage($contents, $args{timeStamp});

  $args{host} = $ENV{REMOTE_ADDR} unless ($args{host});
  for my $pname ('userId', 'host', 'changeSummary', 'timeStamp') {
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
  my $path = "$datadir/$idSub/$id";
  my %dir;
  if (tie(%dir, 'IO::Dir', $path)) {
    for my $rev (keys %dir) {
      unlink "$path/$rev";
    }
    untie %dir;
    rmdir $path;
  }
}

sub _find_txt {
  my $dir = shift;
  my $array_ref = shift;
  my $oldest = shift;
  my %dir;
#print STDERR "_find_txt($dir, $#{$array_ref}, $oldest)\n";
  if (tie %dir, 'IO::Dir', $dir) {
    for my $entry (keys %dir) {
      next if (substr($entry,0,1) eq '.');
      my $a = $dir{$entry};
      next unless ref($a);
      my ($mode, $mtime) = ($a->mode, $a->mtime);
      if (S_ISDIR($mode)) {
        _find_txt("$dir/$entry", $array_ref, $oldest);
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
  for my $subdir ('A'..'Z', 'misc') {
    my $dir = $self->{datadir} . '/' . $subdir;
    _find_txt($dir, $a_ref, undef) if (-d $dir);
  }
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
  for my $subdir ('A'..'Z', 'misc') {
    my $dir = $self->{datadir} . '/' . $subdir;
    _find_txt($dir, $a_ref, $starttime) if (-d $dir);
  }
  for (@$a_ref) {
    if (m|/([^/]+)/[^/]+\.txt$|) {
      my $id = $1;
      $id =~ s|\+|/|g;
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
          $pages{$id}->{host} = $page->getHost || '';
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
  my $toPage = $self->getPage($id, $goodRevision);
  my $to = $toPage->_getText();
  $goodRevision = $toPage->getRevision if (!$goodRevision);

  my $fromrev = $diffRevision || $goodRevision - 1;
  my $from = $self->getPage($id, $fromrev)->_getText();

  require Text::Diff;
  Text::Diff::diff(\$from, \$to, {STYLE => "OldStyle"});
}

sub pageExists {
    my ($self, $id) = @_;
    my $file = $self->getPage($id)->_idPath() . '/current';
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
    my $path = "$datadir/$idSub/$id";
    my %dir;
    if (tie(%dir, 'IO::Dir', $path)) {
      for my $rev (keys %dir) {
        push(@revs, $`+0) if ($rev =~ /\.txt$/);
      }
      untie %dir;
    }
    @revs = (sort { $b <=> $a } @revs);
    $maxcount = $#revs if (!$maxcount || $#revs < $maxcount);
    my @revisions = ();
    for my $rev (@revs[0..$maxcount]) {
      my $page = $self->getPage($id, $rev);
      my ($pageUrl, $diffUrl, $editUrl);

      my $pageTime = $page->getTime();
      my $summary = $page->{changeSummary};
      push( @revisions,
            { revision => $rev,
              dateTime => UseModWiki::TimeToText($pageTime),
              host => $page->getHost,
              userId => $page->getUserID(),
              summary => ($summary && ($summary ne "*"))
                          ? UseModWiki::QuoteHtml($summary) : '',
            } );
    }
    @revisions;
}

package PurpleWiki::Archive::PlainTextPage;

# PurpleWiki Page Data Access

# $Id: Pages.pm 506 2004-09-22 07:31:44Z gerry $

use strict;
use base 'PurpleWiki::Page';

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
    my $rev = $self->{revision};
    $rev || $self->_currentRev;
}

sub _currentRev {
    my $self = shift;
    my $file = $self->_idPath . '/current';
    my $fh = IO::File->new($file);
    if ($fh) {
        my $v = <$fh>;
        $fh->close;
        return $& if ($v =~ /\d+/);
    }
    0;
}

# Gets the timestamp of this Page. 
sub getTime {
    my $self = shift;
    $self->_readMeta();
    $self->{timeStamp};
}

# Gets the hostname or IP
sub getHost {
    my $self = shift;
    $self->_readMeta();
    $self->{host};
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
 
  my $rev = $self->getRevision();
  my $file = $self->_idPath() . "/$rev.txt";
#print STDERR "_readPage($file, $rev)\n";
  my $fh = IO::File->new($file);
  return undef unless (defined($fh));
  $self->{text} = join("", (<$fh>));
  $fh->close;
  "";
}

sub _readMeta {
  my $self = shift;
  return if (defined($self->{changeSummary}));
 
  my $rev = $self->getRevision();
  my $file = $self->_idPath() . "/$rev.meta";
#print STDERR "_readMeta($file)\n";
  my $fh = IO::File->new($file);
  if ($fh) {
    while (<$fh>) {
      chomp();
      my ($k, $v) = split("=", $_, 2);
#print STDERR "RM:$k -> $v\n";
      $self->{$k} = $v;
    }
    $fh->close;
  }
}

sub _writePage {
  my $self = shift;
  my $text = shift;
  my $time = shift;
  my $rev = $self->getRevision();
  my $file = $self->_idPath() . "/$rev.txt";
  my $dir = $file;
  $dir =~ s|/[^/]*$||;
  File::Path::mkpath($dir);
#print STDERR "File mkpath: $file\n",join("\n", File::Path::mkpath($dir)),"\n";
  my $fh = IO::File->new(">$file");
  if ($fh) {
    print $fh $text;
    $fh->close;
  } else {
    print STDERR "_writePage:$file\nError:$!\n";
  }
  utime($time, $time, $file) if $time;
  $self->_writeCurrent($rev);
}

sub _writeCurrent {
  my $self = shift;
  my $rev = shift;
  my $file = $self->_idPath() . '/current';
  my $fh = IO::File->new(">$file");
  if ($fh) {
    print $fh $rev,"\n";
    $fh->close;
  } else {
    print STDERR "_writeCurrent:$file\nError:$!\n";
  }
}

sub _writeMeta {
  my $self = shift;
  my $hashref = shift;
  my $rev = $self->_currentRev;
  my $file = $self->_idPath() . "/$rev.meta";
  my $text = "";
  my $fh = IO::File->new(">$file");
  if ($fh) {
    for (sort keys %$hashref) {
        print $fh "$_=$$hashref{$_}\n";
    }
    $fh->close;
  }
}

sub _requestLock {
  my $self = shift;
  my $lock = $self->_idPath() . '/lock';
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
  my $lock = $self->_idPath() . '/lock';
  rmdir($lock);
}

sub _idPath {
  my $self = shift;
  my $id = $self->{id};
  my $idSub = ($id =~ /^[A-Za-z]/) ? uc($&) : 'misc';
  my $datadir = $self->{datadir};
  "$datadir/$idSub/$id";
}

#
# Filesystem structure:
# /[A-Z]/<id+>/<rev>.txt   Wikitext revisions
# /[A-Z]/<id+>/<rev>.meta  MetaData revisions
# /[A-Z]/<id+>/current     Wikitext Current (contains \d+ revision value)
# /[A-Z]/<id+>/lock        Individual page lock
#

1;
