# PurpleWiki::View::wikitext.pm
#
# $Id: wikitext.pm,v 1.2.6.3 2003/05/21 08:47:27 cdent Exp $
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

package PurpleWiki::View::wikitext;

use 5.005;
use strict;
use PurpleWiki::Tree;
use PurpleWiki::View::EventHandler;

# globals

my $sectionDepth = 0;
my $indentDepth = 0;
my @listStack;
my $lastInlineProcessed;
my @sectionState;

# structural node event handlers

sub startList {
    my $structuralNode = shift;

    push @listStack, $structuralNode->type;
    return '';
}

sub endList {
    pop @listStack;
    undef $lastInlineProcessed;
    return "\n" if (scalar @listStack == 0);
}

sub showNid {
    my $structuralNode = shift;
    undef $lastInlineProcessed;
    my $outputString = &_nid($structuralNode->id);
    if ($structuralNode->type eq 'dt') {
        return $outputString;
    }
    elsif ($structuralNode->type eq 'pre') {
        return $outputString . "\n\n";
    }
    else {
        return $outputString . "\n";
    }
}

# inline node event handlers

sub inlineContent {
    my $inlineNode = shift;

    return $inlineNode->content;
}

# functions

sub registerHandlers {
    $PurpleWiki::View::EventHandler::structuralHandler{section}->{pre} =
        sub { $sectionDepth++; return ''; };
    $PurpleWiki::View::EventHandler::structuralHandler{section}->{post} =
        sub { $sectionDepth--; undef $lastInlineProcessed; return ''; };

    $PurpleWiki::View::EventHandler::structuralHandler{indent}->{pre} =
        sub { $indentDepth++; return ''; };
    $PurpleWiki::View::EventHandler::structuralHandler{indent}->{post} =
        sub { $indentDepth--;
              undef $lastInlineProcessed;
              return "\n" if ($indentDepth == 0); };

    $PurpleWiki::View::EventHandler::structuralHandler{ul}->{pre} = \&startList;
    $PurpleWiki::View::EventHandler::structuralHandler{ul}->{post} = \&endList;

    $PurpleWiki::View::EventHandler::structuralHandler{ol}->{pre} = \&startList;
    $PurpleWiki::View::EventHandler::structuralHandler{ol}->{post} = \&endList;

    $PurpleWiki::View::EventHandler::structuralHandler{dl}->{pre} = \&startList;
    $PurpleWiki::View::EventHandler::structuralHandler{dl}->{post} = \&endList;

    $PurpleWiki::View::EventHandler::structuralHandler{h}->{pre} =
        sub { return '=' x $sectionDepth . ' '; };
    $PurpleWiki::View::EventHandler::structuralHandler{h}->{post} =
        sub { my $structuralNode = shift;
              undef $lastInlineProcessed;
              return &_nid($structuralNode->id) . ' ' . '=' x $sectionDepth . "\n\n"; };

    $PurpleWiki::View::EventHandler::structuralHandler{p}->{pre} =
        sub { return ':' x $indentDepth; };
    $PurpleWiki::View::EventHandler::structuralHandler{p}->{post} =
        sub { my $structuralNode = shift;
              my $outputString = &_nid($structuralNode->id) . "\n";
              $outputString .= "\n" if ($indentDepth == 0);
              undef $lastInlineProcessed;
              return $outputString; };

    $PurpleWiki::View::EventHandler::structuralHandler{li}->{pre} =
        sub { if ($listStack[$#listStack] eq 'ul') {
                  return '*' x scalar(@listStack) . ' ';
              }
              else {
                  return '#' x scalar(@listStack) . ' ';
              } };
    $PurpleWiki::View::EventHandler::structuralHandler{li}->{post} = \&showNid;

    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{pre} =
        sub { return ';' x scalar(@listStack); };
    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{post} = \&showNid;

    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{pre} =
        sub { return ':'; };
    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{post} = \&showNid;

    $PurpleWiki::View::EventHandler::structuralHandler{pre}->{post} = \&showNid;

    $PurpleWiki::View::EventHandler::inlineHandler{b}->{pre} =
        sub { return "'''"; };
    $PurpleWiki::View::EventHandler::inlineHandler{b}->{post} =
        sub { $lastInlineProcessed = 'b'; return "'''"; };

    $PurpleWiki::View::EventHandler::inlineHandler{i}->{pre} =
        sub { return "''"; };
    $PurpleWiki::View::EventHandler::inlineHandler{i}->{post} =
        sub { $lastInlineProcessed = 'i'; return "''"; };

    $PurpleWiki::View::EventHandler::inlineHandler{tt}->{pre} =
        sub { return "<tt>"; };
    $PurpleWiki::View::EventHandler::inlineHandler{tt}->{post} =
        sub { $lastInlineProcessed = 'tt'; return "</tt>"; };

    $PurpleWiki::View::EventHandler::inlineHandler{text}->{pre} =
        sub { my $structuralNode = shift;
              if ($lastInlineProcessed eq 'wikiword' &&
                  $structuralNode->content =~ /^\w/) {
                  return '""';
              }
              else {
                  return '';
              } };
    $PurpleWiki::View::EventHandler::inlineHandler{text}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{text}->{post} =
        sub { $lastInlineProcessed = 'text'; return ''; };

    $PurpleWiki::View::EventHandler::inlineHandler{nowiki}->{pre} =
        sub { return '<nowiki>'; };
    $PurpleWiki::View::EventHandler::inlineHandler{nowiki}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{nowiki}->{post} =
        sub { $lastInlineProcessed = 'nowiki'; return '</nowiki>'; };

    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{pre} =
        sub { my $inlineNode = shift; return '[t'; };
    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{post} =
        sub { $lastInlineProcessed = 'transclusion'; return ']'; };

    $PurpleWiki::View::EventHandler::inlineHandler{link}->{pre} =
        sub { my $inlineNode = shift; return '[' . $inlineNode->href . ' '; };
    $PurpleWiki::View::EventHandler::inlineHandler{link}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{link}->{post} =
        sub { $lastInlineProcessed = 'link'; return ']'; };

    $PurpleWiki::View::EventHandler::inlineHandler{url}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{url}->{post} =
        sub { $lastInlineProcessed = 'url'; return ''; };

    $PurpleWiki::View::EventHandler::inlineHandler{wikiword}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{wikiword}->{post} =
        sub { $lastInlineProcessed = 'wikiword'; return ''; };

    $PurpleWiki::View::EventHandler::inlineHandler{freelink}->{pre} =
        sub { return '[['; };
    $PurpleWiki::View::EventHandler::inlineHandler{freelink}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{freelink}->{post} =
        sub { $lastInlineProcessed = 'freelink'; return ']]'; };

    $PurpleWiki::View::EventHandler::inlineHandler{image}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{image}->{post} =
        sub { $lastInlineProcessed = 'image'; return ''; };
}

sub view {
    my ($wikiTree, %params) = @_;

    &registerHandlers;
    return &PurpleWiki::View::EventHandler::view($wikiTree, %params);
}

# private

sub _nid {
    my $nid = shift;

    return " [nid $nid]";
}

1;
__END__

=head1 NAME

PurpleWiki::View::wikitext - WikiText view driver

=head1 SYNOPSIS

  use PurpleWiki::View::wikitext;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
