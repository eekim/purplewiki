# page.t
# vi:sw=4:ts=4:ai:sm:et

use strict;
use warnings;
use Test;

BEGIN { plan tests => 12};

use PurpleWiki::Database::Page;
use PurpleWiki::Database::KeptRevision;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Config;

my $configdir = 't';
my $lockdir = 't/temp/lockmain';
my $id = 'WikiPage';
my $idFilename = 't/page/W/WikiPage.db';
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
my $database_package = $config->DatabasePackage
                       || "PurpleWiki::Database::Page";
eval "require $database_package";
$database_package .= "s" unless ($database_package =~ /s$/);
my $pages = $database_package->new ($config);
$config->{pages} = $pages;

my $parser = PurpleWiki::Parser::WikiText->new();
my $wiki = $parser->parse($content, add_node_ids => 1);
my $output = $wiki->view('wikitext');
$output =~ s/\r//g;

# is what we parsed what we expected
ok($output, $expected_content);

## now save it, be amazed how complicated this is...
## we'll do the whole bag
# lock
ok(PurpleWiki::Database::RequestLock() && -d $lockdir);
my $page = $pages->newPage('id' => $id, 'now' => time);

# stored id should be the same as what we gave it
ok($page->getID(), $id);

# stored text should be empty at this stage
my $oldText = $page->getText();
ok($oldText, $newcontent);

# revision should be 0
my $oldrev = $page->getRevision();
ok($oldrev, 0);

# add a new wikitext to the page
$page = $pages->newPage(id => $id,
                        wikitext => $output,
                        timestamp => time);
my $getText = $page->getText();
ok($getText, $expected_content);

# adding the wikitext should make a new version
ok($page->getRevision(), 1);

# save page
ok($page->save(), -f $idFilename);

# get rid of lock
ok(PurpleWiki::Database::ReleaseLock() && ! -d $lockdir);
undef($page);

# load the page up and make sure the id and text are right
my $newPage = $pages->newPageId($id);
ok($newPage->getID(), $id);
ok($newPage->getText(), $expected_content);

# parse second content
$wiki = $parser->parse($second_content, add_node_ids => 1);
$output = $wiki->view('wikitext');
$output =~ s/\r//g;

# is what we parsed what we expected
ok($output, $second_expected_content);

sub END {
    unlink('t/sequence');
    unlink($idFilename);
    rmdir($lockdir);
}
