#!/usr/bin/perl
#
# This program prints out all links on a page.
#

use strict;
use warnings;
use lib '/data/www/perl2';
use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::View::Filter;
use Data::Dumper;

my $configDir = shift || die "Usage: $0 /path/to/wikidb\n";

my $config = new PurpleWiki::Config($configDir);
my $parser = new PurpleWiki::Parser::WikiText;

my $filter = new PurpleWiki::View::Filter;
$filter->setFilter(wikiwordMain => sub {print '  ' . shift->content . "\n"},
                   urlMain => sub {print '  ' . shift->href . "\n"},
                   linkMain => sub {print '  ' . shift->href . "\n"});

my $pages = $config->{pages};
my @pageList = $pages->allPages;
foreach my $id (@pageList) {
    print "$id\n";
    my $tree = $pages->getPage($id)->getTree;
    $filter->process($tree);
}
