# page.t
# vi:sw=4:ts=4:ai:sm:et

use strict;
use warnings;
use Test;

BEGIN { plan tests => 11};

use PurpleWiki::Parser::WikiText;
use PurpleWiki::Config;

system('cp t/config.tMod t/config');

my $configdir = 't';
my $id = 'WikiPage';
my $newcontent = "Describe the new page here.\n";
my $content=<<"EOF";
Hello this is a wiki page, using WikiPage as a WikiWord.

== Header Injection ==

* this is a list one
* this is a list two

[http://www.burningchrome.com/ this is a link]
EOF

my $expected_content=<<"EOF";
Hello this is a wiki page, using WikiPage as a WikiWord. {nid 1}

== Header Injection {nid 2} ==

* this is a list one {nid 3}
* this is a list two {nid 4}

[http://www.burningchrome.com/ this is a link] {nid 5}
EOF

my $second_content=<<"EOF";
Hello this is a wiki page, using WikiPage as a WikiWord. {nid 1}

== Header Injection ==

* this is a list one {nid 3}
* this is a list two {nid 4}

[http://www.burningchrome.com/ this is a link] {nid 5}
EOF

my $second_expected_content=<<"EOF";
Hello this is a wiki page, using WikiPage as a WikiWord. {nid 1}

== Header Injection {nid 6} ==

* this is a list one {nid 3}
* this is a list two {nid 4}

[http://www.burningchrome.com/ this is a link] {nid 5}
EOF

# parse first content
my $config = new PurpleWiki::Config($configdir);
my $database_package = $config->DatabasePackage;
print STDERR "Error in Package: $database_package\nError:$@"
    unless (eval "require $database_package");
my $pages = $database_package->new ($config, create => 1);
$config->{pages} = $pages;

my $parser = PurpleWiki::Parser::WikiText->new();
my $wiki = $parser->parse($content, add_node_ids => 1);
my $output = $wiki->view('wikitext');
$output =~ s/\r//g;

# is what we parsed what we expected
ok($output, $expected_content);

## now save it

my $page = $pages->getPage($id);

# stored id should be the same as what we gave it
# getPage should fail and return null value
ok($page->getID, $id);

# stored text should be empty at this stage
my $oldText = $page->getTree()->view('wikitext');
ok($oldText, $newcontent);

# revision should be 0
my $oldrev = $page->getRevision();
ok($oldrev, 0);

my $timestamp = time;

# add a new wikitext to the page

my $result = $pages->putPage(pageId => $id,
                             tree => $wiki);
ok($pages->pageExists($id));
ok($result, "");

undef($page);

# load the page up and make sure the id and text are right
my $newPage = $pages->getPage($id);

# adding the wikitext should make a new version
ok($newPage->getRevision(), 1);

my $ts = $newPage->getTime();
my $timediff = $ts - $timestamp;
$timediff = -$timediff if ($timediff < 0);
ok($timediff < 100);
ok($newPage->getID(), $id);
ok($newPage->getTree()->view('wikitext'), $expected_content);

# parse second content
$wiki = $parser->parse($second_content, add_node_ids => 1);
$output = $wiki->view('wikitext');
$output =~ s/\r//g;

# is what we parsed what we expected
ok($output, $second_expected_content);

sub END {
    unlink('t/tDB/sequence');
    system('cp t/config.tDef t/config');
}
