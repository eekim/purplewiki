# parser01.t

use strict;
use warnings;
use Test;

BEGIN { plan tests => 159 };

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
my $wikiContent = &readFile('t/txt/tree_test01.txt');
my $wikiParser = PurpleWiki::Parser::WikiText->new;
my $wiki = $wikiParser->parse($wikiContent);
$wiki->title('Tree Test 1');

# Document.  (Tests 1-4)

ok($wiki->title, 'Tree Test 1');
ok(ref $wiki->root, 'PurpleWiki::StructuralNode');
ok($wiki->root->type, 'document');
ok(scalar @{$wiki->root->children}, 2);

# Basic Wiki Test (Tests 5-9)

ok($wiki->root->children->[0]->type, 'section');
ok(scalar @{$wiki->root->children->[0]->children}, 2);
ok($wiki->root->children->[0]->children->[0]->type, 'h');
ok($wiki->root->children->[0]->children->[0]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[0]->content->[0]->content,
   'Basic Wiki Test');

# Introduction (Tests 10-37)

ok($wiki->root->children->[0]->children->[1]->type, 'section');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children}, 13);
ok($wiki->root->children->[0]->children->[1]->children->[0]->type, 'h');
ok($wiki->root->children->[0]->children->[1]->children->[0]->content->
    [0]->content, 'Introduction');
ok($wiki->root->children->[0]->children->[1]->children->[1]->type, 'p');
ok($wiki->root->children->[0]->children->[1]->children->[1]->content->
    [0]->content eq
    "This is a bare-bones, error-free example of a textual Wiki page.  The\nquestion is, will this parse correctly?");
ok($wiki->root->children->[0]->children->[1]->children->[2]->type, 'pre');
ok($wiki->root->children->[0]->children->[1]->children->[2]->content->
    [0]->content, "  Only time will tell.\n  And tell it will.");
ok($wiki->root->children->[0]->children->[1]->children->[3]->type, 'p');
ok($wiki->root->children->[0]->children->[1]->children->[3]->content->
    [0]->content, "This is a paragraph.");
ok($wiki->root->children->[0]->children->[1]->children->[4]->type, 'p');
ok($wiki->root->children->[0]->children->[1]->children->[4]->content->
    [0]->content, "This is another paragraph.");
ok($wiki->root->children->[0]->children->[1]->children->[5]->type, 'p');
ok($wiki->root->children->[0]->children->[1]->children->[5]->content->
    [0]->content, "How about mixed paragraphs and preformatting?");
ok($wiki->root->children->[0]->children->[1]->children->[6]->type, 'pre');
ok($wiki->root->children->[0]->children->[1]->children->[6]->content->
    [0]->content, "   This should be preformatted.\n But is it?");
ok($wiki->root->children->[0]->children->[1]->children->[7]->type, 'p');
ok($wiki->root->children->[0]->children->[1]->children->[7]->content->
    [0]->content, "You should know by now.");
ok($wiki->root->children->[0]->children->[1]->children->[8]->type, 'p');
ok($wiki->root->children->[0]->children->[1]->children->[8]->content->
    [0]->content eq
    "What about <strong>HTML</strong> in paragraphs?  You should see the tags.");
ok($wiki->root->children->[0]->children->[1]->children->[9]->type, 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->[9]->
    content}, 3);
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [0]->content, "Does the nowiki tag work?  ");
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [1]->type, 'nowiki');
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [1]->content, "Well, that depends.  Do you see\n'''quotes''' or not?");
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [2]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[9]->content->
    [2]->content, "  If so, then be happy!");

# Unordered list.  (Tests 38-44)

ok($wiki->root->children->[0]->children->[1]->children->[10]->type, 'section');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [0]->type, 'h');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [0]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [0]->content->[0]->content, 'Lists');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->type, 'p');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[10]->children->
    [1]->content->[0]->content, 'Tests moved to tree_test14.txt.');

# Quote formatting.  (Tests 45-66)

ok($wiki->root->children->[0]->children->[1]->children->[11]->type, 'section');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [0]->type, 'h');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [0]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [0]->content->[0]->content, 'Formatting');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->type, 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [11]->children->[1]->content}, 7);
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[0]->content, 'This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[1]->type, 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[1]->children->[0]->content, 'italics');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[2]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[2]->content, '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[3]->type, 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[3]->children->[0]->content, 'bold');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[4]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[4]->content, '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->type, 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->children->[0]->type, 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->children->[0]->children->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[5]->children->[0]->children->[0]->content eq
    "bold and\nitalic");
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[6]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [1]->content->[6]->content, '.');

# HTML formatting.  (Tests 67-99)

ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->type, 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [11]->children->[2]->content}, 12);
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[0]->type, 'wikiword');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[0]->content, 'UseModWiki');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[1]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[1]->content, ' also supports HTML bold and italic tags.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[2]->type, 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[2]->children->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[2]->children->[0]->content, 'italics');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[3]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[3]->content, '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[4]->type, 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[4]->children->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[4]->children->[0]->content, 'bold');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[5]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[5]->content, '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->type, 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->children->[0]->type, 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->children->[0]->children->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[6]->children->[0]->children->[0]->content eq
    'bold and italic');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[7]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[7]->content, '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->type, 'i');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->children->[0]->type, 'b');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->children->[0]->children->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[8]->children->[0]->children->[0]->content eq
    'italic and bold');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[9]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[9]->content, '.  This is ');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[10]->type, 'tt');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[10]->children->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[10]->children->[0]->content, 'monospace');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[11]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[11]->children->
    [2]->content->[11]->content, '.');

# Links.  (Tests 100-151)

ok($wiki->root->children->[0]->children->[1]->children->[12]->type, 'section');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [0]->type, 'h');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [0]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [0]->content->[0]->content, 'Links');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->type, 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [12]->children->[1]->content}, 15);
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[0]->content, 'How about a paragraph with some ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[1]->type, 'wikiword');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[1]->content, 'WikiWords');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[2]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[2]->content, '?  How about a ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[3]->type, 'freelink');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[3]->content, "double\nbracketed free link");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[4]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[4]->content, '?  How about a link to ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[5]->type, 'link');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[5]->href, 'http://www.eekim.com/');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[5]->content, "my\nhomepage");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[6]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[6]->content, '.  What about the URL itself, like ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[7]->type, 'url');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[7]->href, 'http://www.eekim.com/');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[7]->content, "http://www.eekim.com/");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[8]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[8]->content, ".\nHow about not linking a ");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[9]->type, 'nowiki');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[9]->content, "WikiWikiWord");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[10]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[10]->content, ". How about a\n");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[11]->type, 'wikiword');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[11]->content, 'UseMod:InterWiki');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[12]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[12]->content, " link?  Finally, how about separating a\n");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[13]->type, 'wikiword');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[13]->content, 'WordFromNumbers');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[14]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [1]->content->[14]->content, "123 using double quotes?");

ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->type, 'p');
ok(scalar @{$wiki->root->children->[0]->children->[1]->children->
    [12]->children->[2]->content}, 5);
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[0]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[0]->content, 'How about some funkier URLs like ');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[1]->type, 'url');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[1]->href, 'http://www.burningchrome.com:81/');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[1]->content, "http://www.burningchrome.com:81/");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[2]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[2]->content, "?  Or,\n");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[3]->type, 'url');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[3]->href, 'http://www.eekim.com/cgi-bin/dkr?version=2&date=20021225');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[3]->content, "http://www.eekim.com/cgi-bin/dkr?version=2&date=20021225");
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[4]->type, 'text');
ok($wiki->root->children->[0]->children->[1]->children->[12]->children->
    [2]->content->[4]->content, '?');

# Conclusion.  (Tests 152-159)

ok($wiki->root->children->[1]->type, 'section');
ok(scalar @{$wiki->root->children->[1]->children}, 2);
ok($wiki->root->children->[1]->children->[0]->type, 'h');
ok($wiki->root->children->[1]->children->[0]->content->[0]->type, 'text');
ok($wiki->root->children->[1]->children->[0]->content->[0]->content,
   'Conclusion');
ok($wiki->root->children->[1]->children->[1]->type, 'p');
ok($wiki->root->children->[1]->children->[1]->content->[0]->type, 'text');
ok($wiki->root->children->[1]->children->[1]->content->[0]->content,
    "This concludes this test.  We now return you to your regular\nprogramming.");

### tree_test02.txt

