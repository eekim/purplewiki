# config.t

use strict;
use warnings;
use Test;

BEGIN { plan tests => 4 };

use PurpleWiki::Config;
my $configdir = 't';
my $datadir = 't/tDB';

system('cp t/config.tDef t/config');
(-d $datadir) || system("mkdir $datadir");

my $config = new PurpleWiki::Config($configdir);

ok(ref $config eq 'PurpleWiki::Config');

ok($config->UseSubpage == 1);
ok($config->RCName eq 'RecentChanges');
ok($config->ArchiveDriver, 'PurpleWiki::Archive::PlainText');

