#!/usr/bin/perl
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# sequenceIndex.pl - PurpleWiki
#
# $Id: sequenceIndex.pl 535  $
#
# Copyright (c) Blue Oxen Associates 2002.  All rights reserved.
#
# This file is part of PurpleWiki.  PurpleWiki is derived from:
#
#   UseModWiki v0.92          (c) Clifford A. Adams 2000-2001
#   AtisWiki v0.3             (c) Markus Denker 1998
#   CVWiki CVS-patches        (c) Peter Merel 1997
#   The Original WikiWikiWeb  (c) Ward Cunningham
#
# PurpleWiki is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA

BEGIN {unshift(@INC,"/home/gerry/purple/blueoxen/branches/database-api-1");}

use strict;
use PurpleWiki::Sequence;
use PurpleWiki::Archive::Sequence;

our $VERSION;
$VERSION = sprintf("%d", q$Id: sequenceIndex.pl 535 2004-11-04 07:06:22Z gerry $ =~ /\s(\d+)\s/);

my $dataDir='.';
my $sequencDir='.';
my $backend='PurpleWiki::Archive::PlainText';
my $url = '';
my $verb=0;
while (@ARGV) {
  $a = shift(@ARGV);
  if ($a =~ /^-v/) {
    $verb = 1;
  } elsif ($a =~ /^-u/) {
    $url = $' || shift(@ARGV);
  } elsif ($a =~ /^-d/) {
    $dataDir = $' || shift(@ARGV);
  } elsif ($a =~ /^-b/) {
    $backend = $' || shift(@ARGV);
    if ($backend !~ /:/) {
        $backend = "PurpleWiki::Archive::$backend";
    }
  }
}

die "No url\n" unless $url;

local $| = 1;  # Do not buffer output

my $pages;

print STDERR "Database Package $backend\nError: $@\n"
    unless (defined(eval "require $backend"));
$pages = $backend->new(DataDir => $dataDir);
         # Object representing a page database

$pages || die "Can't open input database $dataDir\n";

my ($rev, $host, $summary, $user);
my %all = ();
my $maxNID = &PurpleWiki::Archive::Sequence::getCurrentValue($pages);
my $origNID = $maxNID;
my $count = 0;
for my $id ($pages->allPages()) {
    print "$count: $id $maxNID\n" if $verb;
    $count++;
    &PurpleWiki::Archive::Sequence::updateNIDs
        ($pages, $url."?$id", $id, \$maxNID);
}

&PurpleWiki::Archive::Sequence::setCurrentValue($pages, $maxNID, $origNID);
print "Max: $maxNID Count: $count\n";
