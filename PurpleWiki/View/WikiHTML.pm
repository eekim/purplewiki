package PurpleWiki::View::WikiHTML;

use PurpleWiki::Page;
use PurpleWiki::Tree;

# globals

my @sectionState;

my %structuralActionMap = (
               'section' => {
                   'pre' => sub { push @sectionState, 'section' },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { pop @sectionState },
               },
               'indent' => {
                   'pre' => sub { print "<div class=\"indent\">\n"},
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { print "</div>"},
               },
               'ul' => {
                   'pre' => sub { print "<ul>\n" },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { print "</ul>" },
               },
               'ol' => {
                   'pre' => sub { print "<ol>\n" },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { print "</ol>" },
               },
               'dl' => {
                   'pre' => sub { print "<dl>\n" },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { print "</dl>"},
               },
               'h' => {
                   'pre' => sub { my $nid = shift;
                                  print '<h' . &_headerLevel . '>';
                                  &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   &_printNid($nid);
                                   print '</h' . &_headerLevel . '>' },
               },
               'p' => {
                   'pre' => sub { my $nid = shift;
                                  print '<p>';
                                  &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   &_printNid($nid);
                                   print '</p>'; },
               },
               'li' => {
                   'pre' => sub { my $nid = shift;
                                  print '<li>';
                                  &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   &_printNid($nid);
                                   print '</li>'; },
               },
               'dd' => {
                   'pre' => sub { my $nid = shift;
                                  print '<dd>';
                                  &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   &_printNid($nid);
                                   print '</dd>'; },
               },
               'dt' => {
                   'pre' => sub { my $nid = shift;
                                  print '<dt>';
                                  &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   &_printNid($nid);
                                   print '</dt>'; },
               },
               'pre' => {
                   'pre' => sub { my $nid = shift;
                                  print '<pre>';
                                  &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   &_printNid($nid);
                                   print '</pre>'; },
               },
               );

my %inlineActionMap = (
             'b' => {
                 'pre' => sub { print '<b>' },
                 'mid' => \&_traverseInlineWithData,
                 'post' => sub {print '</b>' },
             },
             'i' => {
                 'pre' => sub { print '<i>' },
                 'mid' => \&_traverseInlineWithData,
                 'post' => sub { print '</i>' },
             },
             'tt' => {
                 'pre' => sub { print '<tt>' },
                 'mid' => \&_traverseInlineWithData,
                 'post' => sub { print '</tt>' },
             },
             'text' => {
                 'pre' => sub {},
                 'mid' => \&_printInlineData,
                 'post' => sub {}
             },
             'nowiki' => {
                 'pre' => sub {},
                 'mid' => \&_printInlineData,
                 'post' => sub {}
             }
             );

sub view {
    my ($wikiTree, %params) = @_;

    &_printHeader($wikiTree->title, $wikiTree->lastNid);
    &_traverseStructural($wikiTree->root->children, 0);
    &_printFooter;
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            if (defined($structuralActionMap{$node->type})) {
                &{$structuralActionMap{$node->type}{'pre'}}($node->id);
                &{$structuralActionMap{$node->type}{'mid'}}($node,
                                                            $indentLevel);
                &{$structuralActionMap{$node->type}{'post'}}($node->id);
            } 
            &_terminateLine unless ($node->type eq 'section');
        }
    }
}

sub _terminateLine {
    print "\n";
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
    print &_quoteHtml($inlineNode->content);
}

sub _traverseStructuralWithChild {
    my $structuralNode = shift;
    my $indentLevel = shift;
    _traverseStructural($structuralNode->children, $indentLevel + 1);
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;

    foreach my $inlineNode (@{$nodeListRef}) {
        if ($inlineNode->type eq 'link' || $inlineNode->type eq 'url') {
            print '<a href="' . $inlineNode->href . '">';
            print &_quoteHtml($inlineNode->content);
            print '</a>';
        }
        elsif ($inlineNode->type eq 'wikiword' || $inlineNode->type eq 'freelink') {
            my $pageName = $inlineNode->content;
            $pageName =~ s/\#(\d+)$//;
            my $pageNid = $1;
            if ($inlineNode->content =~ /:/) {
                print '<a href="' . &PurpleWiki::Page::getInterWikiLink($pageName);

                print "#nid$pageNid" if ($pageNid);
                print '">' . $inlineNode->content . '</a>';
            }
            elsif (&PurpleWiki::Page::exists($pageName)) {
                if ($inlineNode->type eq 'freelink') {
                    print '<a href="' . &PurpleWiki::Page::getFreeLink($inlineNode->content) .
                        '">';
                }
                else {
                    print '<a href="' . &PurpleWiki::Page::getWikiWordLink($pageName);
                    print "#nid$pageNid" if ($pageNid);
                    print '">';
                }
                print $inlineNode->content . '</a>';
            }
            else {
                print $inlineNode->content;
                if ($inlineNode->type eq 'freelink') {
                    print '<a href="' . &PurpleWiki::Page::getFreeLink($inlineNode->content) .
                        '">';
                }
                else {
                    print '<a href="' . &PurpleWiki::Page::getWikiWordLink($inlineNode->content) .
                        '">';
                }
                print '?</a>';
            }
        }
        elsif (defined($inlineActionMap{$inlineNode->type})) {
            &{$inlineActionMap{$inlineNode->type}{'pre'}};
            &{$inlineActionMap{$inlineNode->type}{'mid'}}($inlineNode,
                                                          $indentLevel);
            &{$inlineActionMap{$inlineNode->type}{'post'}};
        }
    }
}

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

sub _printAnchor {
    my $nid = shift;

    print '<a name="nid0' . $nid . '" id="nid0' . $nid . '"></a>' if ($nid);
}

sub _printNid {
    my $nid = shift;

    if ($nid) {
        print ' &nbsp;&nbsp; <a class="nid" href="#nid0' . $nid . '">';
        print "(0$nid)</a>";
    }
}

sub _printHeader {
}

sub _printFooter {
}


1;
