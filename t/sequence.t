# parser.t

use strict;
use Test;

BEGIN { plan tests => 4 };

use IO::File;
use PurpleWiki::Sequence;

my $datadir = '/tmp';

my $sequence = new PurpleWiki::Sequence($datadir);
ok(ref $sequence eq 'PurpleWiki::Sequence');
ok($sequence->getNext() eq '000001');

for (0..7) {
	$sequence->getNext();
}
ok($sequence->getNext() eq '00000A');

for (0..24) {
	$sequence->getNext();
}
ok($sequence->getNext() eq '000010');

unlink("$datadir/sequence");

# FIXME: there should be a test here for overflow
# but I don't know how to deal with an intentionally failing test
# that causes death?
