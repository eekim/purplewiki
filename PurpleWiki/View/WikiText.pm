# PurpleWiki::View::WikiText.pm
#
# $Id: WikiText.pm,v 1.7 2002/11/24 09:19:24 eekim Exp $
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

package PurpleWiki::View::WikiText;

use 5.006;
use strict;
use PurpleWiki::Tree;

# globals

my $sectionDepth = 0;
my $indentDepth = 0;
my @listStack;
my $lastInlineProcessed;
my @sectionState;

my %structuralActionMap = (
    'section' => {
        'pre' => sub { $sectionDepth++; return; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { $sectionDepth--;
                        undef $lastInlineProcessed; return; },
    },
    'indent' => {
        'pre' => sub { $indentDepth++; return; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { $indentDepth--;
                        undef $lastInlineProcessed;
                        return "\n" if ($indentDepth == 0); },
    },
    'ul' => {
        'pre' => sub { push @listStack, 'ul'; return; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { pop @listStack;
                        undef $lastInlineProcessed;
                        return "\n" if (scalar @listStack == 0); },
    },
    'ol' => {
        'pre' => sub { push @listStack, 'ol'; return; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { pop @listStack;
                        undef $lastInlineProcessed;
                        return "\n" if (scalar @listStack == 0); },
    },
    'dl' => {
        'pre' => sub { push @listStack, 'dl'; return; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { pop @listStack;
                        undef $lastInlineProcessed;
                        return "\n" if (scalar @listStack == 0); },
    },
    'h' => {
        'pre' => sub { return '=' x $sectionDepth . ' '; },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        undef $lastInlineProcessed;
                        return &_printNid($nid) . ' ' .
                            '=' x $sectionDepth . "\n\n"; },
        },
    'p' => {
        'pre' => sub { return ':' x $indentDepth; },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        my $outputString = &_printNid($nid) . "\n";
                        $outputString .= "\n" if ($indentDepth == 0);
                        undef $lastInlineProcessed;
                        return $outputString; },
    },
    'li' => {
        'pre' => sub { if ($listStack[$#listStack] eq 'ul') {
                           return '*' x scalar(@listStack) . ' ';
                       }
                       else {
                           return '#' x scalar(@listStack) . ' ';
                       } },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        undef $lastInlineProcessed;
                        return &_printNid($nid) . "\n"; },
    },
    'dt' => {
        'pre' => sub { return ';' x scalar(@listStack); },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        undef $lastInlineProcessed;
                        return &_printNid($nid); },
    },
    'dd' => {
        'pre' => sub { return ':'; },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        undef $lastInlineProcessed;
                        return &_printNid($nid) . "\n"; },
    },
    'pre' => {
        'pre' => sub { return },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        undef $lastInlineProcessed;
                        return &_printNid($nid) . "\n\n"; },
    },
    );

my %inlineActionMap = (
    'b' => {
        'pre' => sub { return "'''"; },
        'mid' => \&_traverseInlineWithData,
        'post' => sub { $lastInlineProcessed = 'b';
                        return "'''"; },
    },
    'i' => {
        'pre' => sub { return "''"; },
        'mid' => \&_traverseInlineWithData,
        'post' => sub { $lastInlineProcessed = 'i';
                        return "''"; },
    },
    'tt' => {
        'pre' => sub { return '<tt>'; },
        'mid' => \&_traverseInlineWithData,
        'post' => sub { $lastInlineProcessed = 'tt';
                        return '</tt>'; },
    },
    'text' => {
        'pre' => sub { my $node = shift;
                       if ($lastInlineProcessed eq 'wikiword' &&
                           $node->content =~ /^\w/) {
                           return '""';
                       }
                       else {
                           return;
                       } },
        'mid' => \&_printInlineData,
        'post' => sub { $lastInlineProcessed = 'text'; return; }
    },
    'nowiki' => {
        'pre' => sub { return '<nowiki>'; },
        'mid' => \&_printInlineData,
        'post' => sub { $lastInlineProcessed = 'nowiki';
                        return '</nowiki>'; }
    }
    );

sub view {
    my ($wikiTree, %params) = @_;

    my $outputString = &_printHeader($wikiTree->lastNid);
    $outputString .= &_traverseStructural($wikiTree->root->children, 0);
    return $outputString;
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;
    my $outputString;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            if (defined($structuralActionMap{$node->type})) {
                $outputString .= &{$structuralActionMap{$node->type}{'pre'}};
                $outputString .= &{$structuralActionMap{$node->type}{'mid'}}($node,
                                                            $indentLevel);
                $outputString .= &{$structuralActionMap{$node->type}{'post'}}($node->id);
            } 
        }
    }
    return $outputString;
}

sub _traverseInlineIfContent {
    my $structuralNode = shift;
    my $indentLevel = shift;
    if ($structuralNode->content) {
        return _traverseInline($structuralNode->content, $indentLevel);
    }
}

sub _traverseInlineWithData {
    my $inlineNode = shift;
    my $indentLevel = shift;
    return _traverseInline($inlineNode->children, $indentLevel);
}

sub _printInlineData {
    my $inlineNode = shift;
    return $inlineNode->content;
}

sub _traverseStructuralWithChild {
    my $structuralNode = shift;
    my $indentLevel = shift;
    return _traverseStructural($structuralNode->children, $indentLevel + 1);
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;
    my $outputString;

    foreach my $inlineNode (@{$nodeListRef}) {
        if ($inlineNode->type eq 'link') {
            $outputString .= '[' . $inlineNode->href . ' ' . $inlineNode->content . ']';
            $lastInlineProcessed = 'link';
        }
        elsif ($inlineNode->type eq 'wikiword') {
            $outputString .= $inlineNode->content;
            $lastInlineProcessed = 'wikiword';
        }
        elsif ($inlineNode->type eq 'url' || $inlineNode->type eq 'image') {
            $outputString .= $inlineNode->content;
            $lastInlineProcessed = 'url';
        }
        elsif ($inlineNode->type eq 'freelink') {
            $outputString .= '[[' . $inlineNode->content . ']]';
            $lastInlineProcessed = 'freelink';
        }
        elsif (defined($inlineActionMap{$inlineNode->type})) {
            $outputString .=
                &{$inlineActionMap{$inlineNode->type}{'pre'}}($inlineNode);
            $outputString .=
                &{$inlineActionMap{$inlineNode->type}{'mid'}}($inlineNode,
                                                          $indentLevel);
            $outputString .=
                &{$inlineActionMap{$inlineNode->type}{'post'}};
        }
    }
    return $outputString;
}

sub _headerLevel {
    my $headerLevel = scalar @sectionState + 1;
    $headerLevel = 6 if ($headerLevel > 6);
    return $headerLevel;
}

sub _printNid {
    my $nid = shift;
    return " [nid $nid]";
}

sub _printHeader {
    my $lastNid = shift;

    return "[lastnid $lastNid]\n" if ($lastNid);
}

1;
__END__

=head1 NAME

PurpleWiki::View::WikiText - WikiText view driver

=head1 SYNOPSIS

  use PurpleWiki::View::WikiText;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
