#
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# ??? - PurpleWiki
#
# $Id:  $
#
# Copyright (c) Blue Oxen Associates 2004.  All rights reserved.
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

package PurpleWiki::ParseRequest;

use PurpleWiki::Request;

sub new {
  my $proto = shift;
  my $config = undef;
  $config = shift if (ref($_[0]) eq "PurpleWiki::Config");
  my %args = @_;
  my $class = ref($proto) || $proto;
  my $self = {};

  my $pattern;
  if ($config) {
    #$pattern = $config->RequestPattern;
    $home = $config->HomePage;
    $self->{freelinks} = $config->FreeLinks();
    $self->{rcname} = $config->RCName();
  } else {
    $self->{freelinks} = 1;
    $self->{rcname} = 'RecentChanges';
  }
  $pattern = $args{Pattern} if (defined($args{Pattern}));
  $pattern = "" unless $pattern;
  $home = $args{HomePage} if (defined($args{HomePage}));
  $home = "" unless $home;
  $self->{pattern} = $pattern;
  $self->{home} = $home;
  $self->{actions} = {};
  bless $self, $class;
}

sub register {
  my ($self, $action, $method) = @_;
  ${$self->{actions}}{$action} = $method;
}

sub action {
  my ($self, $action) = @_;
  my $x = ${$self->{actions}}{$action};
#print STDERR "Getaction($action, $x)\n";
  $x;
}

# &FreeToNormal &BrowsePage &ValidIdOrDie
sub parseRequest {
  my $self = shift;
  my $context = shift;
  my $user = shift;
  my $config = $context->{config};
  my %args = @_;
  my ($q, $action, $revision, $search);
  my $id = '';

  if ($q = $args{cgi}) {
#print STDERR "CGI: ";
    if ($id = (!$q->param) ? $self->{home} : $q->param('keywords')) {
      $id = FreeToNormal($config, $id) if ($self->{freelinks});
      $args{action} = 'rc' if ($id eq $self->{rcname});
      return validRequest($id, $context, %args);
    }

    $action = lc($q->param('action'));
    $revision = $q->param('revision');
    $args{revision} = $revision if ($revision !~ /\D/);
    $action = 'rc' if ($id eq $self->{rcname});
    $args{action} = $action;
    $id = $self->{rcname} if ($action eq 'rc');

#print STDERR "$id\n" if ($action eq 'rc');
    if ($config->UseDiff) {
      if ( ($q->param('diff')
            || ((&PurpleWiki::GetParam($user, 'alldiff', 0) != 0)
               && &PurpleWiki::GetParam($user, 'defaultdiff', 1))
               && (($id ne $self->{rcname})
                   || !&PurpleWiki::GetParam($user, 'norcdiff', 1))) ) {
        $args{diffrevision} = $q->param('diffrevision') || '';
        $args{action} = 'diff';
#print STDERR "ActA:$args{action} ";
      }
    }

#print STDERR "Act0:$action ";
    if ($id = $q->param('id')) {
      $action = $args{action} = 'browse' unless ($action);
      $id = FreeToNormal($config, $id) if ($action eq 'browse' && $self->{freelinks});
      return validRequest($id, $context, %args);
    }

    if ($q->param('oldrev') ne '') {
      $id = $q->param('title') || '';
      $args{action} = 'dopost';
#print STDERR "Act6:$args{action} ";
      $args{text} = $q->param('text');
      $args{summary} = $q->param('summary');
      $args{oldrev} = $q->param('oldrev');
      $args{oldconflict} = $q->param('oldconflict');
      $args{action} = 'preview' if ($q->param('Preview'));
      return validRequest($id, $context, %args);
    }

    if ($self->{inames}) {
      my $iname;
      if ($iname = $q->param('xri_iname')) {
        $args{xsid} = $q->param('xri_xsid');
        $args{iname} = $iname;
        $args{action} = 'iname';
#print STDERR "Act1:$args{action} ";
      } elsif ($self->{inames} && ($iname = $q->param('iname'))) {
        $args{localid} = $q->param('local_id');
        $args{rrsid} = $q->param('rrsid');
        $args{action} = 'associateiname';
#print STDERR "Act2:$args{action} ";
      }
    }

    $args{id} = $id;
    if ($q->param('edit_prefs')) {
      $args{action} = 'updateprefs';
#print STDERR "Act3:$args{action} ";
    } elsif ($q->param('enter_login')) {
      $args{action} = 'dologin';
#print STDERR "Act4:$args{action} ";
    } elsif ( defined($search = $q->param('search'))
             || ($q->param('dosearch') ne '') ) {
      $args{action} = 'dosearch';
#print STDERR "Act5:$args{action} ";
      $args{search} = $search || '';
    }
  } elsif ($q = $args{argv}) {
    grep(/^-/ && ($args{$'} = $q->{$_}), (keys %$q));
  } else { return undef; }
if (!$args{action}) {
  print STDERR "No action: ",join(", ", %args),"\n";
  $args{action} = 'browse';
}
#else{  print STDERR "action:$args{action} ",join(", ", %args),"\n"; }
  return new PurpleWiki::Request($context, %args);
}

sub FreeToNormal {
  my ($config, $id) = @_;

  $id =~ s/ /_/g;
  $id = ucfirst($id);
  if (index($id, '_') > -1) {  # Quick check for any space/underscores
    $id =~ s/__+/_/g;
    $id =~ s/^_//;
    $id =~ s/_$//;
    if ($config->UseSubpage) {
      $id =~ s|_/|/|g;
      $id =~ s|/_|/|g;
    }
  }
  if ($config->FreeUpper) {
    # Note that letters after ' are *not* capitalized
    if ($id =~ m|[-_.,\(\)/][a-z]|) {    # Quick check for non-canonical case
      $id =~ s|([-_.,\(\)/])([a-z])|$1 . uc($2)|ge;
    }
  }
  return $id;
}

# validate the id
sub validRequest {
  my $id = shift;
  my $context = shift;
  my %args = @_;
  my $error;

#print STDERR "Edit($id)\n" if ($args{action} eq 'edit');
  $args{id} = $id;
  if (length($id) > 120) {
    $error = "pageNameTooLong";
  } elsif ($id =~ m| |) {
    $error = "pageNameTooManyChars";
  } elsif ($id =~ /^\//) {
    $error = "pageNameNoMainPage";
  } elsif ($id =~ /\/$/) {
    $error = "pageNameMissingSubpage";
  } elsif (!$args{action}) {
    $args{action} = 'browse';
  }
  $args{error} = $error if $error;
#print STDERR "New Request ($context",join(", ", (%args)),")\n";
  return new PurpleWiki::Request($context, %args);
}

1;
