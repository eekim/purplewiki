#!/usr/bin/perl
#
# moinConvert.pl
#
# $Id$
#
# Converts MoinMoin files over to PurpleWiki.
#
# To use, you must have all of your MoinMoin files in a directory, and
# you must setup an wikidb directory where the converted database will
# go.  That wikidb should have a config file.
#
# Usage:
#
#   moinConvert.pl /path/to/moinmoin /path/to/wikidb

use strict;
use PurpleWiki::Config;
use PurpleWiki::Misc;
use PurpleWiki::UseMod::KeptRevision;
use PurpleWiki::Archive::UseMod;
use PurpleWiki::Parser::MoinMoin;

my $MOINDIR;
my $PW_CONFIG_DIR;
if (scalar @ARGV == 2) {
    $MOINDIR = shift @ARGV;
    $PW_CONFIG_DIR = shift @ARGV;
}
else {
    print <<EOM;
Usage:
    $0 moindir wikidb

where moindir is the directory containing the MoinMoin Wiki files and
wikidb is the directory where the PurpleWiki config file resides and
the converted files will eventually go.

EOM
    exit;
}

use POSIX 'strftime';
my $date = strftime("%F", localtime(time));

my $config = PurpleWiki::Config->new($PW_CONFIG_DIR);
my $wikiParser = PurpleWiki::Parser::MoinMoin->new;

my $database_package = $config->DatabasePackage;
print STDERR "Database Package $database_package\nError: $@\n"
    unless (defined(eval "require $database_package"));
$pages = $database_package->new ($config, create => 1);

opendir DIR, $MOINDIR;
my @files = grep { -f "$MOINDIR/$_" } readdir(DIR);
closedir DIR;

foreach my $file (@files) {
    my $now = time;
    my $wikiContent = &PurpleWiki::Misc::ReadFileOrDie("$MOINDIR/$file");
    my $wiki = $wikiParser->parse($wikiContent, add_node_ids => 1);

    $pages->putPage(pageId => $file,
                    tree => $wiki,
                    changeSummary => 'Converted from MoinMoin $date');
}
