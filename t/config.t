# config.t

use strict;
use Test;

BEGIN { plan tests => 4 };

use PurpleWiki::Config;
my $configfile = 'etc';

my $config = new PurpleWiki::Config($configfile);

ok(ref $config eq 'PurpleWiki::Config');

ok($config->UseSubpage == 1);
ok($config->StyleSheet eq '/~cdent/usemod.css');
ok($config->FS1 eq "\xb31");

