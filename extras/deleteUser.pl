#!/usr/bin/perl
#
# deleteUser.pl
#
# $Id$
#
# Cleans out locked and duplicate user IDs and renumbers users.
# Generates a username -> userID lookup table from wikidb/user
# directory
#
# Copyright (c) Blue Oxen Associates 2004.  All rights reserved.

use strict;
use DB_File;
use File::Copy;
use File::Find;
use PurpleWiki::Config;
use PurpleWiki::UserDB::UseMod;

my $CONFIG;
my $userName;
if (scalar @ARGV > 1) {
    $CONFIG = shift;
    $userName = shift;
}
else {
    print "Usage: $0 wikidb username\n";
    exit;
}

my $config = new PurpleWiki::Config($CONFIG);
my $userDb = new PurpleWiki::UserDB::UseMod;
$userDb->deleteUser($userName);

=head1 NAME

deleteUser.pl - Deletes a user from the database

=head1 SYNOPSIS

  deleteUser.pl /path/to/wikidb username

=head1 DESCRIPTION

Deletes a user from the user database.

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
