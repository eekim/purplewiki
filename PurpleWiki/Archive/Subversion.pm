# PurpleWiki::SVNArchive
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: SVNArchive.pm 506 2004-09-22 07:31:44Z gerry $
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
$VERSION = sprintf("%d", q$Id: SVNArchive.pm 506 2004-09-22 07:31:44Z gerry $ =~ /\s(\d+)\s/);

package PurpleWiki::Archive::Subversion;

use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;

use SVN::Fs;
use SVN::Delta;
use SVN::Repos;
use SVN::Core;

require "timelocal.pl";

sub new {
  my $proto = shift;
  my $config = undef;
  $config = shift if (ref($_[0]) eq "PurpleWiki::Config");
  my %args = @_;
  my $class = ref($proto) || $proto;
  my $self = {};

  my ($reposdir, $reposPath) = ('', '');
  if ($config) {
    $reposdir = $config->DataDir;
    $reposPath =  $config->ReposPath || '';
  } else {
    my $x;
    $reposdir = $x if (defined($x=$args{DataDir}));
    $reposPath = $x if (defined($x=$args{ReposPath}));
  }
  die "No config or data dir defined\n" unless $reposdir;

  substr($reposPath,-1) = '' if (substr($reposPath,-1) eq '/');
  $self->{reposPath} = $reposPath;
#print STDERR "P:$reposPath\n";
  $self->{repository} = $reposdir;
  bless $self, $class;
  return undef unless ($self->_init($reposdir, $args{create}));
  $self;
}

sub _init {
  my $self = shift;
  my $path = shift;
  my $create = shift;

  if ($create && !-d "$path/db") {
    if (!-d $path) {
      mkdir $path || die "Can't create $path $!\n";
    }
    my $repos = $self->{repos_ptr}
              = SVN::Repos::create($path, undef, undef, undef, undef)
                || die "Can't create repository";
  }
  if (!-d "$path/db") {
      die "No repository $path\n";
  }
      
  my $repos = $self->{repos_ptr} = SVN::Repos::open($path);
  return undef unless $repos;
  $self->{fs_ptr} = $repos->fs();
  1;
}

sub getPage {
  my $self = shift;
  my $id = shift;
  my $rev = shift;

  my $path = $self->_repos_path($id);
  my $root = $self->_get_root($rev);
  my $check = $root->check_path($path);
  if ($check == $SVN::Node::none) {
    return PurpleWiki::Archive::SubversionPage->new(id=>$id,
                                    revision=>$self->_currentRev, time=>time,
                                    wikitext=>'Describe the new page here.');
  } elsif ($check != $SVN::Node::file) {
    return '';
  }
  my $file = $root->file_contents($path);

  my $curRev = $rev || $self->_currentRev;
  $rev = $root->node_created_rev($path);
  my $lastmod = _svn_time($fs = $self->{fs_ptr}->revision_prop($rev, "svn:date"));
  local $/ = '';
  my $contents = '';
  do {
    my $chunk = '';
    $file->read($chunk, 1024);
    $contents .= $chunk;
  } while (length($chunk) == 1024);
#print STDERR "Root:",ref($root),":$path:$check:Rv:$rev:Lm:$lastmod:",length($contents),"\n";
  $file->close();
#print STDERR "Cont:$contents=\n";
  return PurpleWiki::Archive::SubversionPage->new(id=>$id, wikitext=>$contents,
                                  time=>$lastmod, revision=>$curRev);
}

sub _repos_path {
  my $self = shift;
  my $id = shift;
  $id =~ s|/|\+|g;
  "$self->{reposPath}/$id";
}

sub _get_root {
  my $self = shift;
  my $rev = shift;

#print STDERR "rev:$rev:";
  $rev = $self->_currentRev unless $rev;
#print STDERR "$rev\n";
  return $self->{fs_ptr}->revision_root($rev);
}

sub _currentRev {
  shift->{fs_ptr}->youngest_rev()
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
#print STDERR "putPage(";for (keys %args) { print STDERR "$_ => $args{$_}, "; }
#print STDERR ")\n";
  my $tree = $args{tree};
  return "No data" unless (defined($tree));
  my $contents = $tree->view('wikitext');
  $contents .= "\n"  unless (substr($contents, -1, "\n"));

  my $id = $args{pageId};
  my $repos_path = $self->_repos_path($id);
  my $user = $args{userId};
  my $root = $self->_get_root();
  my $check = $root->check_path($repos_path);
  my $page = $self->getPage($id, $rev);
  my $old_contents = $page->_getText();

  return "" if ($contents eq $old_contents);

  # this rev is created from oldrev if supplied, so apply change to that rev
  # in theory if this one isn't current it will flag the conflict so we will
  # need to deal with that later.
  my $rev = $args{oldrev} || $self->_currentRev;
  my $repos = $self->{repos_ptr};
  $args{host} =  $ENV{REMOTE_ADDR} unless ($args{host});
  my $log_msg = $args{changeSummary};
  my $cur = $self->_currentRev;
#print STDERR "Txn[$id]$rev:$cur\n";
#print STDERR "Conflict $rev, $cur\n" if ($rev < $cur);
  return "Conflict\n" if ($rev < $cur);
  my $txn = $repos->fs_begin_txn_for_commit($rev, "$user:$host", $log_msg);
  my $root = SVN::Fs::txn_root($txn);

  if ($check != $SVN::Node::file) {
      if ($check == $SVN::Node::none) {
        my @path = split("/", $self->{reposPath});
        my $d;
        while (@path > 1
               && $root->check_path($d=join("/", @path)) == $SVN::Node::none) {
#print STDERR "make_dir $d\n";
          $root->make_dir($d);
        }
#print STDERR "make_file $repos_path\n";
        $root->make_file($repos_path);
        $root->change_node_prop($repos_path, 'svn:eol-style', 'native');
      } else {
        $root->abort_txn();
        return "Collision, non-file at $repos_path ($check)";
      }
  }

  my ($tx_handler, $tx_baton) = $root->apply_textdelta($repos_path, undef, undef);
  SVN::TxDelta::send_string($contents, $tx_handler, $tx_baton);

  #for my $pname ('userId', 'host', 'changeSummary' ) {
  #    my $pval = $args{$pname};
  #    $props{$pname} = (defined($pval)) ? $pval : $page->{$pname};
  #}
  #for my $pname (keys %props) {
  #    $root->change_node_prop($repos_path, 'purple:'.$pname, $props{$pname})
  #        if (defined($props{$pname}));
  #}
#print STDERR "Sent props\n";

  $repos->fs_commit_txn($txn);
#print STDERR "Committed $id ",$self->_currentRev,"\n";
  return "";
}

sub deletePage {
  my $self = shift;
  my $id = shift;

  my $repos_path = $self->_repos_path($id);
  my $root = $self->_get_root();
  my $check = $root->check_path($repos_path);

  return "" if ($check != $SVN::Node::file);

  my $repos = $self->{repos_ptr};
  my $txn = $repos->fs_begin_txn_for_commit($self->_currentRev, "", "Delete page");
  my $root = SVN::Fs::txn_root($txn);

  $root->delete($repos_path);
  $repos->fs_commit_txn($txn);
#print STDERR "Committed $id ",$self->_currentRev,"\n";
  return "";
}

sub allPages {
  my $self = shift;
  my $root = $self->_get_root();
  my $rpath = $self->{reposPath};
  return () if ($root->check_path($rpath) != $SVN::Node::dir);
  my $h = ($root->dir_entries($rpath));
#print STDERR "allPages:\n ",join("\n ", (keys %$h)),"\n::\n";
  my @l = (keys %$h);
  grep(s|\+|/|g, @l);
  (sort @l);
}

# pages->recentChanges($starttime)
sub recentChanges {
  my $self = shift;
  my $starttime = shift;
  local @rc = ();
  my $done = 0;
  my $rpath = $self->{reposPath};
  local $pages = {};
  sub receiver1 {
    #Log:Paths:rev:user:time-2004-10-03T18:55:34.237081Z:log:_p_apr_pool_t=SCALAR(0x8a37064)
    return if ($done);
    my $h = $_[0];
    my $t = _svn_time($_[3]);
    if ($t < $starttime) {
      $done = 1;
      return;
    }
#print STDERR "Log:",join(":",@_),"\n";
    for my $p (keys %$h) {
      next unless ($p =~ /^$rpath\//);
      $id = $';
      if (defined($pages->{$p})) {
        $pages->{$p}->{numChanges}++;
      } else {
        push(@rc, $p);
        $pages->{$p} = { numChanges => 1, pageId => $id };
#print STDERR "Got $id ",$$h{$p}->action,"\n";
        $pages->{$p}->{timeStamp} = $t;
        $pages->{$p}->{changeSummary} = $_[4];
        $pages->{$p}->{userId} = $_[2];
        ($pages->{$p}->{userId}, $pages->{$p}->{host}) = ($`, $')
            if ($pages->{$p}->{userId} =~ /:/);
      }
    }
  }

  $starttime = 0 unless $starttime;
  #$repos->get_logs([paths],start,end,disc,strict,&receiver);
  $self->{repos_ptr}->get_logs("", $self->_currentRev, 1, 1, 1, \&receiver1);
  my $r = [ map($pages->{$_}, @rc) ];
#print STDERR "Rc:",join(":", @rc),"\n::\nPP:",join(":", @$r),"\n";
  $r;
}

sub _svn_time {
  my $t = shift;
  if ($t =~ /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)\.\d+Z/) {
    $t = timegm($6,$5,$4,$3,$2-1,$1,0);
  } else { print SDTERR "Bad date:$t\n"; }
  $t;
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
  my $root = $self->_get_root();
  ($root->check_path($self->_repos_path($id)) == $SVN::Node::file);
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
  my $maxcount = shift || 0;
  my $count = 1;

  local @response = ();
  sub receiver2 {
    #Log:Paths:rev:user:time-2004-10-03T18:55:34.237081Z:log:_p_apr_pool_t=SCALAR(0x8a37064)
    my ($p, $r, $u, $t, $l) = @_;
    return if ($maxcount && $maxcount < $count++);
    $t = _svn_time($t);
    $u =~ s/:.*$//;
#print STDERR "log (r=>$r, u=>$u, t=>$t, s=>$l) $#response\n";
    push( @response, {revision=>$r, user=>$u,
                      dateTime=>UseModWiki::TimeToText($t), summary=>$l} );
  }

  my $repos = $self->{repos_ptr};
  my $path = $self->_repos_path($id);
  my $curRev = $self->_currentRev;
  $repos->get_logs($path, $curRev, 1, 0, 1, \&receiver2);

  return @response;
}

package PurpleWiki::Archive::SubversionPage;

# PurpleWiki Page Data Access

# $Id: SVNArchive.pm 506 2004-09-22 07:31:44Z gerry $

use strict;

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
  $self->{ip};
}

# page->getUserID()
sub getUserID {
    my $self = shift;
    $self->{userID};
}

# Returns the revision of this Page.
sub getRevision {
    shift->{revision};
}

# Gets the timestamp of this Page. 
sub getTime {
    shift->{time};
}

#
# page->_getText([revision])
#
sub _getText {
    shift->{wikitext};
}

sub getTree {
  my $self = shift;
  my $tree = $self->{tree};
  return $tree if $tree;
  my $parser = new PurpleWiki::Parser::WikiText;
  my $text = $self->_getText();
#print STDERR "Tree:$text=\n";
  return "" unless $text;
  $self->{tree} = $parser->parse($text, 'add_node_ids' => 0);
#print STDERR "After:",$self->{tree}->view('wikitext'),"\n";
  $self->{tree};
}

# Retrieves the page id.
sub getID {
    return shift->{id};
}

1;

__END__

$repos = $pages->{repos} = ???
    subwiki.util.Repository(cfg.general.repos, $pool)
$root = $repos->get_root()
$check = SVN::fs::check_path($root, $repos_path, $pool)
# constant: svn.util.svn_node_none
#           svn.util.svn_node_file:
($content_stream, $lastmod) = $repos->get_file($repos_path, $rev)
$old_contents = $content_stream->read()

$txn = SVN::Repos->svn_repos_fs_begin_txn_for_commit($repos->repos_ptr,
                                                      $repos->youngest,
                                                      $author,
                                                      $log_msg,
                                                      $pool)
    $root = SVN::Fs::txn_root($txn, $pool)

    if is_add:
      SVN::Fs::make_file($root, $repos_path, $pool)
      SVN::Fs::change_node_prop($root, $repos_path, 'svn:eol-style', 'native',
                          $pool)

    if is_mod or is_add:
      ($tx_handler, $tx_baton) = SVN::Fs::apply_textdelta($root,
                                                $repos_path,
                                                undef, undef,
                                                $pool)

      SVN::Delta::send_string($new_contents,
                                    $tx_handler, $tx_baton,
                                    $pool)


    for (pname, pval) in props:
      SVN::Fs::change_node_prop(root, handler.repos_path, pname, pval, app.pool)

    SVN::Repos::fs_commit_txn(app.repos.repos_ptr, txn)


view/edit:
    ($contents, $lastmod) = $repos->get_file($repos_path, $rev)
  $contents = $contents->read()


 svn.util.run_app(_do_index, cfg, revision)
 svn.util.run_app(_run_handler, handler_factory, cfg_path)
 svn.fs.node_prop(root, base+path, pname, self.pool)

subwiki.util:
Repository
FileNameParser
ReposReader

class Repository:
init:

  def get_root(self, rev=None, pool=None):
    if rev is None:
      rev = self.youngest

      return $self->fs_ptr->revision_root(rev)


  def get_file(self, repos_path, rev=None, pool=None):
    root = self.get_root(rev, pool)

    file =  fs.file_contents(root, repos_path, pool)

    created_rev = fs.node_created_rev(root, repos_path, pool)
    lastmod = fs.revision_prop(self.fs_ptr, created_rev,
                               svn.util.SVN_PROP_REVISION_DATE, pool)

    return svn.util.Stream(file), iso8601time(lastmod, pool)

  def read_file(self, repos_path, pool):
    root = self.get_root(self.youngest, pool)

    # fetch the file information
    stream = fs.file_contents(root, repos_path, pool)
    size = fs.file_length(root, repos_path, pool)

    # return the entire file contents
    return svn.util.svn_stream_read(stream, size)

  def get_history(self, repos_path=None, pool=None):

    response = []
    def collect_logs(paths, rev, author, date, log, pool, response=response):
      response.insert(0, _item(rev=rev, author=author,
                               date=iso8601time(date, pool), log=log))

    repos.svn_repos_get_logs(self.repos_ptr, paths, 0, self.youngest,
                             0, 0, collect_logs, pool)

    return response, response[0].date

  def get_properties(self, path, rev=None, get_props=None, pool=None):
    """Get the properties of the specified path"""

    if pool is None:
      pool = self.pool

    root = self.get_root(rev, pool)
    props = []
    if get_props:
      getp = {}
      getp.fromkeys(get_props, True)
    for (pname, pval) in svn.fs.node_proplist(root, path, pool).items():
      if pname[:8] == 'subwiki:':
        pname = pname[8:]
        if pname and (not get_props or pname in getp):
          props.append( _item(key=pname, value=pval,
                              display=_property_display.get(pname,pname)) )
    return props

  def get_dir(self, path, rev=None, pool=None):
    if pool is None:
      pool = self.pool

    root = self.get_root(rev, pool)
    return map((lambda a: _item(name=a)),
               svn.fs.dir_entries(root, path, pool).keys())

  def get_dir_str(self, path, rev=None, pool=None):
    if pool is None:
      pool = self.pool

    root = self.get_root(rev, pool)
    return svn.fs.dir_entries(root, path, pool).keys()

class FileNameParser:
      Filesystem paths                     /some/path
      Repository paths                     {repos}/some/path
      Paths relative to the install root   {install}/some/path

