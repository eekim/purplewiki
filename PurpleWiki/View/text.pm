# PurpleWiki::View::text.pm
#
# $Id: text.pm,v 1.6 2003/08/18 07:10:54 eekim Exp $
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

package PurpleWiki::View::text;

use 5.005;
use strict;
use Text::Wrap;
use PurpleWiki::Tree;
use PurpleWiki::View::EventHandler;

use vars qw($VERSION);
$VERSION = '0.9';

# globals

my $initialIndent;
my $subsequentIndent;

my $listNumber = 1;
my $prevDefType;

my @links;
my $linksIndex = 1;

my $showLinks = 1;

# structural node event handlers

sub setIndent {
    my ($structuralNode, %params) = @_;

    my $initialOffset = 1;
    my $subsequentOffset = 1;
    my $subsequentMore = 0;
    my $listMore = 0;
    if ($structuralNode->type eq 'li') {
        $initialOffset = 2;
        $subsequentOffset = 2;
        $listMore = 2;
        if ($params{listType} eq 'ul') {
            $subsequentMore = 2;
        }
        elsif ($params{listType} eq 'ol') {
            $subsequentMore = 3;
        }
    }
    elsif ($structuralNode->type eq 'dt') {
        $initialOffset = 2;
        $subsequentOffset = 2;
    }
    $initialIndent = ' ' x ( ($params{indentLevel} - $initialOffset) * 4
                             + $listMore);
    $subsequentIndent = ' ' x ( ($params{indentLevel} - $subsequentOffset) * 4
                                + $subsequentMore + $listMore);
    return '';
}

sub recurseList {
    my ($structuralNode, %params) = @_;

    $params{indentLevel}++;
    $params{listType} = $structuralNode->type;
    if ($structuralNode->type eq 'ol') {
        $listNumber = 1;
    }
    return &PurpleWiki::View::EventHandler::traverseStructural($structuralNode->children, %params);
}

sub structuralContent {
    my ($structuralNode, %params) = @_;

    if ($structuralNode->content) {
        my $nodeString = &PurpleWiki::View::EventHandler::traverseInline($structuralNode->content, %params);
        if ($structuralNode->type eq 'li') {
            if ($params{listType} eq 'ul') {
                $nodeString = "* $nodeString";
            }
            elsif ($params{listType} eq 'ol') {
                $nodeString = "$listNumber. $nodeString";
                $listNumber++;
            }
        }
        if ($structuralNode->type eq 'pre') {
            return &Text::Wrap::wrap($initialIndent,
                                     $subsequentIndent,
                                     $nodeString);
        }
        else {
            return &Text::Wrap::fill($initialIndent,
                                     $subsequentIndent,
                                     $nodeString);
        }
    }
}

sub newLineSetIndent {
    &setIndent;
    return "\n";
}

sub newLine {
    my $structuralNode = shift;

    return "\n";
}

# inline node event handlers

sub inlineContent {
    my $inlineNode = shift;

    return $inlineNode->content;
}

# functions

sub registerHandlers {
    $PurpleWiki::View::EventHandler::structuralHandler{section}->{pre} = \&setIndent;

    $PurpleWiki::View::EventHandler::structuralHandler{indent}->{pre} = \&setIndent;

    $PurpleWiki::View::EventHandler::structuralHandler{ul}->{pre} = \&setIndent;
    $PurpleWiki::View::EventHandler::structuralHandler{ul}->{main} = \&recurseList;

    $PurpleWiki::View::EventHandler::structuralHandler{ol}->{pre} = \&setIndent;
    $PurpleWiki::View::EventHandler::structuralHandler{ol}->{main} = \&recurseList;

    $PurpleWiki::View::EventHandler::structuralHandler{dl}->{pre} = \&setIndent;

    $PurpleWiki::View::EventHandler::structuralHandler{h}->{pre} = \&newLineSetIndent;
    $PurpleWiki::View::EventHandler::structuralHandler{h}->{main} = \&structuralContent;
    $PurpleWiki::View::EventHandler::structuralHandler{h}->{post} = \&newLine;

    $PurpleWiki::View::EventHandler::structuralHandler{p}->{pre} = \&newLineSetIndent;
    $PurpleWiki::View::EventHandler::structuralHandler{p}->{main} = \&structuralContent;
    $PurpleWiki::View::EventHandler::structuralHandler{p}->{post} = \&newLine;

    $PurpleWiki::View::EventHandler::structuralHandler{li}->{pre} = \&newLineSetIndent;
    $PurpleWiki::View::EventHandler::structuralHandler{li}->{main} = \&structuralContent;
    $PurpleWiki::View::EventHandler::structuralHandler{li}->{post} = \&newLine;

    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{pre} = \&newLineSetIndent;
    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{main} = \&structuralContent;
    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{post} =
        sub { $prevDefType = 'dt'; return "\n"; };

    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{pre} =
        sub { my ($structuralNode, %params) = @_;
              &setIndent;
              if ($prevDefType eq 'dd') {
                  return "\n";
              }
              return ''; };
    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{main} = \&structuralContent;
    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{post} =
        sub { $prevDefType = 'dd'; return "\n"; };

    $PurpleWiki::View::EventHandler::structuralHandler{pre}->{pre} = \&newLineSetIndent;
    $PurpleWiki::View::EventHandler::structuralHandler{pre}->{main} = \&structuralContent;
    $PurpleWiki::View::EventHandler::structuralHandler{pre}->{post} = \&newLine;

    $PurpleWiki::View::EventHandler::inlineHandler{b}->{pre} =
        sub { return '*'; };
    $PurpleWiki::View::EventHandler::inlineHandler{b}->{post} =
        sub { return '*'; };

    $PurpleWiki::View::EventHandler::inlineHandler{i}->{pre} =
        sub { return '_'; };
    $PurpleWiki::View::EventHandler::inlineHandler{i}->{post} =
        sub { return '_'; };

    $PurpleWiki::View::EventHandler::inlineHandler{text}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{nowiki}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{pre} = 
    	sub { print "transclude: "; };
    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{link}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{link}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{link}->{post} =
        sub { my $inlineNode = shift;
              if ($showLinks) {
                  push @links, $inlineNode->href;
                  $linksIndex++;
                  return '[' . ($linksIndex - 1) . ']';
              } };

    $PurpleWiki::View::EventHandler::inlineHandler{url}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{wikiword}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{freelink}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{image}->{main} = \&inlineContent;
}

sub view {
    my ($wikiTree, %params) = @_;

    if ($params{columns} !~ /^\d+$/ || $params{columns} < 10) {
        $params{columns} = 72;
    }
    if (defined $params{show_links} && $params{show_links} == 0) {
        $showLinks = 0;
    }

    $Text::Wrap::columns = $params{columns};
    $Text::Wrap::huge = 'overflow';

    &registerHandlers;
    return &_header($wikiTree, %params) .
        &PurpleWiki::View::EventHandler::view($wikiTree, %params) .
        &_footer;
}

# private

sub _header {
    my ($wikiTree, %params) = @_;
    my $outputString;

    $outputString = &_center($wikiTree->title, $params{columns})
        if ($wikiTree->title);
    $outputString .= &_center($wikiTree->subtitle, $params{columns})
        if ($wikiTree->subtitle);
    $outputString .= &_center($wikiTree->id, $params{columns})
        if ($wikiTree->id);
    $outputString .= &_center($wikiTree->date, $params{columns})
        if ($wikiTree->date);
    $outputString .= &_center($wikiTree->version, $params{columns})
        if ($wikiTree->version);
    return $outputString . "\n";
}

sub _footer {
    my $outputString;

    if ($showLinks) {  # check for links
        if (scalar @links > 0) {
            $outputString = "\n\n";
            $outputString .= "LINK REFERENCES\n\n";
            $linksIndex = 1;
            foreach my $link (@links) {
                $outputString .= "    [$linksIndex] $link\n";
                $linksIndex++;
            }
        }
    }
    return $outputString;
}

sub _center {
    my ($outputString, $columns) = @_;
    my $padding;

    if (length $outputString > $columns) {
        return $outputString . "\n";
    }
    else {
        $padding = ($columns - length $outputString) / 2;
        return ' ' x $padding . $outputString . "\n";
    }
}

1;
__END__

=head1 NAME

PurpleWiki::View::text - Plain text view driver

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::View::EventHandler>.

=cut
