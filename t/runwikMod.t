#!/usr/bin/perl

use Test;

BEGIN { plan tests => 75 };
END {
    system('cp t/config.tDef t/config');
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
            my $diff = diffOutput($compare, $test_out);
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
        } elsif (/^[><]\s+Location=/) {
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
    $line =~ s/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,\s+\d+\s+\d?\d:\d\d(:\d\d)?\s*([ap]m|[A-Z][A-Z]T)\b/DateTimeStamp/;
    $line =~ s/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,\s+\d+\b/DateStamp/;
    $line =~ s/\b\d?\d:\d\d\s*([ap]m|[A-Z][A-Z]T)\b/TimeStamp/;
    substr($line,2);
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
    if (!open(STDOUT, ">$out")) {
        print ERR "Error: $out: $!\n";
        return;
    }
    if (!open(STDERR, ">error")) {
        print ERR "Error: error: $!\n";
        return;
    }
    &UseModWiki::DoWikiRequest($q);
    close STDOUT;
    close STDERR;
    if (!-z "error") {
        print ERR "Error file:\n";
        $err = `cat error`;
        print ERR $err;
    }
}

