# PurpleWiki::Search::Engine.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Engine.pm,v 1.5 2004/01/05 22:11:28 eekim Exp $
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

package PurpleWiki::Search::Engine;

use strict;
use PurpleWiki::Search::Result;

sub new {
    my $class = shift;
    my $self = {};

    bless ($self, $class);

    my %params = @_;

    $self->{config} = $params{config};

    $self->{modules} = $self->{config}->SearchModule;

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
            my $url = $result->getURL;
            my $title = $result->getTitle;
            my $summary = $result->getSummary;
            my $mtime = $result->getModifiedTime;

            # deal with null titles
            $title = $url unless $title;

            $string .= qq{<p class="searchresult"><a href="$url">$title</a>};
            $string .= ' -- <i>' . &_date($mtime) . '</i>' if ($mtime);
            $string .=<<"EOT";
<br />
$summary</p>
EOT
        }
        $string .= "\n";
    }

    return $string;
}

sub _date {
    my $ts = shift;
    my @datetime = localtime($ts);
    my %monthNames = (
        0 => 'Jan',
        1 => 'Feb',
        2 => 'Mar',
        3 => 'Apr',
        4 => 'May',
        5 => 'Jun',
        6 => 'Jul',
        7 => 'Aug',
        8 => 'Sep',
        9 => 'Oct',
        10 => 'Nov',
        11 => 'Dec');
    my $year = 1900 + $datetime[5];
    my $month = $monthNames{$datetime[4]};
    my $day = $datetime[3];

    return "$month $day, $year";
}

1;
__END__

=head1 NAME

PurpleWiki::Search::Engine - Wiki search engine.

=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 METHODS



=head1 AUTHOR

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Search::Result>.

=cut
