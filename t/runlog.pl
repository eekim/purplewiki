
# helper routines for running wiki.pl tests and filtering diffs for real
# differences

sub diffOutput {
    my ($from, $to, $map) = @_;
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
                my $realdiff = check(\@from, \@to, $map);
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

sub MapRevisions {
my $file = shift;
my %revMap = ();
my $revNum = 1;
my @file;
    if (open(IN, $file)) {
        @file = (<IN>);
        for (@file) {
            $revMap{$2} = 1
                if (/(Revision |revision=)(\d+)/ && !defined($revMap{$2}));
        }
        close IN;
        grep( ($revMap{$_} = $revNum++), (sort {$a <=> $b} keys %revMap) );
    } else {
        print ERR "Can't open $file $!\n";
        return;
    }
    if (open(OT, ">$file")) {
        for (@file) {
             s/(revision=|Revision )(\d+)/$1$revMap{$2}/;
             print OT $_;
        }
        close OT;
    } else {
        print ERR "Can't open $file $!\n";
        return;
    }
}

sub check {
my ($from, $to, $map) = @_;
my $last = $#$from;
#print ERR "check $#$from $#$to\n";
    if ($#$to == $last) {
        for my $i (0..$last) {
           my $f = stripDate($$from[$i], $map);
           my $t = stripDate($$to[$i], $map);
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
my $map = shift;
    $line =~ s/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,\s+\d+\s+\d?\d:\d\d(:\d\d)?\s*([ap]m|[A-Z][A-Z]T)\b/DateTimeStamp/;
    $line =~ s/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+,\s+\d+\b/DateStamp/;
    $line =~ s/\b\d?\d:\d\d\s*([ap]m|[A-Z][A-Z]T)\b/TimeStamp/;
    $line =~ s/("oldrev"\s+value=)"\d+"/$1"YourRev"/ if ($map);
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

1;

