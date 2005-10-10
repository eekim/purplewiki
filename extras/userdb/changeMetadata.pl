#!/usr/bin/perl
#
# changeMetadata.pl
#
# $Id$
#
# Only works with the PlainText backend (for speed reasons).
#
# Copyright (c) Blue Oxen Associates 2005.  All rights reserved.

use strict;
use lib '/home/eekim/devel/PurpleWiki/trunk';
use Fcntl ':mode';
use File::Copy;
use IO::Dir;
use PurpleWiki::Config;

my $CONFIG;
my $mappingFile;
if (scalar @ARGV > 1) {
    $CONFIG = shift;
    $mappingFile = shift;
}
else {
    print "Usage: $0 wikidb mappings\n";
    exit;
}

my $config = new PurpleWiki::Config($CONFIG);
my %mapping = &loadMapping($mappingFile);

# find all .meta files
my $metaFiles = [];
for my $subdir ('A'..'Z', 'misc') {
    my $dir = "$CONFIG/$subdir";
    &findMeta($dir, $metaFiles, undef) if (-d $dir);
}
# change userId based on mapping. note that if the script is
# interrupted, the database is left in a corrupted state.  so
# backup, dammit!
my %ids;
foreach my $metaFile (@{$metaFiles}) {
    open(IN, $metaFile);
    open(OUT, ">$metaFile.new");
    while (my $line = <IN>) {
        chomp $line;
        if ($line =~ /^userId=(\d+)$/) {
            my $currentId = $1;
            if (defined $mapping{$currentId}) {
                $line =~ s/\d+$/$mapping{$currentId}/;
            }
        }
        print OUT "$line\n";
    }
    close(IN);
    close(OUT);
    move("$metaFile.new", $metaFile);
}

### functions

sub loadMapping {
    my $fn = shift;
    my %mapping;

    open(FH, $fn);
    while (my $line = <FH>) {
        chomp $line;
        my ($old, $new) = split(/:/, $line);
        $mapping{$old} = $new;
    }
    close(FH);
    return %mapping;
}

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
