#!/usr/bin/perl

my ($split, $once, $update) = (0, 0, 0);
$seq=0;
$configdir = "t";
$dodiff=1;
$testdir="t/out";
while (@ARGV) {
    $a = shift(@ARGV);
    if ($a =~ /^-1/) {
        $once = 1;
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
print ERR "Starting $test_out\n";
            runTest($q, $test_out);
            if ($dodiff) {
            my $diff = diffOutput($compare, $test_out);
                if ($diff) {
                    print ERR "Seq $seq differs:\n";
                    print ERR $diff;
                    unlink $test_out unless ($update);
                } else {
                    unlink $test_out;
                    print ERR "Ok $seq\n";
                }
            }
            close IN;
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

sub diffOutput {
    my ($from, $to) = @_;
    my @diff = split("\n", `diff $from $to 2>&1`);
#print ERR "\nDiff $from $to\n";
#my $diff= join("\n", @diff)."\n";
#return $diff;
    my @out = ();
    my @from = ();
    my @to = ();
    my ($pre, $after, $add_delete) = ("", 0, 0);
    for (@diff) {
        if (/^\d+(,\d+)?([cda])\d+(,\d+)?$/) {
            if ($2 ne 'c') {
                $add_delete = 1;
                push @out, $_;
                next;
            }
            if (@from || @to) {
                my $realdiff = check(\@from, \@to);
                push @out, $pre, $realdiff if $realdiff;
            }
            $pre = $_;
            @from = @to = ();
            $add_delete = $after = 0;
        } elsif ($add_delete) {
            push @out, $_;
        } elsif (/^---$/) {
            $after = 1;
        } elsif (/^[><]\s+Location(=|: )/) {
        } elsif (/^[><]\s+(Set-Cookie|Date|<p>Last save time):/) {
        #} elsif (/^[><][\.\s]+(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,/) {
        } elsif (/^< /) {
            push @out, "From after $." if $after;
            push @from, $_;
        } elsif (/^> /) {
            push @out, "To before $." unless $after;
            push @to, $_;
        } else {
            push @out, "No match $. $_";
        }
    }
    if (@from || @to) {
        my $realdiff = check(\@from, \@to);
        push @out, $pre, $realdiff if $realdiff;
    }
    return join("\n", @out);
}

sub check {
my ($from, $to) = @_;
my (@from, @to) = ((), ());
my $last = $#$from;
#print ERR "check $#$from $#$to\n";
    if ($#$to == $last) {
        for my $i (0..$last) {
           my $f = stripDate($$from[$i]);
           my $t = stripDate($$to[$i]);
#print ERR "Diff:\n-$from\n+$to\n" if ($t ne $f);
           return join("\n", @$from, '---', @$to) if ($t ne $f);
        }
    } else {
        return join("\n", @$from, '---', @$to);
    }
    return "";
}

sub stripDate {
my $line = shift;
my $x = $line;
    $line =~ s/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,\s+\d+\s+\d\d?:\d\d(:\d\d)?\s*([ap]m|[A-Z][A-Z]T)\b/DateTimeStamp/;
#October 6, 2004 8:01 pm
    $line =~ s/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,\s+\d+\b/DateStamp/;
    $line =~ s/\b\d?\d:\d\d\s*([ap]m|[A-Z][A-Z]T)\b/TimeStamp/;
#print ERR "Ch:$x >> $line:\n" if $x ne $line;
    substr($line,2);
}

sub writeTest {
    my ($out, $url, $q) = @_;
    if (!open(OUT, ">$out")) {
        print ERR "Error: $out: $!\n";
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
        require "./wiki.pl";
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
