# structural_node.t

use strict;
use Test;

BEGIN { plan tests => 18 };
use PurpleWiki::StructuralNode;

#########################

# Simple node.  (2 tests)

my $structuralNode = PurpleWiki::StructuralNode->new;
$structuralNode->type('section');
ok($structuralNode->type eq 'section');

$structuralNode->type('ul');
ok($structuralNode->type eq 'ul');

# Simple node with content.  (6 tests)

my $content = 'Paul Bunyan was a very tall man.';
$structuralNode = PurpleWiki::StructuralNode->new('type'=>'p',
    'content'=>$content);

ok($structuralNode->type eq 'p');
ok(ref $structuralNode->content eq 'PurpleWiki::InlineNode');
ok(!defined $structuralNode->content->type);
ok(!defined $structuralNode->content->href);
ok(scalar @{$structuralNode->content->data} == 1);
ok($structuralNode->content->data->[0] eq $content);

# Tree.  (10 tests)

my $rootNode = PurpleWiki::StructuralNode->new('type'=>'section');
my $currentNode = $rootNode->insertChild('type'=>'ul');
ok($currentNode->parent eq $rootNode);

$currentNode = $currentNode->insertChild('type'=>'li',
    'content'=>'Item one.');
$currentNode = $currentNode->parent;
$currentNode = $currentNode->insertChild('type'=>'li',
    'content'=>'Item two.');
ok(scalar @{$rootNode->children} == 1);
ok($rootNode->children->[0]->type eq 'ul');
$currentNode = $rootNode->children->[0];
ok(scalar @{$currentNode->children} == 2);
ok($currentNode->children->[0]->type eq 'li');
ok(scalar @{$currentNode->children->[0]->content->data} == 1);
ok($currentNode->children->[0]->content->data->[0] eq 'Item one.');
ok($currentNode->children->[1]->type eq 'li');
ok(scalar @{$currentNode->children->[1]->content->data} == 1);
ok($currentNode->children->[1]->content->data->[0] eq 'Item two.');
