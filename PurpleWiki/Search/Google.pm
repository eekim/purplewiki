# PurpleWiki::Search::Google.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Google.pm,v 1.1 2004/01/01 01:20:35 cdent Exp $
#

package PurpleWiki::Search::Google;

use strict;
use base 'PurpleWiki::Search::Interface';
use PurpleWiki::Search::Result;

# Where the searching is done.
sub search {
    my $self = shift;
    my $query = shift;
    my @results;

    require SOAP::Lite;

    my $service = 'file:' . $self->{config}->GoogleWSDL();
    my $key = $self->{config}->GoogleKey();

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
