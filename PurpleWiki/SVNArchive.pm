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
$VERSION = sprintf("%d", q$Id: Pages.pm 506 2004-09-22 07:31:44Z gerry $ =~ /\s(\d+)\s/);

package PurpleWiki::SVNArchive;

use PurpleWiki::Config;
use PurpleWiki::Search::Result;
use PurpleWiki::Parser::WikiText;

use SVN::Fs;
use SVN::Delta;
use SVN::Repos;
use SVN::Core;

sub new {
  my $proto = shift;
  my $config = shift;
  die "No config\n" unless $config;
  my $class = ref($proto) || $proto;
  my $self = {};

  $self->{script} = $config->ScriptName;
  my $dir = $self->{repos_dir} = $config->ReposDir;
  my $loc = $config->DataDir;
  $loc .= '/' unless (substr($loc,-1) eq '/');
  $self->{repos_loc} = $loc;
  return undef unless $self->_init($dir);
  bless $self, $class;
  $self;
}

sub _init {
  my $self = shift;
  my $path = shift;

  my $repos = $self->{repos_ptr} = SVN::Repos::open(path)
  return undef unless $repos;
  my $fs_ptr = $self->{fs_ptr} = $repos->fs()
  $self->{youngest} = $fs_ptr->youngest_rev()
  1;
}

sub getPage {
  my $self = shift;
  my $id = shift;
  my $rev = shift;

  $self->_get_page($self->_repos_path($id), $rev);
}

sub _repos_path {
  my $self = shift;
  my $id = shift;
  "$self->{repos_loc}/$id";
}

sub _get_page {
  my $self = shift;
  my $path = shift;
  my $rev = shift;

  my $root = $self->_get_root($rev);
  my $fs = $self->{fs_ptr};
  my $file =  $fs->file_contents($root, $path);

  $rev = $fs->node_created_rev($root, $path)
  my $lastmod = $fs->revision_prop($self->{fs_ptr}, $rev,
                                   SVN::Core::REVISION_DATE);
  my $contents = $file->read();
  $file->close();
  return PurpleWiki::SVNPage->new(wikitext=>$contents, time=>$lastmod, rev=>$rev);
}

sub _get_root {
  my $self = shift;
  my $rev = shift;

  $rev = $self->{youngest} unless $rev;

  return $self->{fs_ptr}->revision_root(rev)
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
  return "No data" unless (defined($tree));
  my $contents = $tree->view('wikitext');
  $contents .= "\n"  unless (substr($contents, -1, "\n"));

  my $id = $args{id};
  my $repos_path = $self->_repos_path($id);
  my $now = $args{timestamp};
  my $root = $self->_get_root()
  my $user = $args{userId};
  my $check = $self->{fs_ptr}->check_path($root, $repos_path)
# constant: svn.util.svn_node_none
#           svn.util.svn_node_file:
  my $page = $repos->_get_page($repos_path, $rev)
  my $old_contents = $page->_getText();

  return "" if ($contents eq $old_contents);

  my $rev = $args{oldrev} || $repos->youngest;
  my $txn = $repos->fs_begin_txn_for_commit($rev, $user, $log_msg);
  my $fs = $self->{fs_ptr};
  my $root = $fs->txn_root($txn);

  if ($check != SVN::Node::File) {
      $fs->make_file($root, $repos_path)
      $fs->change_node_prop($root, $repos_path, 'svn:eol-style', 'native')
  }

  ($tx_handler, $tx_baton) = $root->apply_textdelta($repos_path, undef, undef)

  $root->send_string($wikitext, $tx_handler, $tx_baton);

  $args{host} =  $ENV{REMOTE_ADDR} unless ($args{host});
  my %props = ( ts => $now, contents => $contents, name => $id, id => $id );
  for my $pname ('revision', 'userId', 'ip', 'host', 'changeSummary' ) {
      my $pval = $args{$pname};
      $props{$pname} = (defined($pval)) ? $pval : $page->{$pname};
  }
  for my $pname (keys %props) {
      $root->change_node_prop($repos_path, 'purple:'.$pname, $props{$pname})
          if (defined($props{$pname}));
  }

  $root->commit_txn($repos, $txn);

  return "";
}

sub allPages {
  my $self = shift;
  my $root = $self->_get_root(rev);
  ($self->{fs_ptr}->dir_entries($self->_repos_path("")).keys());
}

# pages->recentChanges($starttime)
sub recentChanges {
  my $self = shift;
  my $starttime = shift;
  my $config = $self->{config} || PurpleWiki::Config->instance();
  my %params = @_;
  $starttime = 0 unless $starttime;
  #PurpleWiki::Database::recentChanges($config, $starttime);
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

sub pageExists {
    my ($self, $id) = @_;
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
    my @pageHistory = ();
}

#sub _getRevisionHistory {
#    my ($self, $id, $section, $isCurrent) = @_;
#    return { revision => $rev,
#             dateTime => UseModWiki::TimeToText($ts),
#             host => $host,
#             user => $user,
#             summary => $summary,
#             pageUrl => $pageUrl,
#             diffUrl => $diffUrl,
#             editUrl => $editUrl };
#}

# Retrieves the default text data by getting the
# Section and then the text in that Section.
# pages->getPageNode($Id, $nid)
#
# get just one node
#
#sub getPageNode {
#  my ($self, $id, $nid) = @_;
#  my $page = $self->getPage($id);
#  my $tree = $page->getTree();
##print STDERR "getPageNode:$pages Pg:$page Tr:$tree Id:$id Nid:$nid\n";
#  return $tree->view('subtree', 'nid' => uc($nid)) if ($tree);
#  ""
#}

package PurpleWiki::SVNPage;

# PurpleWiki Page Data Access

# $Id: Pages.pm 506 2004-09-22 07:31:44Z gerry $

use strict;

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
}

# Gets the timestamp of this Page. 
sub getTime {
    my $self = shift;
}

#
# page->_getText([revision])
#
sub _getText {
    my $self = shift;
}

# page->getWikiHTML()
#
# format the page for HTML output
#
#sub getWikiHTML {
#    my $self = shift;
#
#    my $url = $self->{pages}->{script} . '?' . $self->{id};
#    my $parser = PurpleWiki::Parser::WikiText->new();
#    my $wiki = $parser->parse($self->_getText(),
#                   add_node_ids => 0,
#                   url => $url,
#               );
#    return $wiki->view('wikihtml', url => $url);
#}

sub getTree {
  my $self = shift;
  my $tree = $self->{tree};
  return $tree if $tree;
  my $parser = new PurpleWiki::Parser::WikiText;
  my $text = $self->_getText();
  return "" unless $text;
  return $parser->parse($text, 'add_node_ids' => 0);
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

