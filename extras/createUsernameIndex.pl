#!/usr/bin/perl
#
# createUsernameIndex.pl
#
# $Id$
#
# Cleans out locked and duplicate user IDs and renumbers users.
# Generates a username -> userID lookup table from wikidb/user
# directory

use strict;
use DB_File;
use File::Copy;
use File::Find;
use PurpleWiki::Config;
use PurpleWiki::Database::User;

my $CONFIG;
if (scalar @ARGV) {
    $CONFIG = shift;
}
else {
    print "Usage: $0 wikidb\n";
    exit;
}

my $config = new PurpleWiki::Config($CONFIG);
my $userDir = $config->UserDir;

my %users;  # $users{name} = id
my %ids;    # $ids{id} = name
my @userIds;
find(sub {-f && !/^200\.db/ && /^(\d\d\d\d)\.db/ && push @userIds, $1}, ( $userDir ) );

my @toDelete;

foreach my $userId (sort @userIds) {
    my $user = PurpleWiki::Database::User->new(id => $userId);
    my $userName = $user->getUsername;
    if ($userName) {
        if ($users{$userName}) { # duplicate
            push @toDelete, $users{$userName};
            delete $ids{$users{$userName}};
        }
        $users{$userName} = $userId;
        $ids{$userId} = $userName;
    }
    else {
        push @toDelete, $userId;
    }
}

foreach my $userId (sort @toDelete) {
    unlink &fullPath($userId);
}

my $currentId = 1001;
my %persistentUsers;
tie %persistentUsers, "DB_File", "$userDir/usernames.db",
    O_RDWR|O_CREAT, 0666, $DB_HASH;
foreach my $oldUserId (sort keys %ids) {
    if ($oldUserId > $currentId) {
        $persistentUsers{$ids{$oldUserId}} = $currentId;
        move(&fullPath($oldUserId), &fullPath($currentId));
        my $user = PurpleWiki::Database::User->new(id => $currentId);
        $user->setField('id', $currentId);
        $user->save;
    }
}
untie %persistentUsers;

# fini

sub fullPath {
    my $id = shift;
    $config->UserDir . '/' . ($id % 10) . "/$id.db";
}
