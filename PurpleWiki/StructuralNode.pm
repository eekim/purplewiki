# PurpleWiki::StructuralNode.pm
#
# $Id: StructuralNode.pm,v 1.4 2002/11/22 20:57:24 eekim Exp $
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

package PurpleWiki::StructuralNode;

use 5.006;
use strict;
use warnings;
use PurpleWiki::InlineNode;

our $VERSION = '0.1';

### constructor

sub new {
    my $this = shift;
    my (%attrib) = @_;
    my $self = {};

    # TODO: Type checking.
    $self->{'type'} = $attrib{'type'} if ($attrib{'type'});
    $self->{'id'} = $attrib{'id'} if ($attrib{'id'});
    $self->{'content'} = $attrib{'content'} if ($attrib{'content'});
    bless $self, $this;
    return $self;
}

### methods

sub insertChild {
    my $this = shift;
    my (%attrib) = @_;

    my $newNode = PurpleWiki::StructuralNode->new(%attrib);
    $newNode->{'parent'} = $this;
    push(@{$this->{'children'}}, $newNode);
    return $newNode;
}

sub parent {
    my $this = shift;
    return $this->{'parent'};
}

sub children {
    my $this = shift;
    if ($this->{'children'}) {
        return $this->{'children'};
    }
    else {
        return undef;
    }
}

### accessors/mutators

sub type {
    my $this = shift;

    $this->{'type'} = shift if @_;
    return $this->{'type'};
}

sub id {
    my $this = shift;

    $this->{'id'} = shift if @_;
    return $this->{'id'};
}

sub content {
    my $this = shift;

    $this->{'content'} = shift if @_;
    return $this->{'content'};
}

1;
__END__

=head1 NAME

PurpleWiki::StructuralNode - Structural node object

=head1 SYNOPSIS

  use PurpleWiki::StructuralNode;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Tree>.

=cut
