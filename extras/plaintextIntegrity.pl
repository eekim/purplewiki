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
use IO::Dir;

my $dataDir = shift @ARGV;
die "Usage: $0 wikidb" unless $dataDir;
$dataDir =~ s/\/$//;

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
                if (&yesNo("Warning: $dir/$entry not a directory.  Delete?")) {
                    unlink("$dir/$entry");
                    print "$dir/$entry deleted.\n";
                }
            }
            # $entry is in wrong subdir
            elsif ( (($subdir ne 'misc') and
                     (substr($entry, 0, 1) ne $subdir)) or
                    (($subdir eq 'misc') and ($entry =~ /^[A-Z]/)) ) {
                if (&yesNo("Warning: $entry does not belong in $dir.  Move?")) {
                    my $first = substr($entry, 0, 1);
                    my $newDir = ($first =~ /^[A-Z]$/) ? $first : 'misc';
                    if (!-e "$dataDir/$newDir") {
                        print "Creating $dataDir/$newDir\n";
                        mkdir "$dataDir/$newDir";
                    }
                    move("$dir/$entry", "$dataDir/$newDir/$entry");
                    print "$entry moved to $dataDir/$newDir.  ";
                    print "You'll need to run this script again.\n";
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
                            if (&yesNo("Warning: $file does not belong in $dir/$entry.  Delete?")) {
                                unlink("$dir/$entry/$file");
                                print "$dir/$entry/$file deleted\n";
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
                            if (&yesNo("Warning: No corresponding meta file for $num.txt.  Create?")) {
                                &createMetaFile($entry, $num);
                                $meta{$num} = 1;
                                print "Meta file created.\n";
                            }
                        }
                    }
                    # ... and vice-versa
                    foreach my $num (keys %meta) {
                        if (!$txt{$num}) {
                            if (&yesNo("Warning: No corresponding txt file for $num.meta.  Delete?")) {
                                unlink("$dir/$entry/$num.meta");
                                delete $meta{$num};
                                print "Meta file deleted.\n";
                            }
                        }
                        # check integrity of meta file
                        else {
                            my $timeStamp = &checkMetaFile("$dir/$entry/$num.meta");
                            if (!$timeStamp) {
                                if (&yesNo("Warning: $dir/$entry/$num.meta is bad.  Delete rev $num?")) {
                                    unlink("$dir/$entry/$num.txt");
                                    unlink("$dir/$entry/$num.meta");
                                    delete $txt{$num};
                                    delete $meta{$num};
                                    print "Text and meta files deleted.\n";
                                }
                            }
                            else {  # check timestamp of txt file
                                my @finfo = stat("$dir/$entry/$num.txt");
                                if ($finfo[9] != $timeStamp) {
                                    utime($timeStamp, $timeStamp, "$dir/$entry/$num.txt");
                                    print "Changed timestamp of $num.txt to correspond to meta file.\n";
                                }
                            }
                        }
                    }
                    # if files are out of order, smoosh them down
                    my @revisions = sort keys %txt;
                    my $i = 1;
                    my $lastRev;
                    for my $rev (@revisions) {
                        if ($rev != $i) {
                            print "Renaming $entry rev $rev to $i.\n";
                            move("$dir/$entry/$rev.txt", "$dir/$entry/$i.txt");
                            move("$dir/$entry/$rev.meta", "$dir/$entry/$i.meta");
                        }
                        $i++;
                        $lastRev = $rev;
                    }
                    # update current, timestamps

                    my $timeStamp = &checkMetaFile("$dir/$entry/$lastRev.meta");
                    my @finfo = stat("$dir/$entry");
                    if ($finfo[9] != $timeStamp) {
                        utime($timeStamp, $timeStamp, "$dir/$entry");
                        print "Updated timestamp of $dir/$entry.\n";
                    }
                }
                else {  # can't open page dir
                    print "Warning: Cannot open $dir/$entry!\n";
                }
            }
        }
    }
    else {  # can't open $dir
        print "Warning: Cannot open $dir!\n";
    }
}

### subroutines

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

  plaintextIntegrity.pl wikidb

=head1 DESCRIPTION

Does a series of checks to make sure the PlainText files in wikidb are
valid.

=head1 AUTHOR

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
