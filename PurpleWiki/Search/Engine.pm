# PurpleWiki::Search::Engine.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Engine.pm,v 1.1 2003/12/31 08:02:51 cdent Exp $

package PurpleWiki::Search::Engine;

use strict;
use PurpleWiki::Search::Result;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};

    bless ($self, $class);

    my %params = @_;

    $self->{config} = $params{config};

    $self->{modules} = $self->{config}->SearchModule();

    return $self;
}

sub search {
    my $self = shift;
    my $query = shift;

    foreach my $module (@{$self->{modules}}) {
        my $class = "PurpleWiki::Search::$module";
        eval "require $class";

        my $searcher = $class->new(config => $self->{config});

        $self->{results}{$module} = [ $searcher->search($query) ];
    }

    return $self;
}

# string asHTML
sub asHTML {
    my $self = shift;

    my $string;

    foreach my $module (@{$self->{modules}}) {
        $string .= "<h2>$module</h2>\n";

        foreach my $result (@{$self->{results}{$module}}) {
            my $url = $result->getURL();
            my $title = $result->getTitle();
            my $summary = $result->getSummary();

            $string .=<<"EOT";
<p class="searchresult"><a href="$url">$title</a><br />
$summary</p>
EOT
        }
        $string .= "\n";
    }

    return $string;
}


1;
