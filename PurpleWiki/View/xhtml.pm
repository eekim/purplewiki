# PurpleWiki::View::xhtml.pm
#
# $Id: xhtml.pm,v 1.1.4.2 2003/05/31 02:37:31 cdent Exp $
#
# Copyright (c) Blue Oxen Associates 2002-2003.  All rights reserved.
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

package PurpleWiki::View::xhtml;

use 5.005;
use strict;
use PurpleWiki::Page;
use PurpleWiki::Tree;
use PurpleWiki::View::EventHandler;
use PurpleWiki::View::wikihtml;

# functions

sub view {
    my ($wikiTree, %params) = @_;

    &PurpleWiki::View::wikihtml::registerHandlers;
    return &_htmlHeader($wikiTree, %params) .
        &PurpleWiki::View::EventHandler::view($wikiTree, %params) .
        &_htmlFooter;
}

# private

sub _htmlHeader {
    my ($wikiTree, %params) = @_;
    my $outputString;

    $outputString = "<html>\n<head>\n";
    $outputString .= '<title>' . $wikiTree->title . "</title>\n"
        if ($wikiTree->title);
    if ($params{css_file}) {
        $outputString .= '<link rel="stylesheet" href="';
        $outputString .= $params{css_file};
        $outputString .= '" type="text/css" />' . "\n";
    }
    $outputString .= "</head>\n<body>\n";
    if ($wikiTree->title) {
        $outputString .= '<h1 class="title">';
        $outputString .= $wikiTree->title;
        $outputString .= "</h1>\n";
    }
    if ($wikiTree->subtitle) {
        $outputString .= '<h2 class="subtitle">';
        $outputString .= $wikiTree->subtitle;
        $outputString .= "</h2>\n";
    }
    if ($wikiTree->authors) {
        $outputString .= '<p class="authors">';
        foreach my $author (@{$wikiTree->authors}) {
            $outputString .= $author->[0];
            $outputString .= ' &lt;' . $author->[1] . '&gt;'
                if (scalar @{$author} > 1);
            $outputString .= "<br />\n";
        }
        $outputString .= "</p>\n";
    }
    if ($wikiTree->id || $wikiTree->version || $wikiTree->date) {
        $outputString .= '<p class="docinfo">';
        if ($wikiTree->id) {
            $outputString .= $wikiTree->id;
            if ($wikiTree->version) {
                $outputString .= "<br />\n";
            }
        }
        if ($wikiTree->version) {
            $outputString .= $wikiTree->version;
            if ($wikiTree->date) {
                $outputString .= "<br />\n";
            }
        }
        $outputString .= $wikiTree->date if ($wikiTree->date);
        $outputString .= "</p>\n";
    }
    return $outputString;
}

sub _htmlFooter {
    return "</body>\n</html>\n";
}

1;
__END__

=head1 NAME

PurpleWiki::View::xhtml - XHTML view driver

=head1 SYNOPSIS

  use PurpleWiki::View::xhtml;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
