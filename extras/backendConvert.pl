#!/usr/bin/perl
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# convert.pl - PurpleWiki
#
# $Id$
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

package UseModWiki;
use strict;
use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;

my $CONFIG_DIR = $ENV{PW_CONFIG_DIR} || 'r';
my $NEW_CONFIG = 'new';

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

my $fromDataDir='';
my $toDataDir='';
my $fromBackend='PurpleWiki::Archive::UseMod.pm';
my $toBackend='PurpleWiki::Archive::PlainText.pm';
my $umask='';
my $verb=0;
while (@ARGV) {
  $a = shift(@ARGV);
  if ($a =~ /^-v/) {
    $verb = 1;
  } elsif ($a =~ /^-c/) {
    $fromDataDir = $' || shift(@ARGV);
  } elsif ($a =~ /^-C/) {
    $fromBackend = $' || shift(@ARGV);
    if ($fromBackend !~ /[:\.]/) {
        $fromBackend = "PurpleWiki::Archive::$fromBackend.pm";
    }
  } elsif ($a =~ /^-n/) {
    $toDataDir = $' || shift(@ARGV);
  } elsif ($a =~ /^-N/) {
    $toBackend = $' || shift(@ARGV);
    if ($toBackend !~ /[:\.]/) {
        $toBackend = "PurpleWiki::Archive::$toBackend.pm";
    }
  } elsif ($a =~ /^-u/) {
    $umask = $' || shift(@ARGV);
  }
}

local $| = 1;  # Do not buffer output

my $pages;
my $newpages;

my $wikiParser = PurpleWiki::Parser::WikiText->new;

umask(oct($umask)) if $umask;

print STDERR "Database Package $toBackend\nError: $@\n"
    unless (defined(eval "require $toBackend"));
$newpages = $toBackend->new(DataDir => $toDataDir, create => 1);
         # Object representing a page database

$newpages || die "Can't open input database $toDataDir\n";

print STDERR "Database Package $fromBackend\nError: $@\n"
    unless (defined(eval "require $fromBackend"));
$pages = $fromBackend->new($config);
         # Object representing a page database

$pages || die "Can't open input database $fromDataDir\n";

my ($rev, $host, $summary, $user);
my %all = ();
for my $id ($pages->allPages()) {
  for ($pages->getRevisions($id)) {
    my ($rev, $host, $summary, $user, $pageTime)
      = ($_->{revision}, $_->{host}, $_->{summary}, $_->{user}, $_->{dateTime});
    while (1) {
      unless (defined($all{$pageTime})) {
        $all{$pageTime} = [ $id, $rev, $host, $summary, $user ];
        last;
      }
      print STDERR "Dup time: $pageTime\n";
      $pageTime++;
    }
  }
}

my $err;
my $goodCount = 0;
my $badCount = 0;

for (sort { $a <=> $b } (keys %all)) {
  my ($id, $rev, $host, $summary, $user) = @{$all{$_}};
  my $page = $pages->getPage($id, $rev);
  print "$id, $rev\n" if $verb;
  if ($err = $newpages->putPage( pageId => $id,
                                 tree => $page->getTree(),
                                 changeSummary => $summary,
                                 host => $host,
                                 userId => $user )) {
    print STDERR "$id :: $rev -> $err\n";
    $badCount++;
  } else { $goodCount++; }
}

print STDERR "Copy $goodCount records ($badCount errors)\n";

sub TimeToText { return shift; }
sub QuoteHtml { return shift; }

