# inline_node.t

use strict;
use Test;

BEGIN { plan tests => 75 };
use PurpleWiki::InlineNode;

#########################

# Basic data.  (3 tests)

my $text01 = 'No formatting, no special characters.  Just the business.';

my $inlineNode = PurpleWiki::InlineNode->new('data'=>$text01);
ok(ref $inlineNode eq 'PurpleWiki::InlineNode');
ok(scalar @{$inlineNode->data} == 1);
ok(${$inlineNode->data}[0] eq $text01);

# Bolded sentence.  (5 tests)

my $text02 = "'''Whole sentence is bolded.'''";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text02);
ok(scalar @{$inlineNode->data} == 1);
ok(ref ${$inlineNode->data}[0] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[0]->type eq 'b');
ok(scalar @{${$inlineNode->data}[0]->data} == 1);
ok(${${$inlineNode->data}[0]->data}[0] eq 'Whole sentence is bolded.');

# Bolded word.  (7 tests)

my $text03 = "Three '''blind''' mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text03);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'b');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(${${$inlineNode->data}[1]->data}[0] eq 'blind');

# Bolded multiline word.  (7 tests)

my $text04 = "Three '''blind\nand ugly''' mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text04);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'b');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(${${$inlineNode->data}[1]->data}[0] eq "blind\nand ugly");

# Italicized word.  (7 tests)

my $text05 = "Three ''blind'' mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text05);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'i');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(${${$inlineNode->data}[1]->data}[0] eq 'blind');

# Nowiki.  (7 tests)

my $text06 = "Three <nowiki>''blind''</nowiki> mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text06);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'nowiki');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(${${$inlineNode->data}[1]->data}[0] eq "''blind''");

# Bold tag.  (7 tests)

my $text07 = "Three <b>blind</b> mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text07);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'b');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(${${$inlineNode->data}[1]->data}[0] eq 'blind');

# Italic tag.  (7 tests)

my $text08 = "Three <i>blind</i> mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text08);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'i');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(${${$inlineNode->data}[1]->data}[0] eq 'blind');

# Fixed type tag.  (7 tests)

my $text09 = "Three <tt>blind</tt> mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text09);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'tt');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(${${$inlineNode->data}[1]->data}[0] eq 'blind');

# Bold and italics.  (9 tests)
# Because of the way the parser is implemented, bold should be the
# parent of the italics.

my $text10 = "Three '''''blind''''' mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text10);
ok(scalar @{$inlineNode->data} == 3);
ok(${$inlineNode->data}[0] eq 'Three ');
ok(${$inlineNode->data}[2] eq ' mice');
ok(ref ${$inlineNode->data}[1] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[1]->type eq 'b');
ok(scalar @{${$inlineNode->data}[1]->data} == 1);
ok(ref ${${$inlineNode->data}[1]->data}[0] eq 'PurpleWiki::InlineNode');
ok(${${$inlineNode->data}[1]->data}[0]->type eq 'i');
ok(${${${$inlineNode->data}[1]->data}[0]->data}[0] eq 'blind');

# Italics and bold tags.  (9 tests)

my $text11 = "<i>Three <b>blind</b></i> mice";

$inlineNode = PurpleWiki::InlineNode->new('data'=>$text11);
ok(scalar @{$inlineNode->data} == 2);
ok(${$inlineNode->data}[1] eq ' mice');
ok(ref ${$inlineNode->data}[0] eq 'PurpleWiki::InlineNode');
ok(${$inlineNode->data}[0]->type eq 'i');
ok(scalar @{${$inlineNode->data}[0]->data} == 2);
ok(${${$inlineNode->data}[0]->data}[0] eq 'Three ');
ok(ref ${${$inlineNode->data}[0]->data}[1] eq 'PurpleWiki::InlineNode');
ok(${${$inlineNode->data}[0]->data}[1]->type eq 'b');
ok(${${${$inlineNode->data}[0]->data}[1]->data}[0] eq 'blind');

# Links.  (not implemented)
