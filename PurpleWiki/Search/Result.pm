# PurpleWiki::Search::Result.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Result.pm,v 1.2 2004/01/05 22:11:28 eekim Exp $
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

package PurpleWiki::Search::Result;

use strict;

sub new {
    my $class = shift;
    my $self = {};

    my %params = @_;

    bless ($self, $class);

    return $self;
}

sub setTitle {
    my $self = shift;

    $self->{title} = shift;
    return $self;
}

sub setURL {
    my $self = shift;

    $self->{URL} = shift;
    return $self;
}

sub setSummary {
    my $self = shift;

    $self->{summary} = shift;
    return $self;
}

sub setModifiedTime {
    my $self = shift;

    $self->{mtime} = shift;
    return $self;
}

sub getTitle {
    my $self = shift;
    return $self->{title};
}

sub getURL {
    my $self = shift;
    return $self->{URL};
}

sub getSummary {
    my $self = shift;
    return $self->{summary};
}

sub getModifiedTime {
    my $self = shift;
    return $self->{mtime};
}

1;
__END__

=head1 NAME

PurpleWiki::Search::Result - Class for search results.

=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 METHODS



=head1 AUTHOR

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=cut
