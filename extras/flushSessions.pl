#!/usr/bin/perl

my $INTERVAL = 604800;  # 7 days
my $sessionDir = $ARGV[0];
opendir(DIR, $sessionDir) or die "can't open $sessionDir: $!";
@files = grep { /^cgisess_/ && -f "$sessionDir/$_" } readdir(DIR);
my $now = time;
my $flushed = 0;
foreach my $file (@files) {
    my $mtime = (stat("$sessionDir/$file"))[9];
    if ($now - $mtime > $INTERVAL) {
        unlink "$sessionDir/$file";
        $flushed++;
    }
}
closedir(DIR);
print "$flushed sessions flushed.\n";
