package PurpleWiki::Tree;

use strict;
use PurpleWiki::StructuralNode;
use PurpleWiki::View::Debug;
use PurpleWiki::View::XHTML;


### constructor

sub new {
    my $this = shift;
    my (%options) = @_;
    my $self;

    $self = {};
    $self->{'title'} = $options{'title'} if ($options{'title'});
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

### methods

sub parse {
    my $this = shift;
    my $wikiContent = shift;
    my ($currentNode, @sectionState, $isStart, $nodeContent);
    my ($listLength, $listDepth, $sectionLength, $sectionDepth);
    my ($indentLength, $indentDepth);
    my ($line, $listType);

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

    $currentNode = $this->root->insertChild('type' => 'section');

    foreach $line (split(/\n/, $wikiContent)) { # Process lines one-at-a-time

	# Process lists
	if ($line =~ /^($aggregateListRegExp)$/) {
	    foreach $listType (keys(%listMap)) {
		if ($line =~ /^$listMap{$listType}$/) {
		    $currentNode = &_terminateParagraph($currentNode,
							\$nodeContent);
		    while ($indentDepth > 0) {
			$currentNode = $currentNode->parent;
			$indentDepth--;
		    }
		    $currentNode = &_parseList($listType, length $1,
					       \$listDepth,
					       $currentNode, $2, $3);
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
            $currentNode = $currentNode->insertChild('type'=>'p',
                                                     'content'=>$nodeContent);
            $currentNode = $currentNode->parent;
            undef $nodeContent;
            $isStart = 0 if ($isStart);
        }
        elsif ($line =~ /^(\=+)\s+(\S.+)\s+\=+/) {  # header/section
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
            $currentNode->insertChild('type'=>'h', 'content'=>$nodeContent);
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
}

sub _terminateParagraph {
    my ($currentNode, $nodeContentRef) = @_;

    if (($currentNode->type eq 'p') || ($currentNode->type eq 'pre')) {
        chomp ${$nodeContentRef};
        $currentNode->content(${$nodeContentRef});
        undef ${$nodeContentRef};
        return $currentNode->parent;
    }
    return $currentNode;
}

sub _parseList {
    my ($listType, $listLength, $listDepthRef,
        $currentNode, @nodeContents) = @_;

    while ($listLength > ${$listDepthRef}) {
        $currentNode = $currentNode->insertChild('type'=>$listType);
        ${$listDepthRef}++;
    }
    while ($listLength < ${$listDepthRef}) {
        $currentNode = $currentNode->parent;
        ${$listDepthRef}--;
    }
    if ($listType eq 'dl') {
        $currentNode = $currentNode->insertChild('type'=>'dt',
                                                 'content'=>$nodeContents[0]);
        $currentNode = $currentNode->parent;
        $currentNode = $currentNode->insertChild('type'=>'dd',
                                                 'content'=>$nodeContents[1]);
        return $currentNode->parent;
    }
    else {
        $currentNode = $currentNode->insertChild('type'=>'li',
                                                 'content'=>$nodeContents[0]);
        return $currentNode->parent;
    }
    return $currentNode;
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
}

sub traverseTree {
    my $this = shift;
    my $functionRef = shift;

    &_traverse($this->{'rootNode'}->children, 0, $functionRef);
}

sub _traverse {
    my ($nodeListRef, $indentLevel, $functionRef) = @_;

    foreach my $node (@{$nodeListRef}) {
        &{$functionRef}($node, $indentLevel);
        my $childrenRef = $node->children;
        &_traverse($childrenRef, $indentLevel + 1, $functionRef)
            if ($childrenRef);
    }
}

1;
