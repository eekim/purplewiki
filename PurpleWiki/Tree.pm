# PurpleWiki::Tree.pm
#
# $Id: Tree.pm,v 1.20 2002/12/11 03:06:00 cdent Exp $
#
# Copyright (c) Blue Oxen Associates 2002.  All rights reserved.
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

package PurpleWiki::Tree;

use 5.005;
use strict;
use PurpleWiki::InlineNode;
use PurpleWiki::StructuralNode;
use PurpleWiki::View::Debug;
use PurpleWiki::View::WikiHTML;
use PurpleWiki::View::WikiText;

### constructor

sub new {
    my $this = shift;
    my (%options) = @_;
    my $self;

    $self = {};
    $self->{'title'} = $options{'title'} if ($options{'title'});
    $self->{'lastNid'} = $options{'lastNid'} if ($options{'lastNid'});
    $self->{'rootNode'} = PurpleWiki::StructuralNode->new('type'=>'document');

    bless($self, $this);
    return $self;
}

### accessors/mutators

sub root {
    my $this = shift;

    return $this->{'rootNode'};
}

sub title {
    my $this = shift;

    $this->{'title'} = shift if @_;
    return $this->{'title'};
}

sub lastNid {
    my $this = shift;

    $this->{'lastNid'} = shift if @_;
    return $this->{'lastNid'};
}

### methods

sub view {
    my $this = shift;
    my ($driver, %params) = @_;

    if (lc($driver) eq 'debug') {
        return &PurpleWiki::View::Debug::view($this, %params);
    } 
    elsif (lc($driver) eq 'wikihtml') {
        return &PurpleWiki::View::WikiHTML::view($this, %params);
    }
    elsif (lc($driver) eq 'wiki') {
        return &PurpleWiki::View::WikiText::view($this, %params);
    }
}

1;
__END__

=head1 NAME

PurpleWiki::Tree - Basic PurpleWiki data structure

=head1 SYNOPSIS

  use PurpleWiki::Tree;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
