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

    if ($attrib{'data'}) {
        if ((!defined $self->type) || ($self->{'type'} ne 'nowiki')) {
            $self->data(&_parseInlineNode($attrib{'data'}));
        }
        else {
            $self->data([$attrib{'data'}]);
        }
    }
    return $self;
}

sub _parseInlineNode {
    my $text = shift;
    my (@inlineNodes);

    my $regexpNowiki = '<nowiki>.*?<\/nowiki>';
    my $regexpTt = '<tt>.*?<\/tt>';
    my $regexpFippleQuotes = "'''''.*?'''''";
    my $regexpB = '<b>.*?<\/b>';
    my $regexpTripleQuotes = "'''.*?'''";
    my $regexpI = '<i>.*?<\/i>';
    my $regexpDoubleQuotes = "''.*?''";

    # For some reason, the split below results in a lot of empty list
    # members.  Hence the grep.
    my @nodes = grep(!/^$/,
        split(/(?:
                ($regexpNowiki) |
                ($regexpTt) |
                ($regexpFippleQuotes) |
                ($regexpB) |
                ($regexpTripleQuotes) |
                ($regexpI) |
                ($regexpDoubleQuotes)
                )/xs, $text)
        );
    my $numNodes = scalar @nodes;
    foreach my $node (@nodes) {
        if ($node =~ /^$regexpNowiki$/s) {
            $node =~ s/^<nowiki>//;
            $node =~ s/<\/nowiki>$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'nowiki', 'data'=>$node);
        }
        elsif ($node =~ /^$regexpTt$/s) {
            $node =~ s/^<tt>//;
            $node =~ s/<\/tt>$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'tt', 'data'=>$node);
        }
        elsif ($node =~ /^$regexpFippleQuotes$/s) {
            $node =~ s/^'''//;
            $node =~ s/'''$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'b', 'data'=>$node);
        }
        elsif ($node =~ /^$regexpB$/s) {
            $node =~ s/^<b>//;
            $node =~ s/<\/b>$//;
            push @inlineNodes, 
                PurpleWiki::InlineNode->new('type'=>'b', 'data'=>$node);
        }
        elsif ($node =~ /^$regexpTripleQuotes$/s) {
            $node =~ s/^'''//;
            $node =~ s/'''$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'b', 'data'=>$node);
        }
        elsif ($node =~ /^$regexpI$/s) {
            $node =~ s/^<i>//;
            $node =~ s/<\/i>$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'i', 'data'=>$node);
        }
        elsif ($node =~ /^$regexpDoubleQuotes$/s) {
            $node =~ s/^''//;
            $node =~ s/''$//;
            push @inlineNodes,
                PurpleWiki::InlineNode->new('type'=>'i', 'data'=>$node);
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

    $this->{'data'} = shift if @_;
    return $this->{'data'};
}

1;
