package PurpleWiki::Tree;

use strict;
use PurpleWiki::InlineNode;
use PurpleWiki::StructuralNode;
use PurpleWiki::View::Debug;
use PurpleWiki::View::WikiHTML;
use PurpleWiki::View::WikiText;
use PurpleWiki::View::XHTML;
#use PurpleWiki::Page;

### constructor

sub new {
    my $this = shift;
    my (%options) = @_;
    my $self;

    $self = {};
    $self->{'title'} = $options{'title'} if ($options{'title'});
    $self->{'lastNid'} = $options{'lastNid'} if ($options{'lastNid'});
    $self->{'rootNode'} = PurpleWiki::StructuralNode->new('type'=>'document');

    bless($self, $this);
    return $self;
}

### accessors/mutators

sub root {
    my $this = shift;

    return $this->{'rootNode'};
}

sub title {
    my $this = shift;

    $this->{'title'} = shift if @_;
    return $this->{'title'};
}

sub lastNid {
    my $this = shift;

    $this->{'lastNid'} = shift if @_;
    return $this->{'lastNid'};
}

### methods

sub parse {
    my $this = shift;
    my $wikiContent = shift;
    my %params = @_;

    my ($currentNode, @sectionState, $isStart, $nodeContent);
    my ($listLength, $listDepth, $sectionLength, $sectionDepth);
    my ($indentLength, $indentDepth);
    my ($line, $listType, $biggestNidSeen, $currentNid);

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
    $biggestNidSeen = 0;

    $currentNode = $this->root->insertChild('type' => 'section');

    foreach $line (split(/\n/, $wikiContent)) { # Process lines one-at-a-time
        chomp $line;
        if ($isStart && $line =~ /^\[lastnid (\d+)\]$/) {
            $this->lastNid($1);
        }
        elsif ($line =~ /^($aggregateListRegExp)$/) { # Process lists
            foreach $listType (keys(%listMap)) {
                if ($line =~ /^$listMap{$listType}$/) {
                    $currentNode = &_terminateParagraph($currentNode,
                                                        \$nodeContent,
                                                        \$biggestNidSeen);
                    while ($indentDepth > 0) {
                        $currentNode = $currentNode->parent;
                        $indentDepth--;
                    }
                    $currentNode = &_parseList($listType, length $1,
                                               \$listDepth, $currentNode,
                                               \$biggestNidSeen, $2, $3);
                    $isStart = 0 if ($isStart);
                }
            }
        }
        elsif ($line =~ /^(\:+)(.*)$/) {  # indented paragraphs
            $currentNode = &_terminateParagraph($currentNode, \$nodeContent,
                                                \$biggestNidSeen);
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
            $nodeContent =~  s/\s+\[nid (\d+)\]$//s;
            $currentNid = $1;
            $currentNode = $currentNode->insertChild('type'=>'p',
                'content'=>&_parseInlineNode($nodeContent));
            if (defined $currentNid && ($currentNid =~ /^\d+$/)) {
                $currentNode->id($currentNid);
                if ($biggestNidSeen < $currentNid) {
                    $biggestNidSeen = $currentNid;
                }
            }
            $currentNode = $currentNode->parent;
            undef $nodeContent;
            $isStart = 0 if ($isStart);
        }
        elsif ($line =~ /^(\=+)\s+(\S.+)\s+\=+/) {  # header/section
            $currentNode = &_terminateParagraph($currentNode, \$nodeContent,
                                                \$biggestNidSeen);
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
            $nodeContent =~  s/\s+\[nid (\d+)\]$//s;
            $currentNid = $1;
            $currentNode = $currentNode->insertChild('type'=>'h',
                'content'=>&_parseInlineNode($nodeContent));
            if (defined $currentNid && ($currentNid =~ /^\d+$/)) {
                $currentNode->id($currentNid);
                if ($biggestNidSeen < $currentNid) {
                    $biggestNidSeen = $1;
                }
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
                                                    \$nodeContent,
                                                    \$biggestNidSeen);
                $currentNode = $currentNode->insertChild('type'=>'pre');
            }
            $nodeContent .= "$1\n";
            $isStart = 0 if ($isStart);
        }
        elsif ($line =~ /^\s*$/) {  # blank line
            $currentNode = &_terminateParagraph($currentNode, \$nodeContent,
                                                \$biggestNidSeen);
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
                                                    \$nodeContent,
                                                    \$biggestNidSeen);
                $currentNode = $currentNode->insertChild('type'=>'p');
            }
            $nodeContent .= "$line\n";
            $isStart = 0 if ($isStart);
        }
    }
    $currentNode = &_terminateParagraph($currentNode, \$nodeContent,
                                        \$biggestNidSeen);
    if ($params{'add_node_ids'}) {
        if ($biggestNidSeen > $this->lastNid) {
            $this->lastNid($biggestNidSeen);
        }
        $this->lastNid(&_addNodeIds($this->root, $this->lastNid));
    }
}

sub _terminateParagraph {
    my ($currentNode, $nodeContentRef, $biggestNidSeenRef) = @_;
    my ($currentNid);

    if (($currentNode->type eq 'p') || ($currentNode->type eq 'pre')) {
        chomp ${$nodeContentRef};
        ${$nodeContentRef} =~ s/\s+\[nid (\d+)\]$//s;
        $currentNid = $1;
        if (defined $currentNid && ($currentNid =~ /^\d+$/)) {
            $currentNode->id($currentNid);
            if (${$biggestNidSeenRef} < $currentNid) {
                ${$biggestNidSeenRef} = $currentNid;
            }
        }
        $currentNode->content(&_parseInlineNode(${$nodeContentRef}));
        undef ${$nodeContentRef};
        return $currentNode->parent;
    }
    return $currentNode;
}

sub _parseList {
    my ($listType, $listLength, $listDepthRef,
        $currentNode, $biggestNidSeenRef, @nodeContents) = @_;
    my ($currentNid);

    while ($listLength > ${$listDepthRef}) {
        $currentNode = $currentNode->insertChild('type'=>$listType);
        ${$listDepthRef}++;
    }
    while ($listLength < ${$listDepthRef}) {
        $currentNode = $currentNode->parent;
        ${$listDepthRef}--;
    }
    $nodeContents[0] =~  s/\s+\[nid (\d+)\]$//s;
    $currentNid = $1;
    if ($listType eq 'dl') {
        $currentNode = $currentNode->insertChild('type'=>'dt',
            'content'=>&_parseInlineNode($nodeContents[0]));
        if (defined $currentNid && ($currentNid =~ /^\d+$/)) {
            $currentNode->id($currentNid);
            if (${$biggestNidSeenRef} < $currentNid) {
                ${$biggestNidSeenRef} = $currentNid;
            }
        }
        $currentNode = $currentNode->parent;
        $nodeContents[1] =~  s/\s+\[nid (\d+)\]$//s;
        $currentNid = $1;
        $currentNode = $currentNode->insertChild('type'=>'dd',
            'content'=>&_parseInlineNode($nodeContents[1]));
        if (defined $currentNid && ($currentNid =~ /^\d+$/)) {
            $currentNode->id($currentNid);
            if (${$biggestNidSeenRef} < $currentNid) {
                ${$biggestNidSeenRef} = $currentNid;
            }
        }
        return $currentNode->parent;
    }
    else {
        $currentNode = $currentNode->insertChild('type'=>'li',
            'content'=>&_parseInlineNode($nodeContents[0]));
        if (defined $currentNid && ($currentNid =~ /^\d+$/)) {
            $currentNode->id($currentNid);
            if (${$biggestNidSeenRef} < $currentNid) {
                ${$biggestNidSeenRef} = $currentNid;
            }
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
    my $rxProtocols = '(?i)(?:http|https|ftp|afs|news|mid|cid|nntp|mailto|wais):';
    my $rxWikiWord = '[A-Z]+[a-z]+[A-Z]\w*';
    my $rxSubpage = '[A-Z]+[a-z]+\w*';
    my $rxQuoteDelim = '(?:"")?';
    my $rxDoubleBracketed = '\[\[\w[\w\s]+\]\]';

    # For some reason, the split below results in a lot of empty list
    # members.  Hence the grep.
    my @nodes = grep(!/^$/,
        split(/(?:
                ($rxNowiki) |
                ($rxTt) |
                ($rxFippleQuotes) |
                ($rxB) |
                ($rxTripleQuotes) |
                ($rxI) |
                ($rxDoubleQuotes) |
                (\[$rxProtocols$rxAddress\s*.*?\]) |
                ($rxProtocols$rxAddress) |
                ((?:$rxWikiWord)?\/$rxSubpage(?:\#\d+)?$rxQuoteDelim) |
                ([A-Z]\w+:$rxWikiWord(?:\#\d+)?$rxQuoteDelim) |
                ($rxWikiWord(?:\#\d+)?$rxQuoteDelim) |
                ($rxDoubleBracketed)
                )/xs, $text)
        );
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
        elsif ($node =~ /\[($rxProtocols$rxAddress)\s*(.*?)\]/s) {
            # bracketed link
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'link',
                                                           'href'=>$1,
                                                           'content'=>$2);
        }
        elsif ($node =~ /^$rxProtocols$rxAddress$/) {
            # URL
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'url',
                                                           'href'=>$node,
                                                           'content'=>$node);
        }
        elsif ($node =~ /(?:$rxWikiWord)?\/$rxSubpage(?:\#\d+)?$rxQuoteDelim/s) {
            $node =~ s/""$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'wikiword',
#                                                           'href'=>&PurpleWiki::Page::getWikiWordLink($node),
                                                           'content'=>$node);
        }
        elsif ($node =~ /[A-Z]\w+:$rxWikiWord(?:\#\d+)?$rxQuoteDelim/s) {
            $node =~ s/""$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'wikiword',
#                                                           'href'=>&PurpleWiki::Page::getInterWikiLink($node),
                                                           'content'=>$node);
        }
        elsif ($node =~ /$rxWikiWord(?:\#\d+)?$rxQuoteDelim/s) {
            $node =~ s/""$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'wikiword',
#                                                           'href'=>&PurpleWiki::Page::getWikiWordLink($node),
                                                           'content'=>$node);
        }
        elsif ($node =~ /$rxDoubleBracketed/s) {
            $node =~ s/^\[\[//;
            $node =~ s/\]\]$//;
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'freelink',
#                                                           'href'=>&PurpleWiki::Page::getFreeLink($node),
                                                           'content'=>$node);
        }
        else {
            push @inlineNodes, PurpleWiki::InlineNode->new('type'=>'text',
                                                           'content'=>$node);
        }
    }
    return \@inlineNodes;
}

sub view {
    my $this = shift;
    my ($driver, %params) = @_;

    if (lc($driver) eq 'xhtml') {
        &PurpleWiki::View::XHTML::view($this, %params);
    }
    elsif (lc($driver) eq 'debug') {
        &PurpleWiki::View::Debug::view($this, %params);
    } 
    elsif (lc($driver) eq 'wikihtml') {
        &PurpleWiki::View::WikiHTML::view($this, %params);
    }
    elsif (lc($driver) eq 'wiki') {
        &PurpleWiki::View::WikiText::view($this, %params);
    }
}

sub _addNodeIds {
    my ($rootNode, $currentNid) = @_;

    &_traverseAndAddNids($rootNode->children, \$currentNid)
        if ($rootNode->children);
    return $currentNid;
}

sub _traverseAndAddNids {
    my ($nodeListRef, $currentNidRef) = @_;

    foreach my $node (@{$nodeListRef}) {
        if (($node->type eq 'h' || $node->type eq 'p' ||
             $node->type eq 'li' || $node->type eq 'pre' ||
             $node->type eq 'dt' || $node->type eq 'dd') &&
            !$node->id) {
            ${$currentNidRef}++;
            $node->id(${$currentNidRef});
        }
        my $childrenRef = $node->children;
        &_traverseAndAddNids($childrenRef, $currentNidRef)
            if ($childrenRef);
    }
}

1;
