#!/usr/bin/perl
#
# renameUser.pl
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2005.  All rights reserved.

use strict;
use PurpleWiki::Config;
use PurpleWiki::UserDB::UseMod;

my $CONFIG;
my $oldName;
my $newName;
if (scalar @ARGV > 2) {
    $CONFIG = shift;
    $oldName = shift;
    $newName = shift;
}
else {
    print "Usage: $0 wikidb old_username new_username\n";
    exit;
}

my $config = new PurpleWiki::Config($CONFIG);
my $userDb = new PurpleWiki::UserDB::UseMod;
my $userId = $userDb->idFromUsername($oldName);
my $user = $userDb->loadUser($userId);
$user->username($newName);
$userDb->saveUser($user);
