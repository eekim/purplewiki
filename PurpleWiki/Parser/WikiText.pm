# PurpleWiki::Parser::WikiText.pm
#
# $Id: WikiText.pm,v 1.7.6.2 2003/05/21 05:19:01 cdent Exp $
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

package PurpleWiki::Parser::WikiText;

use 5.005;
use strict;
use PurpleWiki::InlineNode;
use PurpleWiki::StructuralNode;
use PurpleWiki::Tree;
use PurpleWiki::Sequence;
use PurpleWiki::Config;

my $sequence;
my $url;

### constructor

sub new {
    my $this = shift;
    my $self = {};

    bless($self, $this);
    $sequence = new PurpleWiki::Sequence("$DataDir/sequence");
    return $self;
}

### methods

sub parse {
    my $this = shift;
    my $wikiContent = shift;
    my %params = @_;

    $url = $params{url};

    my $tree = PurpleWiki::Tree->new;
    my ($currentNode, @sectionState, $isStart, $nodeContent);
    my ($listLength, $listDepth, $sectionLength, $sectionDepth);
    my ($indentLength, $indentDepth);
    my ($line, $listType, $currentNid);
    my (@authors);

    my %listMap = ('ul' => '(\*+)\s*(.*)',
                   'ol' => '(\#+)\s*(.*)',
                   'dl' => '(\;+)([^:]+\:?)\:(.*)',
                  );

    my $aggregateListRegExp = join('|', values(%listMap));

    $wikiContent =~ s/\\ *\r?\n/ /g;     # Join lines with backslash at end

    $isStart = 1;
    $listDepth = 0;
    $indentDepth = 0;
    $sectionDepth = 1;
    @authors = ();

    $currentNode = $tree->root->insertChild('type' => 'section');

    foreach $line (split(/\n/, $wikiContent)) { # Process lines one-at-a-time
        chomp $line;
        if ($isStart && $line =~ /^\[title (.+)\]$/) {
            # The metadata below is not (currently) used by the
            # Wiki.  It's here to so that this parser can be used
            # as a general documentation formatting system.
            $tree->title($1);
        }
        elsif ($isStart && $line =~ /^\[subtitle (.+)\]$/) {
            # See above.
            $tree->subtitle($1);
        }
        elsif ($isStart && $line =~ /^\[docid (.+)\]$/) {
            # See above.
            $tree->id($1);
        }
        elsif ($isStart && $line =~ /^\[date (.+)\]$/) {
            # See above.
            $tree->date($1);
        }
        elsif ($isStart && $line =~ /^\[version (.+)\]$/) {
            # See above.
            $tree->version($1);
        }
        elsif ($isStart && $line =~ /^\[author (.+)\]$/) {
            # See above.
            my $authorString = $1;
            $authorString =~ s/\s+(\S+\@\S+)$//;
            my $authorEmail = $1 if ($1 ne $authorString);
            if ($authorEmail) {
                push @authors, [$authorString, $authorEmail];
            }
            else {
                push @authors, [$authorString];
            }
        }
        elsif ($line =~ /^($aggregateListRegExp)$/) { # Process lists
            foreach $listType (keys(%listMap)) {
                if ($line =~ /^$listMap{$listType}$/) {
                    $currentNode = &_terminateParagraph($currentNode,
                                                        \$nodeContent);
                    while ($indentDepth > 0) {
                        $currentNode = $currentNode->parent;
                        $indentDepth--;
                    }
                    $currentNode = &_parseList($listType, length $1,
                                               \$listDepth, $currentNode,
                                               $2, $3);
                    $isStart = 0 if ($isStart);
                }
            }
        }
        elsif ($line =~ /^(\:+)(.*)$/) {  # indented paragraphs
            $currentNode = &_terminateParagraph($currentNode, \$nodeContent);
            while ($listDepth > 0) {
                $currentNode = $currentNode->parent;
                $listDepth--;
            }
            $listLength = length $1;
            $nodeContent = $2;
            while ($listLength > $indentDepth) {
                $currentNode = $currentNode->insertChild('type'=>'indent');
                $indentDepth++;
            }
            while ($listLength < $indentDepth) {
                $currentNode = $currentNode->parent;
                $indentDepth--;
            }
            $nodeContent =~  s/\s+\[nid ([A-Z0-9]+)\]$//s;
            $currentNid = $1;
            $currentNode = $currentNode->insertChild('type'=>'p',
                'content'=>&_parseInlineNode($nodeContent));
            if (defined $currentNid && ($currentNid =~ /^[A-Z0-9]+$/)) {
                $currentNode->id($currentNid);
            }
            $currentNode = $currentNode->parent;
            undef $nodeContent;
            $isStart = 0 if ($isStart);
        }
        elsif ($line =~ /^(\=+)\s+(.+)\s+\=+/) {  # header/section
            $currentNode = &_terminateParagraph($currentNode, \$nodeContent);
            while ($listDepth > 0) {
                $currentNode = $currentNode->parent;
                $listDepth--;
            }
            while ($indentDepth > 0) {
                $currentNode = $currentNode->parent;
                $indentDepth--;
            }
            $sectionLength = length $1;
            $nodeContent = $2;
            if ($sectionLength > $sectionDepth) {
                while ($sectionLength > $sectionDepth) {
                    $currentNode = $currentNode->insertChild(type=>'section');
                    $sectionDepth++;
                }
            }
            else {
                while ($sectionLength < $sectionDepth) {
                    $currentNode = $currentNode->parent;
                    $sectionDepth--;
                }
                if ( !$isStart && ($sectionLength == $sectionDepth) ) {
                    $currentNode = $currentNode->parent;
                    $currentNode = $currentNode->insertChild(type=>'section');
                }
            }
            $nodeContent =~  s/\s+\[nid ([A-Z0-9]+)\]$//s;
            $currentNid = $1;
            $currentNode = $currentNode->insertChild('type'=>'h',
                'content'=>&_parseInlineNode($nodeContent));
            if (defined $currentNid && ($currentNid =~ /^[A-Z0-9]+$/)) {
                $currentNode->id($currentNid);
            }
            $currentNode = $currentNode->parent;
            undef $nodeContent;
            $isStart = 0 if ($isStart);
        }
        elsif ($line =~ /^(\s+\S.*)$/) {  # preformatted
            if ($currentNode->type ne 'pre') {
                while ($listDepth > 0) {
                    $currentNode = $currentNode->parent;
                    $listDepth--;
                }
                while ($indentDepth > 0) {
                    $currentNode = $currentNode->parent;
                    $indentDepth--;
                }
                $currentNode = &_terminateParagraph($currentNode,
                                                    \$nodeContent);
                $currentNode = $currentNode->insertChild('type'=>'pre');
            }
            $nodeContent .= "$1\n";
            $isStart = 0 if ($isStart);
        }
        elsif ($line =~ /^\s*$/) {  # blank line
            $currentNode = &_terminateParagraph($currentNode, \$nodeContent);
            while ($listDepth > 0) {
                $currentNode = $currentNode->parent;
                $listDepth--;
            }
            while ($indentDepth > 0) {
                $currentNode = $currentNode->parent;
                $indentDepth--;
            }
        }
        else {
            if ($currentNode->type ne 'p') {
                while ($listDepth > 0) {
                    $currentNode = $currentNode->parent;
                    $listDepth--;
                }
                while ($indentDepth > 0) {
                    $currentNode = $currentNode->parent;
                    $indentDepth--;
                }
                $currentNode = &_terminateParagraph($currentNode,
                                                    \$nodeContent);
                $currentNode = $currentNode->insertChild('type'=>'p');
            }
            $nodeContent .= "$line\n";
            $isStart = 0 if ($isStart);
        }
    }
    $currentNode = &_terminateParagraph($currentNode, \$nodeContent);
    if (scalar @authors > 0) {
        $tree->authors(\@authors);
    }

    if ($params{'add_node_ids'}) {
        &_addNodeIds($tree->root);
    }
    return $tree;
}

### private

sub _terminateParagraph {
    my ($currentNode, $nodeContentRef) = @_;
    my ($currentNid);

    if (($currentNode->type eq 'p') || ($currentNode->type eq 'pre')) {
        chomp ${$nodeContentRef};
        ${$nodeContentRef} =~ s/\s+\[nid ([A-Z0-9]+)\]$//s;
        $currentNid = $1;
        if (defined $currentNid && ($currentNid =~ /^[A-Z0-9]+$/)) {
            $currentNode->id($currentNid);
        }
        $currentNode->content(&_parseInlineNode(${$nodeContentRef}));
        undef ${$nodeContentRef};
        return $currentNode->parent;
    }
    return $currentNode;
}

sub _parseList {
    my ($listType, $listLength, $listDepthRef,
        $currentNode, @nodeContents) = @_;
    my ($currentNid);

    while ($listLength > ${$listDepthRef}) {
        $currentNode = $currentNode->insertChild('type'=>$listType);
        ${$listDepthRef}++;
    }
    while ($listLength < ${$listDepthRef}) {
        $currentNode = $currentNode->parent;
        ${$listDepthRef}--;
    }
    $nodeContents[0] =~  s/\s+\[nid ([A-Z0-9]+)\]$//s;
    $currentNid = $1;
    if ($listType eq 'dl') {
        $currentNode = $currentNode->insertChild('type'=>'dt',
            'content'=>&_parseInlineNode($nodeContents[0]));
        if (defined $currentNid && ($currentNid =~ /^[A-Z0-9]+$/)) {
            $currentNode->id($currentNid);
        }
        $currentNode = $currentNode->parent;
        $nodeContents[1] =~  s/\s+\[nid ([A-Z0-9]+)\]$//s;
        $currentNid = $1;
        $currentNode = $currentNode->insertChild('type'=>'dd',
            'content'=>&_parseInlineNode($nodeContents[1]));
        if (defined $currentNid && ($currentNid =~ /^[A-Z0-9]+$/)) {
            $currentNode->id($currentNid);
        }
        return $currentNode->parent;
    }
    else {
        $currentNode = $currentNode->insertChild('type'=>'li',
            'content'=>&_parseInlineNode($nodeContents[0]));
        if (defined $currentNid && ($currentNid =~ /^[A-Z0-9]+$/)) {
            $currentNode->id($currentNid);
        }
        return $currentNode->parent;
    }
    return $currentNode;
}

sub _parseInlineNode {
    my $text = shift;
    my (@inlineNodes);

    # markup regular expressions
    my $rxNowiki = '<nowiki>.*?<\/nowiki>';
    my $rxTt = '<tt>.*?<\/tt>';
    my $rxFippleQuotes = "'''''.*?'''''";
    my $rxB = '<b>.*?<\/b>';
    my $rxTripleQuotes = "'''.*?'''";
    my $rxI = '<i>.*?<\/i>';
    my $rxDoubleQuotes = "''.*?''";
    # link regular expressions
    my $rxAddress = '[^]\s]*[\w/]';
    my $rxProtocols = '(?i:http|https|ftp|afs|news|mid|cid|nntp|mailto|wais):';
    my $rxWikiWord = '[A-Z]+[a-z]+[A-Z]\w*';
    my $rxSubpage = '[A-Z]+[a-z]+\w*';
    my $rxQuoteDelim = '(?:"")?';
    my $rxDoubleBracketed = '\[\[[\w\/][\w\/\s]+\]\]';

    my @nodes = split(/($rxNowiki |
			$rxTt |
			$rxFippleQuotes |
			$rxB |
			$rxTripleQuotes |
			$rxI |
			$rxDoubleQuotes |
			\[$rxProtocols$rxAddress\s*.*?\] |
			$rxProtocols$rxAddress |
			(?:$rxWikiWord)?\/$rxSubpage(?:\#\d+)?$rxQuoteDelim |
			[A-Z]\w+:$rxWikiWord(?:\#\d+)?$rxQuoteDelim |
			$rxWikiWord(?:\#\d+)?$rxQuoteDelim |
			$rxDoubleBracketed
			)/xs, $text);
    foreach my $node (@nodes) {
        if ($node =~ /^$rxNowiki$/s) {
            $node =~ s/^<nowiki>//;
            $node =~ s/<\/nowiki>$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'nowiki',
                                                           'content'=>$node);
        }
        elsif ($node =~ /^$rxTt$/s) {
            $node =~ s/^<tt>//;
            $node =~ s/<\/tt>$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'tt',
                'children'=>&_parseInlineNode($node));
        }
        elsif ($node =~ /^$rxFippleQuotes$/s) {
            $node =~ s/^'''//;
            $node =~ s/'''$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'b',
                'children'=>&_parseInlineNode($node));
        }
        elsif ($node =~ /^$rxB$/s) {
            $node =~ s/^<b>//;
            $node =~ s/<\/b>$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'b',
                'children'=>&_parseInlineNode($node));
        }
        elsif ($node =~ /^$rxTripleQuotes$/s) {
            $node =~ s/^'''//;
            $node =~ s/'''$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'b',
                'children'=>&_parseInlineNode($node));
        }
        elsif ($node =~ /^$rxI$/s) {
            $node =~ s/^<i>//;
            $node =~ s/<\/i>$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'i',
                'children'=>&_parseInlineNode($node));
        }
        elsif ($node =~ /^$rxDoubleQuotes$/s) {
            $node =~ s/^''//;
            $node =~ s/''$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'i',
                'children'=>&_parseInlineNode($node));
        }
        elsif ($node =~ /^\[($rxProtocols$rxAddress)\s*(.*?)\]$/s) {
            # bracketed link
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'link',
                                                           'href'=>$1,
                                                           'content'=>$2);
        }
        elsif ($node =~ /^$rxProtocols$rxAddress$/s) {
            # URL
            if ($node =~ /\.(?:jpg|gif|png|bmp|jpeg)$/i) {
                push @inlineNodes,
                    PurpleWiki::InlineNode->new('type'=>'image',
                                                'href'=>$node,
                                                'content'=>$node);
            }
            else {
                push @inlineNodes,
                    PurpleWiki::InlineNode->new('type'=>'url',
                                                'href'=>$node,
                                                'content'=>$node);
            }
        }
        elsif ($node =~ /^(?:$rxWikiWord)?\/$rxSubpage(?:\#\d+)?$rxQuoteDelim$/s) {
            $node =~ s/""$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'wikiword',
                                                           'content'=>$node);
        }
        elsif ($node =~ /^([A-Z]\w+):($rxWikiWord(?:\#\d+)?)$rxQuoteDelim$/s) {
            my $site = $1;
            my $page = $2;
            if (&PurpleWiki::Page::siteExists($site)) {
                $node =~ s/""$//;
                push @inlineNodes,
                    PurpleWiki::InlineNode->new('type'=>'wikiword',
                                                'content'=>$node);
            }
            else {
                if ($site =~ /^$rxWikiWord$/) {
                    push @inlineNodes,
                        PurpleWiki::InlineNode->new('type'=>'wikiword',
                                                    'content'=>$site);
                    push @inlineNodes,
                        PurpleWiki::InlineNode->new('type'=>'text',
                                                    'content'=>':');
                }
                else {
                    push @inlineNodes,
                        PurpleWiki::InlineNode->new('type'=>'text',
                                                    'content'=>"$site:");
                }
                push @inlineNodes,
                    PurpleWiki::InlineNode->new('type'=>'wikiword',
                                                'content'=>$page);
            }
        }
        elsif ($node =~ /$rxWikiWord(?:\#\d+)?$rxQuoteDelim/s) {
            $node =~ s/""$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'wikiword',
                                                           'content'=>$node);
        }
        elsif ($node =~ /$rxDoubleBracketed/s) {
            $node =~ s/^\[\[//;
            $node =~ s/\]\]$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'freelink',
                                                           'content'=>$node);
        }
        elsif ($node ne '') {
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'text',
                                                           'content'=>$node);
        }
    }
    return \@inlineNodes;
}

sub _addNodeIds {
    my ($rootNode) = @_;

    &_traverseAndAddNids($rootNode->children)
        if ($rootNode->children);
}

sub _traverseAndAddNids {
    my ($nodeListRef) = @_;

    foreach my $node (@{$nodeListRef}) {
        if (($node->type eq 'h' || $node->type eq 'p' ||
             $node->type eq 'li' || $node->type eq 'pre' ||
             $node->type eq 'dt' || $node->type eq 'dd') &&
            !$node->id) {
            $node->id($sequence->getNext($url));
        }
        my $childrenRef = $node->children;
        &_traverseAndAddNids($childrenRef)
            if ($childrenRef);
    }
}

1;
__END__

=head1 NAME

PurpleWiki::Parser::WikiText - Default PurpleWiki parser.

=head1 SYNOPSIS

  use PurpleWiki::Parser::WikiText;

  my $parser = PurpleWiki::Parser::WikiText->new;
  my $wikiTree = $parser->parse($wikiText);

=head1 DESCRIPTION

Parses a Wiki text file, and returns a PurpleWiki::Tree.

This parser can be replaced by another module that reimplements the
parse() method, which returns a PurpleWiki::Tree.  This way, we can
support multiple parsers, ranging from the default Wiki text to XML.

This parser supports metadata parsing that is not currently used by
PurpleWiki.  This additional metadata support enables this parser to
be used as a general document authoring system.

=head1 MOTIVATION

PurpleWiki's parser and modular architecture are what separate it from
other Wikis.  Most Wikis, including UseModWiki, transform Wiki text
into HTML by applying a series of regular expressions.  The emphasis
is on simplicity of implementation, not correctness.  As a result, the
the HTML is often incorrect, and the parsers are difficult to modify.

Incorrect HTML prevents many Wikis from working correctly with CSS
stylesheets.  It also makes the resulting pages unparseable, although
that is an attribute shared by many web sites and applications.

More impairing is the simplistic parsing strategy and the tight
coupling of the code, which makes it difficult to modify the parser or
the parser's output.  We found this untenable, because we needed to
modify the parser to support purple numbers.  We also wanted to
support multiple view specifications and output formats, including
collapsible outline views of text, XML output, etc.  Finally, we
wanted to support multipe parsers, so that our Wikis could be used to
view and manipulate documents formatted all kinds of ways.
PurpleWiki::Parser::WikiText was designed to meet all of these
requirements.

=head1 ALGORITHM

This parser analyzes text line-by-line, parsing textual elements into
structural nodes (PurpleWiki::StructuralNode).  Structural nodes are
delimited by blank lines or by syntax indicating new structural nodes.
For example, several lines of text followed by a line that starts with
an asterisk indicates the termination of a paragraph structural node
followed by a list structural node.  In other words:

  This is a sample paragraph.
  * This is a list item.

parses to:

  P: This is a sample paragraph.
  UL:
   LI: This is a list item.

As soon as a structural node is terminated, the contents of that node
are parsed into inline nodes (PurpleWiki::InlineNode).

=head2 SECTIONS

HTML has the notion of numbered headers -- h1, h2, etc.  This is poor
design from the point of view of structural markup.  Header tags
typically are used to indicate the size of the displayed header, and
are not consistently used in a semantically consistent way.  Because
Wikis are designed to convert markup into HTML, header markup ("="
in our case) correspond exactly to the equivalent HTML header tags.

Proper document markup languages (like DocBook, Purple, and XHTML 2)
have the notion of sections.  Instead of:

  <h1>Headline News</h1>

  <p>These are today's top stories.</p>

  <h2>PurpleWiki Released, World Celebrates</h2>

  <p>PurpleWiki was released today.</p>

you have something like:

  <section>
    <h>Headline News</h>

    <p>These are today's top stories.</p>

    <section>
      <h>PurpleWiki Released, World Celebrates</h>

      <p>PurpleWiki was released today.</p>
    </section>
  </section>

In the first case, the structural delineation between sections is
implied; in the latter case, it is explicit.

PurpleWiki's data model uses sections rather than numerical headers.
It determines the nestedness of a section by the number of equal signs
in a header.  For example:

  == Introduction ==

  This is an introduction.

is parsed as:

  SECTION:
    SECTION:
      H: Introduction

      P: This is an introduction.

If there is no starting header, then the initial content is assumed to
be in the top-level section.  For example:

  This document starts with a paragraph, not a header.

is parsed as:

  SECTION:
    P: This document starts with a paragraph, not a header.

=head2 PURPLE NUMBERS

PurpleWiki's most obvious unique feature is its support of purple
numbers.  Every structural node gets a node ID that is unique and
immutable, and which is displayed as a purple number.  PurpleWiki uses
new markup -- [nid] -- to indicate purple numbers and
related metadata.  The reason these tags exist and are displayed,
rather than generating purple numbers dynamically, is to enable
persistent, immutable IDs.  That is, if this paragraph had the purple
number "023", and I moved this paragraph to a new location, this
paragraph should retain the same purple number.  Because Wiki editing
is essentially equivalent as replacing the current document with
something entirely new, PurpleWiki includes the node IDs as markup, so
when the modified text is submitted, nodes retain their old IDs.

PurpleWiki does not expect nor desire users to add these IDs
themselves.  This is the job of the parser.  If the add_node_ids
parameter is set, when the parser is finished parsing the text, it
traverses the tree and adds IDs to nodes that do not already have
them.  The reason the parser does a second pass rather than adds the
IDs as it parses the text is that it cannot assume that all of the IDs
are unique, even though they are supposed to be, or that the last node
ID (lastNid) value is correct for that document.  (This implementation
does not currently check for unique IDs, although it does check to
make sure the lastNid value is correct.)

Suppose you had the document:

  = Hello, World! =

  This is an example.

This would be parsed into:

  SECTION:
    H: Hello, World!

    P: This is an example.

Because there are no purple numbers in this markup, the parser assigns
them.  Now the document looks like:

  = Hello, World! [nid 1] =

  This is an example. [nid 2]

Suppose you insert a paragraph before the existing one:

  = Hello, World! [nid 1] =

  New paragraph.

  This is an example. [nid 2]

When this gets parsed, the new paragraph is assigned an ID;

  = Hello, World! [nid 1] =

  New paragraph. [nid 3]

  This is an example. [nid 2]

Note the IDs have stayed with the nodes to which they were
originally assigned. Suppose we delete the new paragraph, and add
a list item after the remaining paragraph.  Parsing and adding new
IDs will result in:

  = Hello, World! [nid 1] =

  This is an example. [nid 2]

  * List item. [nid 4]

Note that the list item has a node ID of 4, not 3.

Users are supposed to ignore the purple number tags, but of course,
there is no way to guarantee this. 

=head1 METHODS

=head2 new()

Constructor.

=head2 parse($wikiContent, %params)

Parses $wikiContent into a PurpleWiki::Tree.  The following parameters
are supported:

  add_node_ids -- Add IDs to structural nodes that do not already
                  have them.

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Tree>.

=cut
