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

my $verb=0;
while (@ARGV) {
  $a = shift(@ARGV);
  if ($a =~ /^-v/) {
    $verb = 1;
  } elsif ($a =~ /^-c/) {
    $CONFIG_DIR = $' || shift(@ARGV);
  } elsif ($a =~ /^-n/) {
    $NEW_CONFIG = $' || shift(@ARGV);
  }
}

local $| = 1;  # Do not buffer output (localized for mod_perl)

# we only need one of each these per run
my $newconfig = new PurpleWiki::Config($NEW_CONFIG);
my $config = new PurpleWiki::Config($CONFIG_DIR);

my $pages;
my $newpages;

my $wikiParser = PurpleWiki::Parser::WikiText->new;

# Set our umask if one was put in the config file. - matthew
umask(oct($config->Umask)) if defined $config->Umask;

my $new_database_package = $newconfig->DatabasePackage;
print STDERR "Database Package $new_database_package\nError: $@\n"
    unless (defined(eval "require $new_database_package"));
$newpages = $new_database_package->new($newconfig, create => 1);
         # Object representing a page database

$newpages || die "Can't open input database $NEW_CONFIG\n";
$newconfig->{pages} = $newpages;

print STDERR "NC:$newconfig\n";

my $database_package = $config->DatabasePackage;
print STDERR "Database Package $database_package\nError: $@\n"
    unless (defined(eval "require $database_package"));
$pages = $database_package->new($config);
         # Object representing a page database

$pages || die "Can't open input database $CONFIG_DIR\n";
$config->{pages} = $pages;   # use the config to store context vars for now
print STDERR "C:$config\n";

my ($rev, $host, $summary, $user);
my %all = ();
for my $p ($pages->allPages($config)) {
  my $id = $p->{id};
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

