#!/usr/bin/perl
#
# plaintextIntegrity.pl
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2004.  All rights reserved.
#
# Checks integrity of plaintext backend.

use strict;
use Fcntl ':mode';
use File::Copy;
use Getopt::Std;
use IO::Dir;
use Text::Diff;

my %opts;
getopt('s', \%opts);
my @spamRegexps = &getSpamRegexps($opts{'s'});

my $dataDir = shift @ARGV;
die "Usage: $0 [-b] [-s spamregexp.txt] wikidb" unless $dataDir;
$dataDir =~ s/\/$//;

my %spammerUserIds;
my %spammerHosts;
my $numFoundSpam = 0;
my $deletedSpam = 0;

for my $subdir ('A'..'Z', 'misc') {
    my $dir = "$dataDir/$subdir";
    next unless (-e $dir);
    die "Error: $dir not a directory!\n" if (!-d $dir);
    my %tiedDir;
    if (tie %tiedDir, 'IO::Dir', $dir) {
        for my $entry (keys %tiedDir) {
            next if ($entry =~ /^\.+$/);
            # all files in $dir must be a directory
            if (!-d "$dir/$entry") {
                if ($opts{'b'} or &yesNo("Warning: $dir/$entry not a directory.  Delete?")) {
                    unlink("$dir/$entry");
                    print STDERR "$dir/$entry deleted.\n";
                }
            }
            # $entry is in wrong subdir
            elsif ( (($subdir ne 'misc') and
                     (substr($entry, 0, 1) ne $subdir)) or
                    (($subdir eq 'misc') and ($entry =~ /^[A-Z]/)) ) {
                if ($opts{'b'} or &yesNo("Warning: $entry does not belong in $dir.  Move?")) {
                    my $first = substr($entry, 0, 1);
                    my $newDir = ($first =~ /^[A-Z]$/) ? $first : 'misc';
                    if (!-e "$dataDir/$newDir") {
                        print STDERR "Creating $dataDir/$newDir\n";
                        mkdir "$dataDir/$newDir";
                    }
                    move("$dir/$entry", "$dataDir/$newDir/$entry");
                    print STDERR "$entry moved to $dataDir/$newDir.  ";
                    print STDERR "You'll need to run this script again.\n";
                }
            }
            # traverse page directory
            else {
                my %pageDir;
                if (tie %pageDir, 'IO::Dir', "$dir/$entry") {
                    my $seenCurrent = 0;
                    my %txt;
                    my %meta;
                    for my $file (keys %pageDir) {
                        next if ($file =~ /^\.+$/);
                        # inappropriately named files
                        if ( ($file !~ /^\d+\.(txt|meta)$/) and
                             ($file ne 'current') ) {
                            if ($opts{'b'} or &yesNo("Warning: $file does not belong in $dir/$entry.  Delete?")) {
                                unlink("$dir/$entry/$file");
                                print STDERR "$dir/$entry/$file deleted\n";
                            }
                        }
                        # file is a directory
                        elsif (-d "$dir/$entry/$file") {
                            die "Error: $dir/$entry/$file is a directory\n";
                        }
                        elsif ($file eq 'current') {
                            $seenCurrent = 1;
                        }
                        elsif ($file =~ /^(\d+)\.txt$/) {
                            $txt{$1} = 1;
                        }
                        elsif ($file =~ /^(\d+)\.meta$/) {
                            $meta{$1} = 1;
                        }
                    }
                    # should be a meta corresponding to each txt...
                    foreach my $num (keys %txt) {
                        if (!$meta{$num}) {
                            if ($opts{'b'} or &yesNo("Warning: No corresponding meta file for $num.txt.  Create?")) {
                                &createMetaFile($entry, $num);
                                $meta{$num} = 1;
                                print STDERR "Meta file created.\n";
                            }
                        }
                    }
                    # ... and vice-versa
                    foreach my $num (keys %meta) {
                        if (!$txt{$num}) {
                            if ($opts{'b'} or &yesNo("Warning: No corresponding txt file for $num.meta.  Delete?")) {
                                unlink("$dir/$entry/$num.meta");
                                delete $meta{$num};
                                print STDERR "Meta file deleted.\n";
                            }
                        }
                        # check integrity of meta file
                        else {
                            my $timeStamp = &checkMetaFile("$dir/$entry/$num.meta");
                            if (!$timeStamp) {
                                if ($opts{'b'} or &yesNo("Warning: $dir/$entry/$num.meta is bad.  Delete rev $num?")) {
                                    unlink("$dir/$entry/$num.txt");
                                    unlink("$dir/$entry/$num.meta");
                                    delete $txt{$num};
                                    delete $meta{$num};
                                    print STDERR "Text and meta files deleted.\n";
                                }
                            }
                            else {  # check timestamp of txt file
                                my @finfo = stat("$dir/$entry/$num.txt");
                                if ($finfo[9] != $timeStamp) {
                                    utime($timeStamp, $timeStamp, "$dir/$entry/$num.txt");
                                    print STDERR "Changed timestamp of $num.txt to correspond to meta file.\n";
                                }
                            }
                        }
                    }
                    # identify and possibly remove spammed revisions
                    my @revisions = sort { $a <=> $b} keys %txt;
                    my $pageSpamFreeRev = 0;
                    if ($opts{'s'}) {
                        my @spammedRevs;
                        for my $rev (@revisions) {
                            my $foundSpam = 0;
                            undef $/;
                            open(REV, "$dir/$entry/$rev.txt");
                            my $content = <REV>;
                            close(REV);
                            $/ = "\n";
                            foreach my $re (@spamRegexps) {
                                if ($content =~ /$re/) {
                                    $foundSpam = 1;
                                    last;
                                }
                            }
                            if ($foundSpam) {
                                push @spammedRevs, $rev;
                                my ($uid, $host) = &getMetaInfo("$dir/$entry/$rev.meta");
                                $spammerUserIds{$uid} = 1 if ($uid);
                                $spammerHosts{$host} = 1 if ($host);
                                $numFoundSpam++;
                            }
                            else {
                                $pageSpamFreeRev = 1;
                            }
                        }
                        if (scalar @spammedRevs > 0) {
                            if (!$pageSpamFreeRev) {
                                print STDERR "WARNING: $entry does not have a spam-free rev\n";
                            }
                            elsif ($opts{'b'} or &yesNo("Remove spam from $entry?")) {
                                foreach my $rev (@spammedRevs) {
                                    unlink("$dir/$entry/$rev.txt");
                                    unlink("$dir/$entry/$rev.meta");
                                    delete $txt{$rev};
                                    delete $meta{$rev};
                                    print STDERR "Deleted spammed rev $rev of $entry\n";
                                    $deletedSpam++;
                                }
                            }
                            else {
                                foreach my $rev (@spammedRevs) {
                                    print STDERR "Suspected spam in rev $rev of $entry\n";
                                }
                            }
                        }
                    }
                    # remove duplicate revisions
                    @revisions = sort { $a <=> $b} keys %txt;
                    my $prevRev = shift @revisions;
                    foreach my $rev (@revisions) {
                        if (!diff("$dir/$entry/$prevRev.txt", "$dir/$entry/$rev.txt")) {
                            if ($opts{'b'} or &yesNo("$prevRev and $rev for $entry are identical.  Remove $rev?")) {
                                    unlink("$dir/$entry/$rev.txt");
                                    unlink("$dir/$entry/$rev.meta");
                                    delete $txt{$rev};
                                    delete $meta{$rev};
                                    print STDERR "Deleted duplicate rev $rev of $entry\n";
                            }
                            else {
                                $prevRev = $rev;
                            }
                        }
                        else {
                            $prevRev = $rev;
                        }
                    }
                    # if files are out of order, smoosh them down
                    @revisions = sort { $a <=> $b} keys %txt;
                    my $i = 1;
                    my $lastRev;
                    for my $rev (@revisions) {
                        if ($rev != $i) {
                            print STDERR "Renaming $entry rev $rev to $i.\n";
                            move("$dir/$entry/$rev.txt", "$dir/$entry/$i.txt");
                            move("$dir/$entry/$rev.meta", "$dir/$entry/$i.meta");
                        }
                        $i++;
                        $lastRev = $rev;
                    }
                    # update current, timestamps
                    if (!$seenCurrent) {
                        &createCurrentFile($entry, $lastRev);
                        print STDERR "Created current file for $entry.\n";
                    }
                    else {
                        open(CURRENT, "$dir/$entry/current");
                        my $rev = <CURRENT>;
                        close(CURRENT);
                        chomp $rev;
                        if ($rev != $lastRev) {
                            unlink("$dir/$entry/current");
                            &createCurrentFile($entry, $lastRev);
                            print STDERR "Corrected current file for $entry.\n";
                        }
                    }
                }
                else {  # can't open page dir
                    print STDERR "Warning: Cannot open $dir/$entry!\n";
                }
            }
        }
    }
    else {  # can't open $dir
        print STDERR "Warning: Cannot open $dir!\n";
    }
}
foreach my $userId (sort keys %spammerUserIds) {
    print STDERR "Suspected spammer user ID: $userId\n";
}
foreach my $host (sort keys %spammerHosts) {
    print STDERR "Suspected spammer host: $host\n";
}
print STDERR "Found $numFoundSpam suspected spam.\n";
print STDERR "Deleted $deletedSpam deleted spam.\n";

### subroutines

sub getSpamRegexps {
    my $file = shift;
    my @re;

    if (open(SPAMRE, $file)) {
        while (my $line = <SPAMRE>) {
            chomp $line;
            push @re, $line;
        }
        close(SPAMRE);
    }
    return @re;
}

sub getMetaInfo {  # just user ID and host
    my $file = shift;

    my ($changeSummary, $host, $timeStamp, $userId);
    if (open(META, $file)) {
        while (my $line = <META>) {
            chomp $line;
            if ($line =~ /^changeSummary=(.*)$/) {
                $changeSummary = $1;
            }
            elsif ($line =~ /^host=(.*)$/) {
                $host = $1;
            }
            elsif ($line =~ /^timeStamp=(.*)$/) {
                $timeStamp = $1;
            }
            elsif ($line =~ /^userId=(.*)$/) {
                $userId = $1;
            }
        }
    }
    return ($userId, $host);
}

sub checkMetaFile {
    my $file = shift;

    my ($changeSummary, $host, $timeStamp, $userId);
    if (open(META, $file)) {
        my $line = <META>;
        if (!$line) {
            return 0;
        }
        do {
            chomp $line;
            if ($line =~ /^changeSummary=(.*)$/) {
                if ($changeSummary) {
                    return 0;
                }
                else {
                    $changeSummary = $1;
                }
            }
            elsif ($line =~ /^host=(.*)$/) {
                if ($host) {
                    return 0;
                }
                else {
                    $host = $1;
                }
            }
            elsif ($line =~ /^timeStamp=(.*)$/) {
                if ($timeStamp) {
                    return 0;
                }
                else {
                    $timeStamp = $1;
                }
            }
            elsif ($line =~ /^userId=(.*)$/) {
                if ($userId) {
                    return 0;
                }
                else {
                    $userId = $1;
                    # TODO: check for user remapping here
                }
            }
            else {  # bad data
                return 0;
            }
        } while ($line = <META>);
    }
    else {
        return 0;
    }
    return $timeStamp;
}

sub createCurrentFile {
    my ($name, $rev) = @_;

    my $subDir = substr($name, 0, 1);
    if ($subDir !~ /^[A-Z]$/) {
        $subDir = 'misc';
    }
    open(CURRENT, ">$dataDir/$subDir/$name/current");
    print CURRENT "$rev\n";
    close(CURRENT);
}

sub createMetaFile {
    my ($name, $rev) = @_;

    my $subDir = substr($name, 0, 1);
    if ($subDir !~ /^[A-Z]$/) {
        $subDir = 'misc';
    }
    open(META, ">$dataDir/$subDir/$name/$rev.meta");
    print META "changeSummary=\n";
    print META "host=\n";
    print META "timeStamp=" . time . "\n";
    print META "userId=\n";
    close(META);
}

sub yesNo {
    my $msg = shift;
    my $response;

    do {
        print "$msg (y/n) ";
        $response = <STDIN>;
        chomp $response;
        $response = lc($response);
    } while (($response ne 'y') and ($response ne 'n'));
    return ($response eq 'y') ? 1 : 0;
}

### fini

__END__
=head1 NAME

plaintextIntegrity.pl - Checks integrity of PlainText backend.

=head1 SYNOPSIS

  plaintextIntegrity.pl [-b] [-s spamregexp.txt] wikidb

=head1 DESCRIPTION

Does a series of checks to make sure the PlainText files in wikidb are
valid.

-b runs in batch mode.

You can specify a file containing regular expressions commonly found
in spam by using the -s switch.  If these expressions match, this
script will give you the option of deleting those files, assuming that
a spam-free revision exists.

=head1 AUTHOR

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
