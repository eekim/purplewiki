package PurpleWiki::View::XHTML;

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
                   'pre' => sub
                   { print "<div class=\"indent\">\n"},
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
                   'pre' => sub
                   { print '<h' . &_headerLevel . '>' },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub
                   { print '</h' . &_headerLevel . '>' },
               },
               'p' => {
                   'pre' => sub { print '<p>' },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { print '</p>' },
               },
               'li' => {
                   'pre' => sub { print '<li>' },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { print '</li>' },
               },
               'dd' => {
                   'pre' => sub { print '<dd>' },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { print '</dd>' },
               },
               'dt' => {
                   'pre' => sub { print '<dt>' },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { print '</dt>' },
               },
               'pre' => {
                   'pre' => sub { print '<pre>' },
                   'mid' => \&_traverseInlineIfContent,
                   'post' => sub { print '</pre>' },
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

    &_printHeader($wikiTree->title);
    &_traverseStructural($wikiTree->root->children, 0);
    &_printFooter;
}

sub _traverseStructural {
    my ($nodeListRef, $indentLevel) = @_;

    if ($nodeListRef) {
        foreach my $node (@{$nodeListRef}) {
            if (defined($structuralActionMap{$node->type})) {
                &{$structuralActionMap{$node->type}{'pre'}};
                &{$structuralActionMap{$node->type}{'mid'}}($node,
                                                            $indentLevel);
                &{$structuralActionMap{$node->type}{'post'}};
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
        if ($inlineNode->type eq 'link') {
            print '<a href="' . $inlineNode->href . '">';
            print &_quoteHtml($inlineNode->content);
            print '</a>';
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

sub _printHeader {
    my $title = shift;

    print <<EOM;
<html>
  <head>
    <title>$title</title>
    <style type="text/css">
    div.indent {
        margin-left: 3em;
    }
    </style>
  </head>
  <body>
    <h1>$title</h1>
EOM
}

sub _printFooter {
    print <<EOM;
  </body>
</html>
EOM
}


1;
