# PurpleWiki::Search::Engine.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Engine.pm,v 1.4 2004/01/01 01:34:23 cdent Exp $

package PurpleWiki::Search::Engine;

use strict;
use PurpleWiki::Search::Result;

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

    $string .= '<ul>';
    foreach my $module (@{$self->{modules}}) {
        $string .= qq(<li><a href="#$module">$module</a></li>\n);
    }
    $string .= '</ul>';

    foreach my $module (@{$self->{modules}}) {
        $string .= qq(<h2><a name="$module">$module</a></h2>\n);

        foreach my $result (@{$self->{results}{$module}}) {
            my $url = $result->getURL();
            my $title = $result->getTitle();
            my $summary = $result->getSummary();

            # deal with null titles
            $title = $url unless $title;

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
