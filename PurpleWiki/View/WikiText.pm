package PurpleWiki::View::WikiText;

use PurpleWiki::Tree;

# globals

my $sectionDepth = 0;
my $indentDepth = 0;
my @listStack;
my $lastInlineProcessed;

my %structuralActionMap = (
    'section' => {
        'pre' => sub { $sectionDepth++; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { $sectionDepth--; },
    },
    'indent' => {
        'pre' => sub { $indentDepth++; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { $indentDepth--;
                        print "\n" if ($indentDepth == 0); },
    },
    'ul' => {
        'pre' => sub { push @listStack, 'ul'; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { pop @listStack;
                        print "\n" if (scalar @listStack == 0); },
    },
    'ol' => {
        'pre' => sub { push @listStack, 'ol'; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { pop @listStack;
                        print "\n" if (scalar @listStack == 0); },
    },
    'dl' => {
        'pre' => sub { push @listStack, 'dl'; },
        'mid' => \&_traverseStructuralWithChild,
        'post' => sub { pop @listStack;
                        print "\n" if (scalar @listStack == 0); },
    },
    'h' => {
        'pre' => sub { for (my $i = 0; $i < $sectionDepth; $i++) {
                           print '=';
                       }
                       print ' '; },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        &_printNid($nid);
                        print ' ';
                        for (my $i = 0; $i < $sectionDepth; $i++) {
                            print '=';
                        }
                        print "\n\n"; },
        },
    'p' => {
        'pre' => sub { for (my $i = 0; $i < $indentDepth; $i++) {
                           print ':';
                       } },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        &_printNid($nid);
                        print "\n";
                        print "\n" if ($indentDepth == 0); },
    },
    'li' => {
        'pre' => sub { for (my $i = 0; $i < scalar @listStack; $i++) {
                           if ($listStack[$#listStack] eq 'ul') {
                               print '*';
                           }
                           else {
                               print '#';
                           }
                       }
                       print ' '; },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        &_printNid($nid);
                        print "\n"; },
    },
    'dt' => {
        'pre' => sub { for (my $i = 0; $i < scalar @listStack; $i++) {
                           print ';';
                       } },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        &_printNid($nid); },
    },
    'dd' => {
        'pre' => sub { print ':'; },
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        &_printNid($nid);
                        print "\n"; },
    },
    'pre' => {
        'pre' => sub {},
        'mid' => \&_traverseInlineIfContent,
        'post' => sub { my $nid = shift;
                        &_printNid($nid);
                        print "\n\n"; },
    },
    );

my %inlineActionMap = (
    'b' => {
        'pre' => sub { print "'''"; },
        'mid' => \&_traverseInlineWithData,
        'post' => sub { print "'''";
                        $lastInlineProcessed = 'b'; },
    },
    'i' => {
        'pre' => sub { print "''"; },
        'mid' => \&_traverseInlineWithData,
        'post' => sub { print "''";
                        $lastInlineProcessed = 'i'; },
    },
    'tt' => {
        'pre' => sub { print '<tt>'; },
        'mid' => \&_traverseInlineWithData,
        'post' => sub { print '</tt>';
                        $lastInlineProcessed = 'tt'; },
    },
    'text' => {
        'pre' => sub { my $node = shift;
                       if ($lastInlineProcessed eq 'wikiword' &&
                           $node->content =~ /^\w/) {
                           print '""';
                       } },
        'mid' => \&_printInlineData,
        'post' => sub { $lastInlineProcessed = 'text'; }
    },
    'nowiki' => {
        'pre' => sub { print '<nowiki>'; },
        'mid' => \&_printInlineData,
        'post' => sub { print '</nowiki>';
                        $lastInlineProcessed = 'nowiki'; }
    }
    );

sub view {
    my ($wikiTree, %params) = @_;

    &_printHeader($wikiTree->lastNid);
    &_traverseStructural($wikiTree->root->children, 0);
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            if (defined($structuralActionMap{$node->type})) {
                &{$structuralActionMap{$node->type}{'pre'}};
                &{$structuralActionMap{$node->type}{'mid'}}($node,
                                                            $indentLevel);
                &{$structuralActionMap{$node->type}{'post'}}($node->id);
            } 
        }
    }
}

sub _traverseInlineIfContent {
    my $structuralNode = shift;
    my $indentLevel = shift;
    if ($structuralNode->content) {
        _traverseInline($structuralNode->content, $indentLevel);
    }
}

sub _traverseInlineWithData {
    my $inlineNode = shift;
    my $indentLevel = shift;
    _traverseInline($inlineNode->children, $indentLevel);
}

sub _printInlineData {
    my $inlineNode = shift;
    print $inlineNode->content;
}

sub _traverseStructuralWithChild {
    my $structuralNode = shift;
    my $indentLevel = shift;
    _traverseStructural($structuralNode->children, $indentLevel + 1);
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;

    my $rxWikiWord = '[A-Z]+[a-z]+[A-Z]\w*';
    my $rxSubpage = '[A-Z]+[a-z]+\w*';
    my $rxQuoteDelim = '(?:"")?';

    foreach my $inlineNode (@{$nodeListRef}) {
        if ($inlineNode->type eq 'link') {
            print '[' . $inlineNode->href . ' ' . $inlineNode->content . ']';
            $lastInlineProcessed = 'link';
        }
        elsif ($inlineNode->type eq 'wikiword') {
            print $inlineNode->content;
            $lastInlineProcessed = 'wikiword';
        }
        elsif ($inlineNode->type eq 'url') {
            print $inlineNode->content;
            $lastInlineProcessed = 'url';
        }
        elsif ($inlineNode->type eq 'freelink') {
            print '[[' . $inlineNode->content . ']]';
            $lastInlineProcessed = 'freelink';
        }
        elsif (defined($inlineActionMap{$inlineNode->type})) {
            &{$inlineActionMap{$inlineNode->type}{'pre'}}($inlineNode);
            &{$inlineActionMap{$inlineNode->type}{'mid'}}($inlineNode,
                                                          $indentLevel);
            &{$inlineActionMap{$inlineNode->type}{'post'}};
        }
    }
}

sub _headerLevel {
    my $headerLevel = scalar @sectionState + 1;
    $headerLevel = 6 if ($headerLevel > 6);
    return $headerLevel;
}

sub _printNid {
    my $nid = shift;
    print " [nid $nid]";
}

sub _printHeader {
    my $lastNid = shift;

    print "[lastnid $lastNid]\n" if ($lastNid);
}


1;
