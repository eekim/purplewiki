package PurpleWiki::View::WikiHTML;

use PurpleWiki::Page;
use PurpleWiki::Tree;

# globals

my @sectionState;

my %structuralActionMap = (
               'section' => {
                   'pre' => sub { push @sectionState, 'section'; return; },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { pop @sectionState; return; },
               },
               'indent' => {
                   'pre' => sub { return "<div class=\"indent\">\n"},
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { return "</div>"},
               },
               'ul' => {
                   'pre' => sub { return "<ul>\n" },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { return "</ul>" },
               },
               'ol' => {
                   'pre' => sub { return "<ol>\n" },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { return "</ol>" },
               },
               'dl' => {
                   'pre' => sub { return "<dl>\n" },
                   'mid' => \&_traverseStructuralWithChild,
                   'post' => sub { return "</dl>"},
               },
               'h' => {
                   'pre' => sub { my $nid = shift;
                                  return '<h' . &_headerLevel . '>' .
                                      &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   return &_printNid($nid) .
                                       '</h' . &_headerLevel . '>'; }
               },
               'p' => {
                   'pre' => sub { my $nid = shift;
                                  return '<p>' .
                                      &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   return &_printNid($nid) .
                                       '</p>'; },
               },
               'li' => {
                   'pre' => sub { my $nid = shift;
                                  return '<li>' .
                                      &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   return &_printNid($nid) .
                                       '</li>'; },
               },
               'dd' => {
                   'pre' => sub { my $nid = shift;
                                  return '<dd>' .
                                      &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   return &_printNid($nid) .
                                       '</dd>'; },
               },
               'dt' => {
                   'pre' => sub { my $nid = shift;
                                  return '<dt>' .
                                      &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   return &_printNid($nid) .
                                       '</dt>'; },
               },
               'pre' => {
                   'pre' => sub { my $nid = shift;
                                  return '<pre>' .
                                      &_printAnchor($nid); },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { my $nid = shift;
                                   return &_printNid($nid) .
                                       '</pre>'; },
               },
               );

my %inlineActionMap = (
             'b' => {
                 'pre' => sub { return '<b>' },
                 'mid' => \&_traverseInlineWithData,
                 'post' => sub {return '</b>' },
             },
             'i' => {
                 'pre' => sub { return '<i>' },
                 'mid' => \&_traverseInlineWithData,
                 'post' => sub { return '</i>' },
             },
             'tt' => {
                 'pre' => sub { return '<tt>' },
                 'mid' => \&_traverseInlineWithData,
                 'post' => sub { return '</tt>' },
             },
             'text' => {
                 'pre' => sub { return },
                 'mid' => \&_printInlineData,
                 'post' => sub { return }
             },
             'nowiki' => {
                 'pre' => sub { return },
                 'mid' => \&_printInlineData,
                 'post' => sub { return }
             }
             );

sub view {
    my ($wikiTree, %params) = @_;

    return &_traverseStructural($wikiTree->root->children, 0);
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;
    my $outputString;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            if (defined($structuralActionMap{$node->type})) {
                $outputString .=
                    &{$structuralActionMap{$node->type}{'pre'}}($node->id);
                $outputString .=
                    &{$structuralActionMap{$node->type}{'mid'}}($node,
                                                                $indentLevel);
                $outputString .=
                    &{$structuralActionMap{$node->type}{'post'}}($node->id);
            } 
            $outputString .= &_terminateLine unless ($node->type eq 'section');
        }
    }
    return $outputString;
}

sub _terminateLine {
    return "\n";
}

sub _traverseInlineIfContent {
    my $structuralNode = shift;
    my $indentLevel = shift;
    if ($structuralNode->content) {
        return _traverseInline($structuralNode->content, $indentLevel);
    }
}

sub _traverseInlineWithData {
    my $inlineNode = shift;
    my $indentLevel = shift;
    return _traverseInline($inlineNode->children, $indentLevel);
}

sub _printInlineData {
    my $inlineNode = shift;
    return &_quoteHtml($inlineNode->content);
}

sub _traverseStructuralWithChild {
    my $structuralNode = shift;
    my $indentLevel = shift;
    return _traverseStructural($structuralNode->children, $indentLevel + 1);
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;
    my $outputString;

    foreach my $inlineNode (@{$nodeListRef}) {
        if ($inlineNode->type eq 'link' || $inlineNode->type eq 'url') {
            $outputString .= '<a href="' . $inlineNode->href . '">';
            $outputString .= &_quoteHtml($inlineNode->content);
            $outputString .= '</a>';
        }
        elsif ($inlineNode->type eq 'wikiword' || $inlineNode->type eq 'freelink') {
            my $pageName = $inlineNode->content;
            $pageName =~ s/\#(\d+)$//;
            my $pageNid = $1;
            if ($inlineNode->content =~ /:/) {
                $outputString .= '<a href="' . &PurpleWiki::Page::getInterWikiLink($pageName);

                $outputString .= "#nid$pageNid" if ($pageNid);
                $outputString .= '">' . $inlineNode->content . '</a>';
            }
            elsif (&PurpleWiki::Page::exists($pageName)) {
                if ($inlineNode->type eq 'freelink') {
                    $outputString .= '<a href="' . &PurpleWiki::Page::getFreeLink($inlineNode->content) .
                        '">';
                }
                else {
                    $outputString .= '<a href="' . &PurpleWiki::Page::getWikiWordLink($pageName);
                    $outputString .= "#nid$pageNid" if ($pageNid);
                    $outputString .= '">';
                }
                $outputString .= $inlineNode->content . '</a>';
            }
            else {
                $outputString .= $inlineNode->content;
                if ($inlineNode->type eq 'freelink') {
                    $outputString .= '<a href="' . &PurpleWiki::Page::getFreeLink($inlineNode->content) .
                        '">';
                }
                else {
                    $outputString .= '<a href="' . &PurpleWiki::Page::getWikiWordLink($inlineNode->content) .
                        '">';
                }
                $outputString .= '?</a>';
            }
        }
        elsif (defined($inlineActionMap{$inlineNode->type})) {
            $outputString .= &{$inlineActionMap{$inlineNode->type}{'pre'}};
            $outputString .= &{$inlineActionMap{$inlineNode->type}{'mid'}}($inlineNode,
                                                          $indentLevel);
            $outputString .= &{$inlineActionMap{$inlineNode->type}{'post'}};
        }
    }
    return $outputString;
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

    return '<a name="nid0' . $nid . '" id="nid0' . $nid . '"></a>' if ($nid);
}

sub _printNid {
    my $nid = shift;

    if ($nid) {
        my $outputString = ' &nbsp;&nbsp; <a class="nid" href="#nid0' . $nid . '">';
        $outputString .= "(0$nid)</a>";
        return $outputString;
    }
}


1;
