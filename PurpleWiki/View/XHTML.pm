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
    my $node = shift;
    my $indentLevel = shift;
    if ($node->content) {
	_traverseInline($node->content->data, $indentLevel);
    }
}

sub _traverseInlineWithData {
    my $node = shift;
    my $indentLevel = shift;
    _traverseInline($node->data, $indentLevel);
}

sub _traverseStructuralWithChild {
    my $node = shift;
    my $indentLevel = shift;
    _traverseStructural($node->children, $indentLevel + 1);
}

sub _traverseInline {
    my ($nodeListRef, $indentLevel) = @_;

    foreach my $node (@{$nodeListRef}) {
        if (ref $node) {
	    if ($node->type eq 'nowiki') {
                print &_quoteHtml($node->data->[0]);
	    }
            elsif ($node->type eq 'link') {
                print '<a href="' . $node->href . '">';
                print &_quoteHtml($node->data->[0]);
                print '</a>';
            }
	    elsif (defined($inlineActionMap{$node->type})) {
		&{$inlineActionMap{$node->type}{'pre'}};
		&{$inlineActionMap{$node->type}{'mid'}}($node,
							$indentLevel);
		&{$inlineActionMap{$node->type}{'post'}};
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
