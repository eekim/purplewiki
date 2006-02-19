# parser.t

use strict;
use warnings;
use Test::More;

BEGIN { plan tests => 4 };

use IO::File;
use Purple::Client;

my $datadir = '/tmp';
my $url = 'test:test';
my $i=0;

# make sure any existing sequence is killed
unlink("$datadir/purple.db");

### test sequence incrementing
# Using local store, expecting sqlite
my $sequence = new Purple::Client(store => $datadir);
is(ref $sequence, 'Purple::SQLite', 'returned object should be Purple::SQLite');
ok($sequence->getNext($url) eq '1');

for (0..7) {
	$sequence->getNext($i++ . $url);
}
ok($sequence->getNext($i++ . $url) eq 'A');

for (0..24) {
	$sequence->getNext($i-- . $url );
}
ok($sequence->getNext($i++ . $url ) eq '10');

#unlink("$datadir/purple.db");
