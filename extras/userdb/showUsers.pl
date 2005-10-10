#!/usr/bin/perl
#
# showUsers.pl
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2005.  All rights reserved.

use strict;
use DB_File;
use PurpleWiki::Config;
use PurpleWiki::UserDB::UseMod;

my $CONFIG;
if (scalar @ARGV > 0) {
    $CONFIG = shift;
}
else {
    print "Usage: $0 wikidb\n";
    exit;
}

my $config = new PurpleWiki::Config($CONFIG);
my $userDb = new PurpleWiki::UserDB::UseMod;
my %users;
tie %users, "DB_File", $config->userDir . '/usernames.db',
        O_RDONLY, 0444, $DB_HASH;
my %ids;
foreach my $username (keys %users) {
    $ids{$users{$username}} = $username;
}
untie %users;
foreach my $id (sort keys %ids) {
    print "$id     " . $ids{$id} . "\n";
}
