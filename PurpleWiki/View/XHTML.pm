package PurpleWiki::View::XHTML;

use PurpleWiki::Tree;

# globals

my @sectionState;

# functions

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
            if ($node->type eq 'section') {
                push @sectionState, 'section';
                &_traverseStructural($node->children, $indentLevel + 1);
                pop @sectionState;
            }
            elsif ($node->type eq 'indent') {
                print "<div class=\"indent\">\n";
                &_traverseStructural($node->children, $indentLevel + 1);
                print '</div>';
            }
            elsif ($node->type eq 'ul') {
                print "<ul>\n";
                &_traverseStructural($node->children, $indentLevel + 1);
                print '</ul>';
            }
            elsif ($node->type eq 'ol') {
                print "<ol>\n";
                &_traverseStructural($node->children, $indentLevel + 1);
                print '</ol>';
            }
            elsif ($node->type eq 'dl') {
                print "<dl>\n";
                &_traverseStructural($node->children, $indentLevel + 1);
                print '</dl>';
            }
            elsif ($node->type eq 'h') {
                print '<h' . &_headerLevel . '>';
                &_traverseInline($node->content->data, $indentLevel)
                    if ($node->content);
                print '</h' . &_headerLevel . '>';
            }
            elsif ($node->type eq 'p') {
                print '<p>';
                &_traverseInline($node->content->data, $indentLevel)
                    if ($node->content);
                print '</p>';
            }
            elsif ($node->type eq 'li') {
                print '<li>';
                &_traverseInline($node->content->data, $indentLevel)
                    if ($node->content);
                print '</li>';
            }
            elsif ($node->type eq 'dd') {
                print '<dd>';
                &_traverseInline($node->content->data, $indentLevel)
                    if ($node->content);
                print '</dd>';
            }
            elsif ($node->type eq 'dt') {
                print '<dt>';
                &_traverseInline($node->content->data, $indentLevel)
                    if ($node->content);
                print '</dt>';
            }
            elsif ($node->type eq 'pre') {
                print '<pre>';
                &_traverseInline($node->content->data, $indentLevel)
                    if ($node->content);
                print '</pre>';
            }
            print "\n" if ($node->type ne 'section');
        }
    }
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;

    foreach my $node (@{$nodeListRef}) {
        if (ref $node) {
            if ($node->type eq 'b') {
                print '<b>';
                &_traverseInline($node->data, $indentLevel);
                print '</b>';
            }
            elsif ($node->type eq 'i') {
                print '<i>';
                &_traverseInline($node->data, $indentLevel);
                print '</i>';
            }
            elsif ($node->type eq 'tt') {
                print '<tt>';
                &_traverseInline($node->data, $indentLevel);
                print '</tt>';
            }
            elsif ($node->type eq 'link') {
                print '<a href="' . $node->href . '">';
                print &_quoteHtml($node->data->[0]);
                print '</a>';
            }
            elsif ($node->type eq 'nowiki') {
                print &_quoteHtml($node->data->[0]);
            }
        }
        else {
            print &_quoteHtml($node);
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
