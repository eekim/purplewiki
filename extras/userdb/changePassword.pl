#!/usr/bin/perl
#
# changePassword.pl
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2005.  All rights reserved.

use strict;
use File::Copy;
use File::Find;
use PurpleWiki::Config;
use PurpleWiki::UserDB::UseMod;

my $CONFIG;
my $userName;
my $password;
if (scalar @ARGV > 2) {
    $CONFIG = shift;
    $userName = shift;
    $password = shift;
}
else {
    print "Usage: $0 wikidb username password\n";
    exit;
}

my $config = new PurpleWiki::Config($CONFIG);
my $userDb = new PurpleWiki::UserDB::UseMod;
my $userId = $userDb->idFromUsername($userName);
my $user = $userDb->loadUser($userId);
$user->setPassword($password);
$userDb->saveUser($user);
