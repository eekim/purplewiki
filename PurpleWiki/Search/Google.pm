# PurpleWiki::Search::Google.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Google.pm,v 1.3 2004/01/21 23:24:08 cdent Exp $
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

package PurpleWiki::Search::Google;

use strict;
use base 'PurpleWiki::Search::Interface';
use PurpleWiki::Search::Result;

use vars qw($VERSION);
$VERSION = '0.9.2';

# Where the searching is done.
sub search {
    my $self = shift;
    my $query = shift;
    my @results;

    require SOAP::Lite;

    my $service = 'file:' . $self->config()->GoogleWSDL();
    my $key = $self->config()->GoogleKey();

    return @results unless $key;

    my $result = SOAP::Lite
        -> service($service)
        -> doGoogleSearch($key, $query, 0, 10, 0, '', 0, '',
            'latin1', 'latin1');

    if (@{$result->{resultElements}} > 0) {
        foreach my $element (@{$result->{resultElements}}) {
            my $result = new PurpleWiki::Search::Result;
            $result->setURL($element->{URL});
            $result->setTitle($element->{title});
            $result->setSummary($element->{snippet});
            push(@results, $result);
        }
    }

    return @results;
}

1;

__END__

=head1 NAME

PurpleWiki::Search::Google = Search google from PurpleWiki

=head1 SYNOPSIS

This module includes the top ten results from google.com for 
a query when performing a search in PurpleWiki.

=head1 DESCRIPTION

Search results from google.com can be accessed the SOAP remote
API. This module uses that API to pass a query from PurpleWiki
to google to retrieve the top ten results.

To enable this search changes must be made to the PurpleWiki
configuration file, F<config>:

  SearchModule = Google
  GoogleWSDL = /path/to/GoogleSearch.wsdl
  GoogleKey = <google API key>

To get a google API key, visit http://www.google.com/apis/

=head1 METHODS

See L<PurpleWiki::Search::Interface>.

=head1 AUTHOR

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Search::Interface>.
L<PurpleWiki::Search::Results>.
L<PurpleWiki::Search::Engine>.

=head1 TO DO

Number of results should be configurable.
