# parser.t

use strict;
use Test;

#BEGIN { plan tests => 258 };
BEGIN { plan tests => 249 };

use IO::File;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Config;
my $configfile = 't';

sub readFile {
    my $fileName = shift;
    my $fileContent;

    my $fh = new IO::File $fileName;
    if (defined $fh) {
        local ($/);
        $fileContent = <$fh>;
        $fh->close;
        return $fileContent;
    }
    else {
        return;
    }
}

#########################

### tree_test01.txt

my $config = new PurpleWiki::Config($configfile);
my $wikiContent = &readFile('t/tree_test01.txt');
my $wikiParser = PurpleWiki::Parser::WikiText->new;
my $wiki = $wikiParser->parse($wikiContent, config => $config);
$wiki->title('Tree Test 1');

# Document.  (Tests 1-4)

ok($wiki->title eq 'Tree Test 1');
ok(ref $wiki->root eq 'PurpleWiki::StructuralNode');
ok($wiki->root->type eq 'document');
ok(scalar @{$wiki->root->children} == 2);

# Basic Wiki Test (Tests 5-9)

ok($wiki->root->children->[0]->type eq 'section');
ok(scalar @{$wiki->root->children->[0]->children} == 2);
ok($wiki->root->children->[0]->children->[0]->type eq 'h');
ok($wiki->root->children->[0]->children->[0]->content->[0]->type
    eq 'text');
ok($wiki->root->children->[0]->children->[0]->content->[0]->content 
    eq 'Basic Wiki Test');

# Introduction (Tests 10-37)

ok($wiki->root->children->[0]->children->[1]->type eq 'section');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children}
    == 13);
ok($wiki->root->children->[0]->children->[1]->children->[0]->type
    eq 'h');
ok($wiki->root->children->[0]->children->[1]->children->[0]->content->
    [0]->content eq 'Introduction');
ok($wiki->root->children->[0]->children->[1]->children->[1]->type
    eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[1]->content->
    [0]->content eq
    "This is a bare-bones, error-free example of a textual Wiki page.  The\nquestion is, will this parse correctly?");
ok($wiki->root->children->[0]->children->[1]->children->[2]->type
    eq 'pre');
ok($wiki->root->children->[0]->children->[1]->children->[2]->content->
    [0]->content eq "  Only time will tell.\n  And tell it will.");
ok($wiki->root->children->[0]->children->[1]->children->[3]->type
    eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[3]->content->
    [0]->content eq "This is a paragraph.");
ok($wiki->root->children->[0]->children->[1]->children->[4]->type
    eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[4]->content->
    [0]->content eq "This is another paragraph.");
ok($wiki->root->children->[0]->children->[1]->children->[5]->type
    eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[5]->content->
    [0]->content eq "How about mixed paragraphs and preformatting?");
ok($wiki->root->children->[0]->children->[1]->children->[6]->type
    eq 'pre');
ok($wiki->root->children->[0]->children->[1]->children->[6]->content->
    [0]->content eq "   This should be preformatted.\n But is it?");
ok($wiki->root->children->[0]->children->[1]->children->[7]->type
    eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[7]->content->
    [0]->content eq "You should know by now.");
ok($wiki->root->children->[0]->children->[1]->children->[8]->type
    eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[8]->content->
    [0]->content eq
    "What about <strong>HTML</strong> in paragraphs?  You should see the tags.");
ok($wiki->root->children->[0]->children->[1]->children->[9]->type
    eq 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->[9]->
    content} == 3);
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [0]->content eq "Does the nowiki tag work?  ");
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [1]->type eq 'nowiki');
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [1]->content eq "Well, that depends.  Do you see\n'''quotes''' or not?");
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [2]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [2]->content eq "  If so, then be happy!");

# Unordered list.  (Tests 38-60)

ok($wiki->root->children->[0]->children->[1]->children->[10]->type
    eq 'section');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [0]->type eq 'h');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [0]->content->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [0]->content->[0]->content eq 'Lists');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->type eq 'ul');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [10]->children->[1]->children} == 3);
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[0]->content->[0]->content eq
    'Lists are an excellent test.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[1]->content->[0]->content eq
    'Yessirreebob.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->type eq 'ul');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [10]->children->[1]->children->[2]->children} == 5);
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[0]->content->[0]->content eq
    'This is a sublist.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[1]->content->[0]->content eq
    'This is item two of the sublist.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[2]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[2]->content->[0]->content eq
    'Item three of the sublist should be one sentence.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[3]->type eq 'ul');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[3]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[3]->children->[0]->content->[0]->content
    eq 'This is a subsublist.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[4]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->children->[2]->children->[4]->content->[0]->content eq
    'This is item three of the sublist.');

# Ordered list.  (Tests 61-74)

ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->type eq 'ol');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [10]->children->[2]->children} == 3);
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[0]->content->[0]->content eq
    'How about numbered lists?');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[1]->content->[0]->content eq
    'What about them?');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->type eq 'ol');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->children->[0]->content->[0]->content eq
    'Will it parse correctly?');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->children->[1]->type eq 'ol');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->children->[1]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->children->[1]->children->[0]->content->[0]->
    content eq 'I sure hope so.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->children->[2]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [2]->children->[2]->children->[2]->content->[0]->content eq
    'Only one way to find out.');

# Mixed unordered and ordered.  (Tests 75-87)

ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->type eq 'ul');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [10]->children->[3]->children} == 4);
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[0]->content->[0]->content eq
    'Mixed list.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[1]->content->[0]->content eq
    'Second item.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[2]->type eq 'ol');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[2]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[2]->children->[0]->content->[0]->content eq
    'Now do numbered list.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[2]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[2]->children->[1]->content->[0]->content eq
    'Again.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[3]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [3]->children->[3]->content->[0]->content eq
    'Backed to unordered list.');

# Mixed ordered and unordered.  (Tests 88-100)

ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->type eq 'ol');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [10]->children->[4]->children} == 4);
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[0]->content->[0]->content eq
    'Ordered list.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[1]->content->[0]->content eq
    'Number two.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[2]->type eq 'ul');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[2]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[2]->children->[0]->content->[0]->content eq
    'Now do unordered.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[2]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[2]->children->[1]->content->[0]->content eq
    'Again.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[3]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [4]->children->[3]->content->[0]->content eq
    'Number three.');

# Definition list.  (Tests 100-115)

ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->type eq 'dl');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [10]->children->[5]->children} == 5);
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[0]->type eq 'dt');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[0]->content->[0]->content eq
    'definition lists');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[1]->type eq 'dd');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[1]->content->[0]->content eq
    'Will definition lists parse correctly?');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[2]->type eq 'dt');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[2]->content->[0]->content eq
    'testing');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[3]->type eq 'dd');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[3]->content->[0]->content eq
    'This is a test.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[4]->type eq 'dl');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[4]->children->[0]->type eq 'dt');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[4]->children->[0]->content->[0]->content eq
    'indented definition');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[4]->children->[1]->type eq 'dd');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [5]->children->[4]->children->[1]->content->[0]->content eq
    'This should be indented again.');

# The rest of lists.  (Tests 116-124)

ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [6]->type eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [6]->content->[0]->content eq 'Okay, some mixed paragraphs and lists.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [7]->type eq 'ul');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [7]->children->[0]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [7]->children->[0]->content->[0]->content eq 'This ought to work.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [7]->children->[1]->type eq 'li');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [7]->children->[1]->content->[0]->content eq 'But I just want to make sure.');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [8]->type eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [8]->content->[0]->content eq 'Did it work?');

# Quote formatting.  (Tests 125-146)

ok($wiki->root->children->[0]->children->[1]->children->[11]->type
    eq 'section');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [0]->type eq 'h');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [0]->content->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [0]->content->[0]->content eq 'Formatting');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->type eq 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [11]->children->[1]->content} == 7);
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[0]->content eq 'This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[1]->type eq 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[1]->children->[0]->content eq 'italics');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[2]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[2]->content eq '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[3]->type eq 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[3]->children->[0]->content eq 'bold');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[4]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[4]->content eq '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->type eq 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->children->[0]->type eq 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->children->[0]->children->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->children->[0]->children->[0]->content eq
    "bold and\nitalic");
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[6]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[6]->content eq '.');

# HTML formatting.  (Tests 147-179)

ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->type eq 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [11]->children->[2]->content} == 12);
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[0]->type eq 'wikiword');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[0]->content eq 'UseModWiki');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[1]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[1]->content eq ' also supports HTML bold and italic tags.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[2]->type eq 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[2]->children->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[2]->children->[0]->content eq 'italics');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[3]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[3]->content eq '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[4]->type eq 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[4]->children->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[4]->children->[0]->content eq 'bold');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[5]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[5]->content eq '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->type eq 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->children->[0]->type eq 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->children->[0]->children->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->children->[0]->children->[0]->content eq
    'bold and italic');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[7]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[7]->content eq '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->type eq 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->children->[0]->type eq 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->children->[0]->children->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->children->[0]->children->[0]->content eq
    'italic and bold');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[9]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[9]->content eq '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[10]->type eq 'tt');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[10]->children->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[10]->children->[0]->content eq 'monospace');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[11]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[11]->content eq '.');

# Indented text.  (Tests 180-194)

ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->type eq 'indent');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [11]->children->[3]->children} == 2);
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[0]->type eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[0]->content->[0]->content eq 'Indented text.');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->type eq 'indent');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->children->[0]->type eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->children->[0]->content->[0]->content eq
    'Double indented text.');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->children->[1]->type eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->children->[1]->content->[0]->content eq
    'Another paragraph of double indented text.');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->children->[2]->type eq 'indent');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->children->[2]->children->[0]->type eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [3]->children->[1]->children->[2]->children->[0]->content->
    [0]->content eq 'Triple indented text.');

ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [4]->type eq 'p');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [4]->content->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [4]->content->[0]->content eq 'Text after indentation.');

# Links.  (Tests 195-250)

ok($wiki->root->children->[0]->children->[1]->children->[12]->type
    eq 'section');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [0]->type eq 'h');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [0]->content->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [0]->content->[0]->content eq 'Links');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->type eq 'p');
#ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
#    [12]->children->[1]->content} == 17);
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[0]->content eq 'How about a paragraph with some ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[1]->type eq 'wikiword');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[1]->content eq 'WikiWords');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[2]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[2]->content eq '?  How about a ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[3]->type eq 'freelink');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[3]->content eq "double\nbracketed free link");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[4]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[4]->content eq '?  How about a link to ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[5]->type eq 'link');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[5]->href eq 'http://www.eekim.com/');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[5]->content eq "my\nhomepage");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[6]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[6]->content eq '.  What about the URL itself, like ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[7]->type eq 'url');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[7]->href eq 'http://www.eekim.com/');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[7]->content eq "http://www.eekim.com/");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[8]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[8]->content eq ".\nHow about not linking a ");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[9]->type eq 'nowiki');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[9]->content eq "WikiWikiWord");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[10]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[10]->content eq ". How about a\n");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[11]->type eq 'wikiword');
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[11]->content eq 'UseMod');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[12]->type eq 'text');
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[12]->content eq ":");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[13]->type eq 'wikiword');
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[13]->content eq 'InterWiki');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[14]->type eq 'text');
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[14]->content eq " link?  Finally, how about separating a\n");
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[15]->type eq 'wikiword');
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[15]->content eq 'WordFromNumbers');
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[16]->type eq 'text');
#ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
#    [1]->content->[16]->content eq "123 using double quotes?");

ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->type eq 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [12]->children->[2]->content} == 5);
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[0]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[0]->content eq 'How about some funkier URLs like ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[1]->type eq 'url');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[1]->href eq 'http://www.burningchrome.com:81/');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[1]->content eq "http://www.burningchrome.com:81/");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[2]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[2]->content eq "?  Or,\n");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[3]->type eq 'url');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[3]->href eq 'http://www.eekim.com/cgi-bin/dkr?version=2&date=20021225');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[3]->content eq "http://www.eekim.com/cgi-bin/dkr?version=2&date=20021225");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[4]->type eq 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[4]->content eq '?');

# Conclusion.  (Tests 251-258)

ok($wiki->root->children->[1]->type eq 'section');
ok(scalar @{$wiki->root->children->[1]->children} == 2);
ok($wiki->root->children->[1]->children->[0]->type eq 'h');
ok($wiki->root->children->[1]->children->[0]->content->[0]->type
    eq 'text');
ok($wiki->root->children->[1]->children->[0]->content->[0]->content 
    eq 'Conclusion');
ok($wiki->root->children->[1]->children->[1]->type eq 'p');
ok($wiki->root->children->[1]->children->[1]->content->[0]->type eq 
    'text');
ok($wiki->root->children->[1]->children->[1]->content->[0]->content eq
    "This concludes this test.  We now return you to your regular\nprogramming.");

### tree_test02.txt

