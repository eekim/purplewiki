#!/usr/bin/perl -w
#
# dumpSequence.pl
#
# $Id$
#
# Outputs the contents of the sequence database.
#
# Copyright (c) Blue Oxen Associates 2004.  All rights reserved.

use DB_File;

my (%h, %r);
my $seqdir = '.';
while (@ARGV) {
  $a = shift;
  if ($a =~ /^-d/) {
    $seqdir = $' || shift(@ARGV);
  } else { last; }
}

tie %h, 'DB_File', "$seqdir/sequence.index", O_RDONLY, 0, $DB_HASH
|| die "error opening index $seqdir/sequence.index $!\n";

tie %r, 'DB_File', "$seqdir/sequence.rindex", O_RDONLY, 0, $DB_HASH
|| die "error opening rev index $seqdir/sequence.rindex $!\n";

while (($k, $v) = each(%h)) {
print "$k -> $v\n";
}
print "Reverse:\n";
while (($k, $v) = each(%r)) {
print "$k -> $v\n";
}

untie %h;
untie %r;
exit;
