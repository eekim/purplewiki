# PurpleWiki::View::debug.pm
#
# $Id: debug.pm,v 1.1 2003/01/18 05:23:45 eekim Exp $
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

# functions

sub view {
    my ($wikiTree, %params) = @_;

    return 'title:' . $wikiTree->title . "\n" .
        &_traverseStructural($wikiTree->root->children, 0);
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;
    my $outputString;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            $outputString .= ' ' x ($indentLevel * 2) . $node->type . ':';
            if ( ($node->type eq 'section') || ($node->type eq 'indent') ||
                 ($node->type eq 'ul') || ($node->type eq 'ol') ||
                 ($node->type eq 'dl') ) {
                $outputString .= "\n";
            }
            if ($node->content) {
                foreach my $inlineNode (@{$node->content}) {
                    $outputString .= uc($inlineNode->type) . ':'
                        if ($inlineNode->type ne 'text');
                    if ($inlineNode->children) {
                        $outputString .= &_traverseInline($inlineNode->children,
                                                          $indentLevel);
                    }
                    else {
                        $outputString .= $inlineNode->content . "\n";
                    }
                }
            }
            if ($node->children) {
                $outputString .= &_traverseStructural($node->children,
                                                      $indentLevel + 1);
            }
        }
    }
    return $outputString;
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;
    my $outputString;

    foreach my $node (@{$nodeListRef}) {
        if (defined $node->content) {
            $outputString .= $node->content . "\n";
        }
        else {
            $outputString .= uc($node->type) . ':';
            $outputString .= &_traverseInline($node->children, $indentLevel);
        }
    }
    return $outputString;
}

1;
__END__

=head1 NAME

PurpleWiki::View::debug - Debug view driver

=head1 SYNOPSIS

  use PurpleWiki::View::debug;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
