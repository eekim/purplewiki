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
