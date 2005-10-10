#!/usr/bin/perl
#
# copyUser.pl
#
# $Id$
#
# Copy user from one userdb to another.
#
# Copyright (c) Blue Oxen Associates 2005.  All rights reserved.

use strict;
use PurpleWiki::Config;
use PurpleWiki::UserDB::UseMod;

my $oldConfigFilename;
my $newConfigFilename;
my $username;
if (scalar @ARGV > 2) {
    $oldConfigFilename = shift;
    $newConfigFilename = shift;
    $username = shift;
}
else {
    print "Usage: $0 oldwikidb newwikidb username\n";
    exit;
}

# can only have one PurpleWiki::Config object, so must hack this a bit
my $config = new PurpleWiki::Config($oldConfigFilename);
my $userDb = new PurpleWiki::UserDB::UseMod;
my $userId = $userDb->idFromUsername($username);
my $user = $userDb->loadUser($userId);

my $password = $user->getPassword;
my $tzOffset = $user->tzOffset;
my $createTime = $user->createTime;
my $createIp = $user->createIp;

$user = undef;
$userDb = undef;
$config = undef;

$config = new PurpleWiki::Config($newConfigFilename);
$userDb = new PurpleWiki::UserDB::UseMod;
$user = $userDb->createUser;
$user->username($username);
$user->setPassword($password);
$user->tzOffset($tzOffset);
$user->createTime($createTime);
$user->createIp($createIp);
$userDb->saveUser($user);
