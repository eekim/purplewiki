# PurpleWiki::View::wikihtml.pm
# vi:ai:sm:ts=4:sw=4:et
#
# $Id: wikihtml.pm,v 1.2 2003/06/20 23:54:02 cdent Exp $
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

package PurpleWiki::View::wikihtml;

use 5.005;
use strict;
use PurpleWiki::Page;
use PurpleWiki::Tree;
use PurpleWiki::View::EventHandler;

# globals

use vars qw(@sectionState);

# structural node event handlers

sub openTag {
    my $node = shift;

    return '<' . $node->type . ">\n";
}

sub closeTag {
    my $node = shift;

    return '</' . $node->type . '>';
}

sub closeTagWithNewline {
    my $node = shift;

    return &closeTag($node) . "\n";
}

sub openTagWithNid {
    my $node = shift;

    return &openTag($node) . &_anchor($node->id);
}

sub closeTagWithNid {
    my $node = shift;
    my %params = @_;

    return &_nid($node->id, %params) . &closeTag($node);
}

# inline node event handlers

sub transcludeContent {
    my $node = shift;
    my %params = @_;
    require PurpleWiki::Transclusion;

    my $space = new PurpleWiki::Transclusion(config => $params{config},
        url => $params{url}
    );

    return $space->get($node->content);
}

sub inlineContent {
    my $node = shift;

    return &_quoteHtml($node->content);
}

sub openLinkTag {
    my $node = shift;
    my $outputString;

    $outputString = '<a class="extlink" href="' . $node->href . '">';
    # FIXME: chris doesn't like bracketed external links
    #$outputString .= '[' if ($node->type eq 'link');
    return $outputString;
}

sub closeLinkTag {
    my $node = shift;
    my $outputString;

    # FIXME: chris doesn't like bracketed external links
    #$outputString = ']' if ($node->type eq 'link');
    $outputString .= '</a>';
    return $outputString;
}

sub wikiLink {
    my $node = shift;
    my %params = @_;
    my $outputString;
    my $pageNid;

    my $pageName = $node->content;
    if ($pageName =~ s/\#(\d+)$//) {
        $pageNid = $1;
    }

    if ($node->content =~ /:/) {
        $outputString .= '<a href="' .
            &PurpleWiki::Page::getInterWikiLink($pageName, $params{config});
        $outputString .= "#nid$pageNid" if ($pageNid);
        $outputString .= '">' . $node->content . '</a>';
    }
    elsif (&PurpleWiki::Page::exists($pageName, $params{config})) {
        if ($node->type eq 'freelink') {
            $outputString .= '<a href="' .
                &PurpleWiki::Page::getFreeLink($node->content, $params{config}) .
                '">';
        }
        else {
            $outputString .= '<a href="' . &PurpleWiki::Page::getWikiWordLink($pageName, $params{config});
            $outputString .= "#nid$pageNid" if ($pageNid);
            $outputString .= '">';
        }
        $outputString .= $node->content . '</a>';
    }
    else {
        if ($node->type eq 'freelink') {
            $outputString .= '[' . $node->content . ']';
            $outputString .= '<a href="' .
                &PurpleWiki::Page::getFreeLink($node->content, $params{config}) .
                '">';
        }
        else {
            $outputString .= $node->content;
            $outputString .= '<a href="' . &PurpleWiki::Page::getWikiWordLink($pageName, $params{config}) .
                '">';
        }
        $outputString .= '?</a>';
    }
    return $outputString;
}

# functions

sub registerHandlers {
    $PurpleWiki::View::EventHandler::structuralHandler{section}->{pre} =
        sub { push @sectionState, 'section'; return ''; };
    $PurpleWiki::View::EventHandler::structuralHandler{section}->{post} =
        sub { pop @sectionState; return ''; };

    $PurpleWiki::View::EventHandler::structuralHandler{indent}->{pre} =
        sub { return "<div class=\"indent\">\n"; };
    $PurpleWiki::View::EventHandler::structuralHandler{indent}->{post} = 
        sub { return "</div>\n"; };

    $PurpleWiki::View::EventHandler::structuralHandler{ul}->{pre} = \&openTag;
    $PurpleWiki::View::EventHandler::structuralHandler{ul}->{post} = \&closeTagWithNewline;

    $PurpleWiki::View::EventHandler::structuralHandler{ol}->{pre} = \&openTag;
    $PurpleWiki::View::EventHandler::structuralHandler{ol}->{post} = \&closeTagWithNewline;

    $PurpleWiki::View::EventHandler::structuralHandler{dl}->{pre} = \&openTag;
    $PurpleWiki::View::EventHandler::structuralHandler{dl}->{post} = \&closeTagWithNewline;

    $PurpleWiki::View::EventHandler::structuralHandler{h}->{pre} =
        sub { my $node = shift;
              return '<h' . &_headerLevel . '>' . &_anchor($node->id); };
    $PurpleWiki::View::EventHandler::structuralHandler{h}->{post} =
        sub { my $node = shift; my %params = @_;
              return &_nid($node->id, %params) . '</h' . &_headerLevel . '>'; };

    $PurpleWiki::View::EventHandler::structuralHandler{p}->{pre} = \&openTagWithNid;
    $PurpleWiki::View::EventHandler::structuralHandler{p}->{post} = \&closeTagWithNid;

    $PurpleWiki::View::EventHandler::structuralHandler{li}->{pre} = \&openTagWithNid;
    $PurpleWiki::View::EventHandler::structuralHandler{li}->{post} = \&closeTagWithNid;

    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{pre} = \&openTagWithNid;
    $PurpleWiki::View::EventHandler::structuralHandler{dd}->{post} = \&closeTagWithNid;

    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{pre} = \&openTagWithNid;
    $PurpleWiki::View::EventHandler::structuralHandler{dt}->{post} = \&closeTagWithNid;

    $PurpleWiki::View::EventHandler::structuralHandler{pre}->{pre} = \&openTagWithNid;
    $PurpleWiki::View::EventHandler::structuralHandler{pre}->{post} = \&closeTagWithNid;

    $PurpleWiki::View::EventHandler::inlineHandler{b}->{pre} = \&openTag;
    $PurpleWiki::View::EventHandler::inlineHandler{b}->{post} = \&closeTag;

    $PurpleWiki::View::EventHandler::inlineHandler{i}->{pre} = \&openTag;
    $PurpleWiki::View::EventHandler::inlineHandler{i}->{post} = \&closeTag;

    $PurpleWiki::View::EventHandler::inlineHandler{tt}->{pre} = \&openTag;
    $PurpleWiki::View::EventHandler::inlineHandler{tt}->{post} = \&closeTag;

    $PurpleWiki::View::EventHandler::inlineHandler{text}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{nowiki}->{main} = \&inlineContent;

    $PurpleWiki::View::EventHandler::inlineHandler{image}->{main} =
        sub { my $node = shift;
              return '<img src="' . $node->href . '" />'; };

    $PurpleWiki::View::EventHandler::inlineHandler{transclusion}->{main} = \&transcludeContent;

    $PurpleWiki::View::EventHandler::inlineHandler{link}->{pre} = \&openLinkTag;
    $PurpleWiki::View::EventHandler::inlineHandler{link}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{link}->{post} = \&closeLinkTag;

    $PurpleWiki::View::EventHandler::inlineHandler{url}->{pre} = \&openLinkTag;
    $PurpleWiki::View::EventHandler::inlineHandler{url}->{main} = \&inlineContent;
    $PurpleWiki::View::EventHandler::inlineHandler{url}->{post} = \&closeLinkTag;

    $PurpleWiki::View::EventHandler::inlineHandler{wikiword}->{main} = \&wikiLink;
    $PurpleWiki::View::EventHandler::inlineHandler{freelink}->{main} = \&wikiLink;
}

sub view {
    my ($wikiTree, %params) = @_;

    @sectionState = ();
    &registerHandlers;
    $params{url} = '' unless defined($params{url});
    return &PurpleWiki::View::EventHandler::view($wikiTree, %params);
}

# private

sub _quoteHtml {
    my ($html) = @_;

    $html =~ s/&/&amp;/g;
    $html =~ s/</&lt;/g;
    $html =~ s/>/&gt;/g;
    if (1) {   # Make an official option?
        $html =~ s/&amp;([#a-zA-Z0-9]+);/&$1;/g;  # Allow character references
    }
    return $html;
}

sub _headerLevel {
    my $headerLevel = scalar @sectionState + 1;
    $headerLevel = 6 if ($headerLevel > 6);
    return $headerLevel;
}

# FIXME: goes to too much effort to avoid a void return
sub _anchor {
    my $nid = shift;
    my $string = '';

    if ($nid) {
        $string = '<a name="nid0' . $nid . '" id="nid0' . $nid . '"></a>';
    }

    return $string;
}

# FIXME: goes to too much effort to avoid a void return
sub _nid {
    my $nid = shift;
    my %params = @_;
    my $string = '';

    if ($nid) {
        $string = ' &nbsp;&nbsp; <a class="nid" ' .
	                   'title="' . "0$nid" . '" href="' .
			   $params{url} . '#nid0' .
			   $nid . '">#</a>';
    }

    return $string;
}

1;
__END__

=head1 NAME

PurpleWiki::View::wikihtml - WikiHTML view driver

=head1 SYNOPSIS

  use PurpleWiki::View::wikihtml;

=head1 DESCRIPTION

blah blah blah

=head1 METHODS

blah blah blah

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
