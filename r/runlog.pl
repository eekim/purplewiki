#!/usr/bin/perl

my ($split, $once, $update) = (0, 0, 0);
$seq=0;
while (@ARGV) {
    $a = shift(@ARGV);
    if ($a =~ /^-1/) {
        $once = 1;
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

use CGI;

open(ERR, ">&STDERR") || die "Error open $!\n";
close STDERR;
close STDOUT;

if ($split) {
    while(!eof(STDIN)) {
        my $test_in = "out/request.$seq";
        my $test_out = "out/wiki.$seq.html";
        chomp($url = <STDIN>);
        my $q = new CGI(STDIN);
        writeTest($test_in, $url, $q);
        runTest($q, $test_out);
        last if $once;
        $seq++;
    }
} else {
    my $test_in = "out/request.$seq";
    my $test_out = "out/test.$seq.html";
    my $compare = "out/wiki.$seq.html";
    while (-f $test_in) {
        if (open(IN, $test_in)) {
            chomp($url = <IN>);
            my $q = new CGI(IN);
            runTest($q, $test_out);
            my $diff = diffOutput($test_out, $compare);
            if ($diff) {
                print ERR "Seq $seq differs:\n";
                print ERR $diff;
                unlink $test_out unless ($update);
            } else {
                unlink $test_out;
            }
            close IN;
        } else { print ERR "Couldn't open $test_in: $!\n"; }
        last if $once;
        $seq++;
        $test_in = "out/request.$seq";
        $test_out = "out/test.$seq.html";
        $compare = "out/wiki.$seq.html";
    }
}

print ERR "end\n";

exit;

sub diffOutput {
    my ($from, $to) = @_;
    my @diff = split("\n", `diff $from $to 2>&1`);
#print ERR "\nDiff $from $to\n";
#my $diff= join("\n", @diff)."\n";
#return $diff;
    my @out = ();
    my ($pre, $post) = ("", 0);
    for (@diff) {
        if (/^\d+(,\d+)?c\d+(,\d+)?$/) {
            if ($post) { push @out, ($_ . "\n"); }
            else { $post = 0; $pre = ($_ . "\n"); }
        } elsif (/^---$/) {
            if ($post) { push @out, ($_ . "\n"); }
            else { $pre .= ($_ . "\n"); }
        } elsif (/^[><]\s+(Set-Cookie|Date|<p>Last save time):/) {
        } elsif (/^[><][\.\s]+(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,/) {
        } else {
            push @out, $pre, "$_\n";
            $pre = '';
            $post = 1;
        }
    }
    return join("", @out);
}

sub writeTest {
    my ($out, $url, $q) = @_;
    if (!open(OUT, ">$out")) {
        print ERR "Error: out/wiki.$seq: $!\n";
        return;
    }
    print OUT "$url\n";
    $q->save(OUT);
    close(OUT);
}

sub runTest {
my ($q, $out) = @_;
my ($child, $kid);
    if (!open(STDOUT, ">$out")) {
        print ERR "Error: $out: $!\n";
        return;
    }
    if (!open(STDERR, ">error")) {
        print ERR "Error: error: $!\n";
        return;
    }
    if ($child = fork()) {
        print ERR "Started $child $out\n";
        $kid = wait;
        print ERR "Kid $kid Ch $child\n" if ($kid != $child);
    } else {
        # in child, run the test and exit
        require "wiki.pl";
        &UseModWiki::DoWikiRequest($q);
        exit;
    }
    close STDOUT;
    close STDERR;
    if ($?) { print ERR "Status $?\n"; }
    if (!-z "error") {
        print ERR "Error file:\n";
        $err = `cat error`;
        print ERR $err;
    }
}
