# PurpleWiki::Search::Result.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Result.pm,v 1.4 2004/01/21 23:24:08 cdent Exp $
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

use vars qw($VERSION);
$VERSION = '0.9.1';

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

Encapsulates a single search result to be used by the 
L<PurpleWiki::Search::Engine> module search system.

=head1 DESCRIPTION

PurpleWiki::Search::Results provides an extensible class for
containing search results, one result per object.

Each object contains the following required fields:

=over 4

=item URL

The URL of the entity where the content of the result can be found.

=back

In addition there are the following optional fields:

=over 4

=item Title

The title of the entity where the content of the result can be 
found. If no title is provided, the URL will be displayed in
the results.

=item Summary

A short textual summary string from the content of the result. Some
modules use the first N characters. Others use text surrounding the
query string.

=item Modified Time

A epoch time representation of the last modified date of the result
entity.

=back

Classes which subclass L<PurpleWiki::Search::Interface> return a 
list of PurpleWiki::Search::Result objects. Those classes are
responsible for filling in the fields of each object and ordering
the resulting list.

=head1 METHODS

=over 4

=item new()

Creates a new Result object.

=item setURL($url)

Sets the URL of the object. No checking is performed.

=item setTitle($title)

Sets the title of the object. There are no explicit length
restrictions.

=item setSummary($summary)

Sets the summary of the object. There are no explicit length
restrictions.

=item setModifiedTime($epochTime)

Sets the Modified Time of the object to the provide epoch time
(number of seconds since midnight, 1st of January 1970).

=item getURL, getTitle, getSummary, getModifiedTime

Access the stored URL, Title, Summary and Modified Time values.

=back


=head1 SEE ALSO

L<PurpleWiki::Search::Engine>
L<PurpleWiki::Search::Interface>

=head1 AUTHOR

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=cut
