# PurpleWiki::View::EventHandler.pm
#
# $Id: EventHandler.pm,v 1.6 2003/08/28 17:41:47 eekim Exp $
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

package PurpleWiki::View::EventHandler;

use 5.005;
use strict;
use vars qw(%structuralHandler %inlineHandler $VERSION);
$VERSION = '0.9';

use PurpleWiki::Tree;

### Register the default handlers

&registerHandlers;

### functions

# structural node event handlers

sub emptyString {
    return '';
}

sub recurseStructural {
    my ($structuralNode, %params) = @_;

    $params{indentLevel}++;
    return &traverseStructural($structuralNode->children, %params);
}

sub structuralContent {
    my ($structuralNode, %params) = @_;

    if ($structuralNode->content) {
        return &traverseInline($structuralNode->content, %params);
    }
}

# inline node event handlers

sub recurseInline {
    my ($inlineNode, %params) = @_;

    return &traverseInline($inlineNode->children, %params);
}

# functions

sub registerHandlers {
    $structuralHandler{section}->{pre} = \&emptyString;
    $structuralHandler{section}->{main} = \&recurseStructural;
    $structuralHandler{section}->{post} = \&emptyString;

    $structuralHandler{indent}->{pre} = \&emptyString;
    $structuralHandler{indent}->{main} = \&recurseStructural;
    $structuralHandler{indent}->{post} = \&emptyString;

    $structuralHandler{ul}->{pre} = \&emptyString;
    $structuralHandler{ul}->{main} = \&recurseStructural;
    $structuralHandler{ul}->{post} = \&emptyString;

    $structuralHandler{ol}->{pre} = \&emptyString;
    $structuralHandler{ol}->{main} = \&recurseStructural;
    $structuralHandler{ol}->{post} = \&emptyString;

    $structuralHandler{dl}->{pre} = \&emptyString;
    $structuralHandler{dl}->{main} = \&recurseStructural;
    $structuralHandler{dl}->{post} = \&emptyString;

    $structuralHandler{h}->{pre} = \&emptyString;
    $structuralHandler{h}->{main} = \&structuralContent;
    $structuralHandler{h}->{post} = \&emptyString;

    $structuralHandler{p}->{pre} = \&emptyString;
    $structuralHandler{p}->{main} = \&structuralContent;
    $structuralHandler{p}->{post} = \&emptyString;

    $structuralHandler{li}->{pre} = \&emptyString;
    $structuralHandler{li}->{main} = \&structuralContent;
    $structuralHandler{li}->{post} = \&emptyString;

    $structuralHandler{dd}->{pre} = \&emptyString;
    $structuralHandler{dd}->{main} = \&structuralContent;
    $structuralHandler{dd}->{post} = \&emptyString;

    $structuralHandler{dt}->{pre} = \&emptyString;
    $structuralHandler{dt}->{main} = \&structuralContent;
    $structuralHandler{dt}->{post} = \&emptyString;

    $structuralHandler{pre}->{pre} = \&emptyString;
    $structuralHandler{pre}->{main} = \&structuralContent;
    $structuralHandler{pre}->{post} = \&emptyString;

    $structuralHandler{sketch}->{pre} = \&emptyString;
    $structuralHandler{sketch}->{main} = \&emptyString;
    $structuralHandler{sketch}->{post} = \&emptyString;

    $inlineHandler{b}->{pre} = \&emptyString;
    $inlineHandler{b}->{main} = \&recurseInline;
    $inlineHandler{b}->{post} = \&emptyString;

    $inlineHandler{i}->{pre} = \&emptyString;
    $inlineHandler{i}->{main} = \&recurseInline;
    $inlineHandler{i}->{post} = \&emptyString;

    $inlineHandler{tt}->{pre} = \&emptyString;
    $inlineHandler{tt}->{main} = \&recurseInline;
    $inlineHandler{tt}->{post} = \&emptyString;

    $inlineHandler{text}->{pre} = \&emptyString;
    $inlineHandler{text}->{main} = \&emptyString;
    $inlineHandler{text}->{post} = \&emptyString;

    $inlineHandler{nowiki}->{pre} = \&emptyString;
    $inlineHandler{nowiki}->{main} = \&emptyString;
    $inlineHandler{nowiki}->{post} = \&emptyString;

    $inlineHandler{transclusion}->{pre} = \&emptyString;
    $inlineHandler{transclusion}->{main} = \&emptyString;
    $inlineHandler{transclusion}->{post} = \&emptyString;

    $inlineHandler{link}->{pre} = \&emptyString;
    $inlineHandler{link}->{main} = \&emptyString;
    $inlineHandler{link}->{post} = \&emptyString;

    $inlineHandler{url}->{pre} = \&emptyString;
    $inlineHandler{url}->{main} = \&emptyString;
    $inlineHandler{url}->{post} = \&emptyString;

    $inlineHandler{wikiword}->{pre} = \&emptyString;
    $inlineHandler{wikiword}->{main} = \&emptyString;
    $inlineHandler{wikiword}->{post} = \&emptyString;

    $inlineHandler{freelink}->{pre} = \&emptyString;
    $inlineHandler{freelink}->{main} = \&emptyString;
    $inlineHandler{freelink}->{post} = \&emptyString;

    $inlineHandler{image}->{pre} = \&emptyString;
    $inlineHandler{image}->{main} = \&emptyString;
    $inlineHandler{image}->{post} = \&emptyString;
}

sub view {
    my ($wikiTree, %params) = @_;

    $params{indentLevel} = 0;
    my $outputString = &traverseStructural($wikiTree->root->children, %params);
    &registerHandlers;  # reset handlers
    return $outputString;
}

sub traverseStructural {
    my ($nodeListRef, %params) = @_;
    my $outputString;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            if (defined($structuralHandler{$node->type})) {
		    # FIXME: these || '' shouldn't be here
		    # but should be in the handlers
                $outputString .=
                    $structuralHandler{$node->type}{pre}($node, %params)
		    	|| '';
                $outputString .=
                    $structuralHandler{$node->type}{main}($node, %params)
		    	|| '';
                $outputString .=
                    $structuralHandler{$node->type}{post}($node, %params)
		    	|| '';
            }
        }
    }
    return $outputString;
}

sub traverseInline {
    my ($nodeListRef, %params) = @_;
    my $outputString;

    foreach my $node (@{$nodeListRef}) {
        if (defined($inlineHandler{$node->type})) {
            $outputString .=
                $inlineHandler{$node->type}{pre}($node, %params);
            $outputString .=
                $inlineHandler{$node->type}{main}($node, %params);
            $outputString .=
                $inlineHandler{$node->type}{post}($node, %params);
        }
    }
    return $outputString;
}

1;
__END__

=head1 NAME

PurpleWiki::View::EventHandler - Event handlers for View drivers

=head1 DESCRIPTION

This is a generic module for serializing a PurpleWiki::Tree.  It
assigns a pre, main, and post event for all node types, both
structural and inline.  These events are meant to be overridden by the
actual view drivers.  See these drivers for an example of how to use
EventHandler.

Eventually, we plan on converting this module into a base class from
which all view drivers inherit.  There would be a method for each
event, and view drivers would simply override these methods.

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
