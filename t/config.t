# config.t

use strict;
use warnings;
use Test;

BEGIN { plan tests => 8 };

use PurpleWiki::Config;
my $configdir = 't';
my $datadir = 'tDB';

(-d $datadir) || system("mkdir $datadir");

my $config = new PurpleWiki::Config($configdir);

ok(ref $config, 'PurpleWiki::Config');

ok($config->UseSubpage, 1);
ok($config->RCName, 'RecentChanges');
ok($config->FS1, "\xb31");

my $mod = $config->Module;
ok(ref($mod), "HASH");
ok($mod->{database}, "PurpleWiki::Database::Page");
my $action = $config->Action;
ok(ref($action), "HASH");
ok($action->{edit}, "PurpleWiki::Action::Edit");

