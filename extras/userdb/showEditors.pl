#!/usr/bin/perl
#
# showEditors.pl
#
# $Id$
#
# Only works with the PlainText backend (for speed reasons).
#
# Copyright (c) Blue Oxen Associates 2005.  All rights reserved.

use strict;
use Fcntl ':mode';
use IO::Dir;
use PurpleWiki::Config;

my $CONFIG;
if (scalar @ARGV > 0) {
    $CONFIG = shift;
}
else {
    print "Usage: $0 wikidb\n";
    exit;
}

my $config = new PurpleWiki::Config($CONFIG);

# find all .meta files
my $metaFiles = [];
for my $subdir ('A'..'Z', 'misc') {
    my $dir = "$CONFIG/$subdir";
    &findMeta($dir, $metaFiles, undef) if (-d $dir);
}
# get user IDs
my %ids;
foreach my $metaFile (@{$metaFiles}) {
    open(FH, $metaFile);
    while (my $line = <FH>) {
        chomp $line;
        if ($line =~ /^userId=(\d+)$/) {
            my $id = $1;
            if ($ids{$id}) {
                $ids{$id}++;
            }
            else {
                $ids{$id} = 1;
            }
        }
    }
}
# print user IDs by number of edits (largest first)
foreach my $id (sort { $ids{$b} <=> $ids{$a} } keys %ids) {
    print "$id     " . $ids{$id} . "\n";
}

### functions

sub findMeta {
    my ($dir, $metaFiles, $oldest) = @_;
    my %dir;

    if (tie %dir, 'IO::Dir', $dir) {
        for my $entry (keys %dir) {
            next if ($entry =~ /^\./);
            my $a = $dir{$entry};
            next unless ref($a);
            my ($mode, $mtime) = ($a->mode, $a->mtime);
            if (S_ISDIR($mode)) {
                findMeta("$dir/$entry", $metaFiles, $oldest);
            } elsif (S_ISREG($mode)) {
                push @{$metaFiles}, "$dir/$entry"
                    if ((!$oldest || $mtime > $oldest) && $entry =~ /\.meta$/);
            }
        }
        untie %dir;
    } else { print STDERR "Error reading dir $dir\nError: $!\n"; }
}
