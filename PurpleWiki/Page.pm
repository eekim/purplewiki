# PurpleWiki::Page.pm
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2004.  All rights reserved.
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

package PurpleWiki::Page;

use 5.005;
use strict;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

### constructor

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

### accessors/mutators

sub getId {
    return shift->{id};
}

sub getUserId {
    return shift->{userId};
}

sub getRevision {
    return shift->{revision};
}

sub getTime {
    return shift->{timestamp};
}

sub getHost {
    return shift->{host};
}

sub getSummary {
    return shift->{changeSummary};
}

sub getTree {
    return shift->{tree};
}

1;
__END__

=head1 NAME

PurpleWiki::Page - Simplest Page class possible

=head1 SYNOPSIS

  use PurpleWiki::Archive::PlainText;  # backends return Page objects

  my $pages = PurpleWiki::Archive::PlainText->new;
  my $page = $pages->getPage('FrontPage');

  print $page->getId . "\n";
  print $page->getRevision . "\n";
  print $page->getTime . "\n";
  print $page->getUserId . "\n";
  print $page->getHost . "\n";
  print $page->getSummary . "\n";
  print $page->getTree->view('wikihtml') . "\n";

=head1 DESCRIPTION

PurpleWiki::Page is the simplest page class possible, suitable for any
Archive backend.  Also defines the interface for all Page classes.
The default Archive backends that come with PurpleWiki use
PurpleWiki::Page as a base class, overloading the methods in order to
achieve some performance trickery.  However, this is not necessary.
You can write an Archive backend that uses this Page class.

=head1 METHODS

=head2 new({ id => $id, revision => $revision, userId => $userId, host => $host, timeStamp => $timeStamp, tree => $tree})

Constructor.  We did not define any mutators for the Page class, so
all parameters must be passed via the constructor.

=head2 Accessors

 getId()
 getUserId()
 getRevision()
 getHost()
 getTime()
 getSummary()
 getTree()

Accessors for all the various fields.

=head1 AUTHORS

Gerry Gleason, E<lt>gerry@geraldgleason.comE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Archive::Base>.

=cut
