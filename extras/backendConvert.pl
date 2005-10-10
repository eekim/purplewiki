#!/usr/bin/perl -w
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# backendConvert.pl - PurpleWiki
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2004.  All rights reserved.
#
# Converts data from one backend format to another.

package UseModWiki;  # nasty hack

use lib '/home/eekim/devel/PurpleWiki/trunk';
use strict;
use File::Copy;
use Getopt::Std;
use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Sequence;
use PurpleWiki::Archive::Sequence;

### read parameters

my %opts;
getopts('chvrs:o:n:', \%opts);

my $oldBackend = ($opts{'o'}) ? $opts{'o'} : 'PurpleWiki::Archive::UseMod';
my $newBackend = ($opts{'n'}) ? $opts{'n'} : 'PurpleWiki::Archive::PlainText';
my $verbose = $opts{'v'};
my $copySeq = !$opts{'c'};

if ($opts{'h'} || scalar @ARGV < 3) {
    print "Usage:\n";
    print "    $0 [-v] [-o oldBackend] [-n newBackend] \\\n";
    print "        [-s sequenceDir] oldDataDir newDataDir baseUrl\n";
    exit -1;
}

my $oldDataDir = shift @ARGV;
my $newDataDir = shift @ARGV;
my $url = shift @ARGV;
my $sequenceDir = $opts{'s'} || $newDataDir;

### create page objects

local $| = 1;  # Do not buffer output

print "Database Package $newBackend\nError: $@\n"
    unless (defined(eval "require $newBackend"));
my $newpages = $newBackend->new(DataDir => $newDataDir,
                                SequenceDir => $sequenceDir,
                                create => 1);
$newpages || die "Can't open input database $newDataDir\n";
    # Object representing a page database

print "Database Package $oldBackend\nError: $@\n"
    unless (defined(eval "require $oldBackend"));
my $pages = $oldBackend->new(DataDir => $oldDataDir);
    # Object representing a page database

$pages || die "Can't open input database $oldDataDir\n";

### convert database

if ($copySeq) {
    copy("$oldDataDir/sequence", "$sequenceDir/sequence");
    copy("$oldDataDir/sequence.index", "$sequenceDir/sequence.index");
}

my ($rev, $host, $summary, $user);
my %all = ();
for my $id ($pages->allPages()) {
  for ($pages->getRevisions($id)) {
    my ($rev, $host, $summary, $userId, $pageTime)
      = ($_->{revision}, $_->{host}, $_->{summary}, $_->{userId}, $_->{dateTime});
    while (1) {
      unless (defined($all{$pageTime})) {
        $all{$pageTime} = [ $id, $rev, $host, $summary, $userId ];
        last;
      }
      print "Dup time: $pageTime\n" if ($verbose);
      $pageTime++;
    }
  }
}

my $err;
my $goodCount = 0;
my $badCount = 0;

for my $pageTime (sort { $b <=> $a } (keys %all)) {
    my ($id, $rev, $host, $summary, $userId) = @{$all{$pageTime}};
    my $page = $pages->getPage($id, $rev);
    print "$id, $rev\n" if $verbose;
    if ($err = $newpages->putPage( pageId => $id,
                                   tree => $page->getTree(),
                                   changeSummary => $summary,
                                   host => $host,
                                   timeStamp => $pageTime,
                                   userId => $userId,
				   )) {
#                                   url => "$url?$id")) {
        print "$id :: $rev -> $err\n";
        $badCount++;
    }
    else {
        $goodCount++;
    }
}

print "Copy $goodCount records ($badCount errors)\n";

### more nasty hack

sub TimeToText { return shift; }
sub QuoteHtml { return shift; }

### fini

__END__
=head1 NAME

backendConvert.pl - Converts data into a different backend format

=head1 SYNOPSIS

  backendConvert.pl [-v] [-o oldBackend] [-n newBackend] [-u url] \
      [-s sequenceDir ] oldDataDir newDataDir baseUrl

defaults:
fromBackend = UseMod
toBackend = PlainText
sequenceDir = newDataDir
v = verbose (0)
c = copy (don't copy if -c present)

=head1 DESCRIPTION

Reads all Wiki page revisions and writes them to a new page archive with a
different archive module.  Also copies and re-inserts to the sequence index
(after optionally copying the sequence index and current).

=head1 AUTHORS

Gerry Gleason, E<lt>gerry@geraldgleason.comE<gt>
Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
