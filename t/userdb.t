# userdb.t

use strict;
use Test;

BEGIN { plan tests => 8 };

use PurpleWiki::UserDB::UseMod;
use PurpleWiki::Config;

my $configdir = 't';
my $datadir = 't/tDB';
my $userName = '@blueoxen*eekim';

#########################

my $config = new PurpleWiki::Config($configdir);

# create new user database
my $userDb = PurpleWiki::UserDB::UseMod->new;

# create new user $userName
my $user = $userDb->createUser;
ok($user->id == 1001);
$user->username($userName);
$userDb->saveUser($user);
ok(-f "$datadir/user/1/1001.db");

# create another user
$user = undef;
$user = $userDb->createUser;
ok($user->id == 1002);

# now open user $userName again
$user = undef;
$user = $userDb->loadUser($userDb->idFromUsername($userName));
ok($user->id == 1001);
ok($user->username eq $userName);

# rename the user
$user->username('eekim');
$userDb->saveUser($user);
$user = undef;
ok(!defined $userDb->idFromUsername($userName));
ok($userDb->idFromUsername('eekim') == 1001);
$user = $userDb->loadUser(1001);
ok($user->username eq 'eekim');

sub END { 
    # delete user database
    unlink("$datadir/user/usernames.db");
    unlink("$datadir/user/1/1001.db");
    unlink("$datadir/user/2/1002.db");
    rmdir("$datadir/user/0");
    rmdir("$datadir/user/1");
    rmdir("$datadir/user/2");
    rmdir("$datadir/user/3");
    rmdir("$datadir/user/4");
    rmdir("$datadir/user/5");
    rmdir("$datadir/user/6");
    rmdir("$datadir/user/7");
    rmdir("$datadir/user/8");
    rmdir("$datadir/user/9");
    rmdir("$datadir/user");
}
