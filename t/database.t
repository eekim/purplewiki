# database.t

use strict;
use warnings;
use Test;

BEGIN { plan tests => 5 };

use PurpleWiki::UseMod::Database;
use PurpleWiki::Misc;
use PurpleWiki::Config;

my $configdir = 't';
my $file = "t/tDB/$$";
my $dir = "t/tDB/testdir$$";
my $content = "sample content";
my $tempdir = 't/tDB/temp';
my $lockdir = "$tempdir/lockmain";


# filehandling
ok(PurpleWiki::Misc::WriteStringToFile($file, $content), 1);
ok(PurpleWiki::Misc::ReadFile($file), $content);
ok(PurpleWiki::Misc::CreateDir($dir) && -d $dir);

# lockhandling
my $config = new PurpleWiki::Config($configdir);
ok(PurpleWiki::UseMod::Database::RequestLock($config) && -d $lockdir);
ok(PurpleWiki::UseMod::Database::ReleaseLock($config) && ! -d $lockdir);

# diff handling elsewhere, in the page tests
   
sub END { 
    unlink($file);
    rmdir($dir);
    rmdir($tempdir);
}
