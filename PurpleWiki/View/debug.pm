# PurpleWiki::View::debug.pm
#
# $Id: debug.pm,v 1.3 2003/08/14 07:01:51 eekim Exp $
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

package PurpleWiki::View::debug;

use 5.005;
use strict;
use PurpleWiki::Tree;
use PurpleWiki::View::EventHandler;

# structural node event handlers

sub structuralStructurePre {
    my ($node, %params) = @_;

    return &_indent($params{indentLevel}, $node->type) . "\n";
}

sub structuralContentPre {
    my ($node, %params) = @_;

    return &_indent($params{indentLevel}, $node->type);
}

# inline node event handlers

sub inlinePre {
    my ($node, %params) = @_;

    return uc($node->type) . ':';
}

sub inlineContentMain {
    my ($node, %params) = @_;

    return $node->content . "\n";
}

# functions

sub registerHandlers {
    $PurpleWiki::View::EventHandler::structuralHandler{section}->{pre} = \&structuralStructurePre;
    $PurpleWiki::View::EventHandler::structuralHandler{indent}->{pre} = \&structuralStructurePre;
    $PurpleWiki::View::EventHandler::structuralHandler{ul}->{pre} = \&structuralStructurePre;
    $PurpleWiki::View::EventHandler::structuralHandler{ol}->{pre} = \&structuralStructurePre;
    $PurpleWiki::View::EventHandler::structuralHandler{dl}->{pre} = \&structuralStructurePre;

    $PurpleWiki::View::EventHandler::structuralHandler{h}->{pre} = \&structuralContentPre;
    $PurpleWiki::View::EventHandler::structuralHandler{p}->{pre} = \&structuralContentPre;
    $PurpleWiki::View::EventHandler::structuralHandler{li}->{pre} = \&structuralContentPre;
    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{pre} = \&structuralContentPre;
    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{pre} = \&structuralContentPre;
    $PurpleWiki::View::EventHandler::structuralHandler{pre}->{pre} = \&structuralContentPre;

    $PurpleWiki::View::EventHandler::inlineHandler{b}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{i}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{tt}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{nowiki}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{link}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{url}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{wikiword}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{freelink}->{pre} = \&inlinePre;
    $PurpleWiki::View::EventHandler::inlineHandler{image}->{pre} = \&inlinePre;

    $PurpleWiki::View::EventHandler::inlineHandler{text}->{main} = \&inlineContentMain;
    $PurpleWiki::View::EventHandler::inlineHandler{nowiki}->{main} = \&inlineContentMain;
    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{main} = \&inlineContentMain;
    $PurpleWiki::View::EventHandler::inlineHandler{link}->{main} = \&inlineContentMain;
    $PurpleWiki::View::EventHandler::inlineHandler{url}->{main} = \&inlineContentMain;
    $PurpleWiki::View::EventHandler::inlineHandler{wikiword}->{main} = \&inlineContentMain;
    $PurpleWiki::View::EventHandler::inlineHandler{freelink}->{main} = \&inlineContentMain;
    $PurpleWiki::View::EventHandler::inlineHandler{image}->{main} = \&inlineContentMain;
}

sub view {
    my ($wikiTree, %params) = @_;

    &registerHandlers;
    return &_header($wikiTree, %params) .
        &PurpleWiki::View::EventHandler::view($wikiTree, %params);
}

sub _header {
    my ($wikiTree, %params) = @_;

    return 'title:' . $wikiTree->title . "\n";
}

# private

sub _indent {
    my ($indentLevel, $nodeType) = @_;

    return ' ' x ($indentLevel * 2) . $nodeType . ':';
}

1;
__END__

=head1 NAME

PurpleWiki::View::debug - Debug View driver

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::View::EventHandler>.

=cut
