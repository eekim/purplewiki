#!/usr/bin/perl

require "t/runlog.pl";

my ($split, $once, $update) = (0, 0, 0);
$seq=0;
$configdir = "t";
$dodiff=1;
$testdir="t/out";
$map=0;
while (@ARGV) {
    $a = shift(@ARGV);
    if ($a =~ /^-1/) {
        $once = 1;
    } elsif ($a eq '-m') {
        $map = 1;
    } elsif ($a eq '-nd') {
        $dodiff = 0;
    } elsif ($a =~ /^-t/) {
        $testdir = $' || shift(@ARGV);
    } elsif ($a =~ /^-c/) {
        $configdir = $' || shift(@ARGV);
    } elsif ($a =~ /^-s/) {
        $split = 1;
    } elsif ($a =~ /^-u/) {
        $update = 1;
    } elsif ($a =~ /^\d+$/) {
        $seq = $a;
    } elsif (!$a) {
        print STDERR "Null option? @ARGV\n";
    } else {
        die "Bad option :$a:\n";
    }
}
$ENV{PW_CONFIG_DIR} = $configdir;

require "wiki.pl";
use CGI;

open(ERR, ">&STDERR") || die "Error open $!\n";
close STDERR;
close STDOUT;

if ($split) {
    while(!eof(STDIN)) {
        my $test_in = "$testdir/request.$seq";
        my $test_out = "$testdir/wiki.$seq.html";
        chomp($url = <STDIN>);
        my $q = new CGI(STDIN);
        writeTest($test_in, $url, $q);
        runTest($q, $test_out);
        last if $once;
        $seq++;
    }
} else {
    my $test_in = "$testdir/request.$seq";
    my $test_out = "$testdir/test.$seq.html";
    my $compare = "$testdir/wiki.$seq.html";
    while (-f $test_in) {
        if (open(IN, $test_in)) {
            chomp($url = <IN>);
            my $q = new CGI(IN);
            close IN;
            runTest($q, $test_out);
            if ($dodiff) {
                MapRevisions($test_out) if ($map);
                my $diff = diffOutput($compare, $test_out);
                if ($diff) {
                    print ERR "Seq $seq differs:\n";
                    print ERR $diff,"\n";
                    unlink $test_out unless ($update);
                } else {
                    unlink $test_out;
                }
            }
        } else { print ERR "Couldn't open $test_in: $!\n"; }
        last if $once;
        $seq++;
        $test_in = "$testdir/request.$seq";
        $test_out = "$testdir/test.$seq.html";
        $compare = "$testdir/wiki.$seq.html";
    }
}

print ERR "end\n";

exit;

