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

use strict;
use PurpleWiki::Sequence;
use PurpleWiki::Archive::Sequence;
use Getopt::Std;

our $VERSION;
$VERSION = sprintf("%d", q$Id: sequenceIndex.pl 535 2004-11-04 07:06:22Z gerry $ =~ /\s(\d+)\s/);

my %opts;
getopts('hvu:d:b:s:', \%opts);

my $url = ($opts{'u'}) ? $opts{'u'} : '';
my $dataDir = ($opts{'d'}) ? $opts{'d'} : '.';
my $sequenceDir = ($opts{'s'}) ? $opts{'s'} : $dataDir;
my $backend = ($opts{'b'}) ? $opts{'b'} : 'PurpleWiki::Archive::PlainText';
$backend = "PurpleWiki::Archive::$backend" if ($backend !~ /:/);
my $verbose = $opts{'v'};

ie "Usage: sequenceIndex.pl [-v] -u url [-d dataDir] [-s sequenceDir] [-b backend]\n"
   if ($opts{'h'} || !$url);

local $| = 1;  # Do not buffer output

my $pages;

print STDERR "Database Package $backend\nError: $@\n"
    unless (defined(eval "require $backend"));
$pages = $backend->new(DataDir => $dataDir, SequenceDir => $sequenceDir);
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
__END__
 
=head1 NAME
  
sequenceIndex.pl - Add index entries for a Wiki.
   
=head1 SYNOPSIS
    
sequenceIndex.pl [-v] -u url [-d dataDir] [-s sequenceDir] [-b backend]
       
=head1 DESCRIPTION
        
Generates index entries for a Wiki database and appends to the sequence index.
Updates the sequence number to max of current value and all NIDs loaded.
dataDir defaults to '.', and sequenceDir defaults to dataDir.  backend default
to PurpleWiki::Archive::Plaintext.  If backend doesn't have any ':' chars in
it, prepend PurpleWiki::Archive:: to it.
         
=head1 AUTHORS
          
Gerry Gleason, E<lt>gerry@geraldgleason.com<gt>
           
=cut
