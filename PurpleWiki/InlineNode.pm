package PurpleWiki::InlineNode;

use strict;

### constructor

sub new {
    my $this = shift;
    my (%attrib) = @_;
    my $self = {};

    ### Need to add type checking here. -eek
    $self->{'type'} = $attrib{'type'} if ($attrib{'type'});
    $self->{'href'} = $attrib{'href'} if ($attrib{'href'});
    bless $self, $this;

    $self->data($attrib{'data'}) if ($attrib{'data'});
    return $self;
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
                ((?:$rxWikiWord)?\/$rxSubpage$rxQuoteDelim) |
                ([A-Z]\w+:$rxWikiWord$rxQuoteDelim) |
                ($rxWikiWord$rxQuoteDelim) |
                ($rxDoubleBracketed)
                )/xs, $text)
        );
    my $numNodes = scalar @nodes;
    foreach my $node (@nodes) {
        if ($node =~ /^$rxNowiki$/s) {
            $node =~ s/^<nowiki>//;
            $node =~ s/<\/nowiki>$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'nowiki', 'data'=>$node);
        }
        elsif ($node =~ /^$rxTt$/s) {
            $node =~ s/^<tt>//;
            $node =~ s/<\/tt>$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'tt', 'data'=>$node);
        }
        elsif ($node =~ /^$rxFippleQuotes$/s) {
            $node =~ s/^'''//;
            $node =~ s/'''$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'b', 'data'=>$node);
        }
        elsif ($node =~ /^$rxB$/s) {
            $node =~ s/^<b>//;
            $node =~ s/<\/b>$//;
            push @inlineNodes, 
                PurpleWiki::InlineNode->new('type'=>'b', 'data'=>$node);
        }
        elsif ($node =~ /^$rxTripleQuotes$/s) {
            $node =~ s/^'''//;
            $node =~ s/'''$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'b', 'data'=>$node);
        }
        elsif ($node =~ /^$rxI$/s) {
            $node =~ s/^<i>//;
            $node =~ s/<\/i>$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'i', 'data'=>$node);
        }
        elsif ($node =~ /^$rxDoubleQuotes$/s) {
            $node =~ s/^''//;
            $node =~ s/''$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'i', 'data'=>$node);
        }
        elsif ($node =~ /\[($rxProtocols$rxAddress)\s*(.*?)\]/s) {
            # bracketed link
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'link', 'href'=>$1,
                                            'data'=>$2);
        }
        elsif ($node =~ /^$rxProtocols$rxAddress$/) {
            # URL
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'link', 'href'=>$node,
                                            'data'=>$node);
        }
        elsif ($node =~ /(?:$rxWikiWord)?\/$rxSubpage$rxQuoteDelim/s) {
            $node =~ s/""$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'link',
                                            'data'=>$node);
        }
        elsif ($node =~ /[A-Z]\w+:$rxWikiWord$rxQuoteDelim/s) {
            $node =~ s/""$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'link',
                                            'data'=>$node);
        }
        elsif ($node =~ /$rxWikiWord$rxQuoteDelim/s) {
            $node =~ s/""$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'link',
                                            'data'=>$node);
        }
        elsif ($node =~ /$rxDoubleBracketed/s) {
            $node =~ s/^\[\[//;
            $node =~ s/\]\]$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'link',
                                            'data'=>$node);
        }
        else {
            push @inlineNodes, $node;
        }
    }
    return \@inlineNodes;
}

### accessors/mutators

sub type {
    my $this = shift;

    $this->{'type'} = shift if @_;
    return $this->{'type'};
}

sub href {
    my $this = shift;

    $this->{'href'} = shift if @_;
    return $this->{'href'};
}

sub data {
    my $this = shift;

    if (@_) {
        my $data = shift;
        if ( (!defined $this->type) || ($this->type ne 'nowiki') &&
             ($this->type ne 'link') ) {
            $this->{'data'} = &_parseInlineNode($data);
        }
        else {
            $this->{'data'} = ([$data]);
        }
    }
    return $this->{'data'};
}

1;
