# PurpleWiki::View::Debug.pm
#
# $Id: Debug.pm,v 1.3 2002/11/22 21:17:36 eekim Exp $
#
# Copyright (c) Blue Oxen Associates 2002.  All rights reserved.
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

package PurpleWiki::View::Debug;

use 5.006;
use strict;
use warnings;
use PurpleWiki::Tree;

# functions

sub view {
    my ($wikiTree, %params) = @_;

    print 'title:' . $wikiTree->title . "\n";
    &_traverseStructural($wikiTree->root->children, 0);
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            print &_spaces($indentLevel, 0) . $node->type . ':';
            if ( ($node->type eq 'section') || ($node->type eq 'indent') ||
                 ($node->type eq 'ul') || ($node->type eq 'ol') ||
                 ($node->type eq 'dl') ) {
                print "\n";
            }
            if ($node->content) {
                foreach my $inlineNode (@{$node->content}) {
                    print uc($inlineNode->type) . ':' if ($inlineNode->type ne 'text');
                    if ($inlineNode->children) {
                        &_traverseInline($inlineNode->children, $indentLevel);
                    }
                    else {
                        print $inlineNode->content . "\n";
                    }
                }
            }
            &_traverseStructural($node->children, $indentLevel + 1);
        }
    }
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;

    foreach my $node (@{$nodeListRef}) {
        if (defined $node->content) {
            print $node->content . "\n";
        }
        else {
            print uc($node->type) . ':';
            &_traverseInline($node->children, $indentLevel);
        }
    }
}

sub _spaces {
    my $indentLevel = shift;

    for (my $i = 0; $i < $indentLevel * 2; $i++) {
        print ' ';
    }
}

1;
__END__

=head1 NAME

PurpleWiki::View::Debug - Debug view driver

=head1 SYNOPSIS

  use PurpleWiki::View::Debug;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
