#!/usr/bin/perl

use Test;
require "t/runlog.pl";

BEGIN { plan tests => 75 };
END {
    system('cp t/config.tDef t/config');
    system('cp -r t/rDB t/useModDB');
    system('rm -fr t/rDB');
}

$ENV{PW_CONFIG_DIR} = 't';
my $keep_errors = 0;
my $testdir = 't/out';
system('cp t/config.runMod t/config');

{
    require "wiki.pl";
    use CGI;

    open(ERR, ">&STDERR") || die "Error open $!\n";
    close STDERR;
    open(OUT, ">&STDOUT") || die "Error open $!\n";

    my ($test_in, $test_out, $compare);
    for my $seq (0..74) {
        $test_in = "$testdir/request.$seq";
        $test_out = "$testdir/test.$seq.html";
        $compare = "$testdir/wiki.$seq.html";
        if (open(IN, $test_in)) {
            chomp($url = <IN>);
            my $q = new CGI(IN);
            close IN;
            close STDOUT;
            runTest($q, $test_out);
            MapRevisions($test_out);
            my $diff = diffOutput($compare, $test_out, 1);
            open(STDOUT, ">&OUT");
            ok($diff, '');
            if ($diff) {
                print ERR "Seq $seq differs:\n";
                print ERR $diff;
                unlink $test_out unless ($keep_errors);
            } else {
                unlink $test_out;
            }
        } else { print ERR "Couldn't open $test_in: $!\n"; }
    }
}

exit;

