package PurpleWiki::View::Debug;

use PurpleWiki::Tree;

# functions

sub view {
    my ($wikiTree, %params) = @_;

    print 'title:' . $wikiTree->title . "\n";
    &_traverseStructural($wikiTree->root->children, 0);
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            print &_spaces($indentLevel, 0) . $node->type . ':';
            if ( ($node->type eq 'section') || ($node->type eq 'indent') ||
                 ($node->type eq 'ul') || ($node->type eq 'ol') ||
                 ($node->type eq 'dl') ) {
                print "\n";
            }
            if ($node->content) {
                foreach my $inlineNode (@{$node->content}) {
                    print uc($inlineNode->type) . ':' if ($inlineNode->type ne 'text');
                    if ($inlineNode->children) {
                        &_traverseInline($inlineNode->children, $indentLevel);
                    }
                    else {
                        print $inlineNode->content . "\n";
                    }
                }
            }
            &_traverseStructural($node->children, $indentLevel + 1);
        }
    }
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;

    foreach my $node (@{$nodeListRef}) {
        if (defined $node->content) {
            print $node->content . "\n";
        }
        else {
            print uc($node->type) . ':';
            &_traverseInline($node->children, $indentLevel);
        }
    }
}

sub _spaces {
    my $indentLevel = shift;

    for (my $i = 0; $i < $indentLevel * 2; $i++) {
        print ' ';
    }
}


1;
