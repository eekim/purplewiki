# PurpleWiki::View::text.pm
#
# $Id: text.pm,v 1.2 2003/01/09 06:33:19 eekim Exp $
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

package PurpleWiki::View::text;

use 5.005;
use strict;
use Text::Wrap;
use PurpleWiki::Tree;

# global variables
my @links;
my $linksIndex = 1;

my $showLinks = 1;

# functions

sub view {
    my ($wikiTree, %params) = @_;
    my $columns = $params{columns} ? $params{columns} : 72;
    my $text;

    if (defined $params{show_links} && $params{show_links} == 0) {
    $showLinks = 0;
    }
    $Text::Wrap::columns = $columns;
    $Text::Wrap::huge = 'overflow';
    $text = &_center($wikiTree->title, $columns) if ($wikiTree->title);
    $text .= &_center($wikiTree->subtitle, $columns) if ($wikiTree->subtitle);
    $text .= &_center($wikiTree->id, $columns) if ($wikiTree->id);
    $text .= &_center($wikiTree->date, $columns) if ($wikiTree->date);
    $text .= &_center($wikiTree->version, $columns) if ($wikiTree->version);

    $text .= "\n";
    $text .= &_traverseStructural($wikiTree->root->children, undef, undef,
                  1, 0);
    # check for links
    if ($showLinks) {
    if (scalar @links > 0) {
        $text .= "\n\n";
        $text .= "LINK REFERENCES\n\n";
        $linksIndex = 1;
        foreach my $link (@links) {
        $text .= "    [$linksIndex] $link\n";
        $linksIndex++;
        }
    }
    }
    return $text;
}

sub _traverseStructural {
    my ($nodeListRef, $prevNodeType, $listType, $listNumber, $level) = @_;
    my $outputString;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
        # add blank line
        if ( ( ($node->type eq 'h') || ($node->type eq 'p') ||
           ($node->type eq 'pre') ) ||
         ( ( ($prevNodeType eq 'ul') || ($prevNodeType eq 'ol') ||
             ($prevNodeType eq 'dl') ) &&
           ( ($node->type eq 'li') || ($node->type eq 'dt') ) ) ||
         ( ( ($node->type eq 'dt') || ($node->type eq 'dd') ) &&
           ($prevNodeType eq 'dd') ) ) {
        $outputString .= "\n";
        }
        # set indentation appropriately
            my $initialOffset = 1;
            my $subsequentOffset = 1;
        my $subsequentMore = 0;
            if ($node->type eq 'li') {
        $initialOffset = 2;
        $subsequentOffset = 2;
                if ($listType eq 'ul') {
            $subsequentMore = 2;
                }
                elsif ($listType eq 'ol') {
            $subsequentMore = 3;
                }
            }
        elsif ($node->type eq 'dt') {
                $initialOffset = 2;
                $subsequentOffset = 2;
        }
        my $initialIndent = ' ' x ( ($level - $initialOffset) * 4);
        my $subsequentIndent = ' ' x ( ($level - $subsequentOffset) * 4
        + $subsequentMore);
        # parse content
            if ($node->content) {
                my $nodeString;
                foreach my $inlineNode (@{$node->content}) {
                    if ($inlineNode->children) {
            $nodeString .= &_inlineFormat($inlineNode->type);
                        $nodeString .= &_traverseInline($inlineNode->children,
                            $level);
            $nodeString .= &_inlineFormat($inlineNode->type);
                    }
                    else {
                        $nodeString .= $inlineNode->content;
            # check for links
            if ($showLinks) {
                if ($inlineNode->type eq 'link') {
                $nodeString .= '[' . $linksIndex . ']';
                push @links, $inlineNode->href;
                $linksIndex++;
                }
            }
                    }
            if ($node->type eq 'li') {
            if ($listType eq 'ul') {
                $nodeString = '* ' . $nodeString;
            }
            elsif ($listType eq 'ol') {
                $nodeString = $listNumber . '. ' . $nodeString;
                $listNumber++;
            }
            }
            elsif ($node->type eq 'h') {
            $nodeString = uc($nodeString);
            }
        }
        if ($node->type eq 'pre') {
            $outputString .= &Text::Wrap::wrap($initialIndent,
                               $subsequentIndent,
                               $nodeString);
        }
        else {
            $outputString .= &Text::Wrap::fill($initialIndent,
                               $subsequentIndent,
                               $nodeString);
        }
            }
            if ($node->children) {
        if ($node->type eq 'ul') {
            $outputString .= &_traverseStructural($node->children,
                              $node->type,
                              'ul',
                              $listNumber,
                              $level + 1);
        }
        elsif ($node->type eq 'ol') {
            $outputString .= &_traverseStructural($node->children,
                              $node->type,
                              'ol',
                              1,
                              $level + 1);
        }
        else {
            $outputString .= &_traverseStructural($node->children,
                              $node->type,
                              $listType,
                              $listNumber,
                              $level + 1);
        }
            }
        # terminate content with newline
        if ( ($node->type ne 'section') && ($node->type ne 'ul') &&
         ($node->type ne 'ol') && ($node->type ne 'dl') &&
         ($node->type ne 'indent') ) {
        $outputString .= "\n";
        }
        $prevNodeType = $node->type;
        }
    }
    return $outputString;
}

sub _traverseInline {
    my ($nodeListRef, $level) = @_;
    my $outputString;

    foreach my $node (@{$nodeListRef}) {
        if (defined $node->content) {
            $outputString .= $node->content;
        }
        else {
        $outputString .= &_inlineFormat($node->type);
            $outputString .= &_traverseInline($node->children, $level);
        $outputString .= &_inlineFormat($node->type);
        }
    }
    return $outputString;
}

sub _inlineFormat {
    my $nodeType = shift;

    if ($nodeType eq 'i') {
    return '_';
    }
    elsif ($nodeType eq 'b') {
    return '*';
    }
    return '';
}

sub _center {
    my ($text, $columns) = @_;
    my $padding;

    if (length $text > $columns) {
        return $text . "\n";
    }
    else {
        $padding = ($columns - length $text) / 2;
        return ' ' x $padding . $text . "\n";
    }
}

1;
__END__

=head1 NAME

PurpleWiki::View::text - Plain text view driver

=head1 SYNOPSIS

  use PurpleWiki::View::text;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
