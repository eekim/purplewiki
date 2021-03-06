# PurpleWiki::UseMod::Database.pm
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2003.  All rights reserved.
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

package PurpleWiki::UseMod::Database;

# PurpleWiki Page Data Access

# $Id$

use strict;
use PurpleWiki::Config;
use PurpleWiki::Misc;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

# Creates a directory that acts as a general locking
# mechanism for the system.
# FIXME: ForceReleaseLock (below) is not immediately accessible
# to mortals.
# Private.
sub _RequestLockDir {
    my ($name, $tries, $wait, $errorDie, $lockdir, $tempdir) = @_;
    my ($lockName, $n);
    my $config = PurpleWiki::Config->instance();

    if ($config) {
        $tempdir = $config->TempDir || $config->DataDir . "/temp";
        $lockdir = $config->LockDir || $config->DataDir . "/lock";
    } elsif (!$tempdir) {
        $tempdir = (m|/[^/]+$|) ? $` : '';
    }
    die("No lockdir") unless $lockdir;
    &PurpleWiki::Misc::CreateDir($tempdir);
    $lockName = $lockdir . $name;
    $n = 0;
    while (mkdir($lockName, 0555) == 0) {
        if ($! != 17) {
            die("can not make $lockName: $!\n")  if $errorDie;
            return 0;
        }
        return 0  if ($n++ >= $tries);
        sleep($wait);
    }
    return 1;
}

# Removes the locking directory, destroying the lock
# Private
sub _ReleaseLockDir {
    my ($name, $lockdir) = @_;
    my $config = PurpleWiki::Config->instance();
    if ($config) {
        $lockdir = $config->LockDir || $config->DataDir . "/lock";
    }
    die("No lockdir") unless $lockdir;
    rmdir($lockdir . $name);
}

# Requests a general editing lock for the system.
# Public
sub RequestLock {
    # 10 tries, 3 second wait, die on error
    return _RequestLockDir("main", 10, 3, 1, @_);
}

# Releases the general editing lock
# Public
sub ReleaseLock {
    _ReleaseLockDir('main', @_);
}

# Forces the lock to be released
# Public
sub ForceReleaseLock {
    my ($name) = shift;
    my $forced;

    # First try to obtain lock (in case of normal edit lock)
    # 5 tries, 3 second wait, do not die on error
    $forced = !_RequestLockDir($name, 5, 3, 0, @_);
    _ReleaseLockDir($name, @_);  # Release the lock, even if we didn't get it.
    return $forced;
}

# Creates and returns an array containing a list of all the
# wiki pages in the database.
# Public
sub AllPagesList {
    my $pageDir = shift;
    my (@pages, @dirs, $id, $dir, @pageFiles, @subpageFiles, $subId);

    @pages = ();
    # The following was inspired by the FastGlob code by Marc W. Mengel.
    # Thanks to Bob Showalter for pointing out the improvement.
    opendir(PAGELIST, $pageDir);
    @dirs = readdir(PAGELIST);
    closedir(PAGELIST);
    @dirs = sort(@dirs);
    foreach $dir (@dirs) {
        next  if (($dir eq '.') || ($dir eq '..'));
        my $directory = "$pageDir/$dir";
        opendir(PAGELIST, $directory);
        @pageFiles = readdir(PAGELIST);
        closedir(PAGELIST);
        foreach $id (@pageFiles) {
            next  if (($id eq '.') || ($id eq '..'));
            if (substr($id, -3) eq '.db') {
                push(@pages, substr($id, 0, -3));
            } elsif (substr($id, -4) ne '.lck') {
                opendir(PAGELIST, "$directory/$id");
                @subpageFiles = readdir(PAGELIST);
                closedir(PAGELIST);
                foreach $subId (@subpageFiles) {
		    push(@pages, "$id/" . substr($subId, 0, -3))
                        if (substr($subId, -3) eq '.db');
                }
            }
        }
    }
    return sort @pages;
}

# Populates a hash reference with recent changes.
# Data structure:
#   $recentChanges = [
#     { timeStamp => ,   # time stamp
#       pageId => ,      # page Id
#       numChanges => ,  # number of times changed
#       changeSummary =>,# change summary
#       userName => ,    # username
#       userId => ,      # user ID
#       host => ,        # hostname
#     },
#     ...
#   ]
sub recentChanges {
    my ($config, $timeStamp) = @_;
    my @recentChanges;
    my %pages;

    # Default to showing all changes.
    $timeStamp = 0 if not defined $timeStamp;

    # Convert timeStamp to seconds since the epoch if it's not already in
    # that form.
    if (not $timeStamp =~ /^\d+$/) {
        use Date::Manip;
        $timeStamp = abs(UnixDate($timeStamp, "%o")) || 0;
    }

    ### FIXME: There's also an OldRcFile.  Should we read this also?
    ### What is it for, anyway?
    if (open(IN, $config->RcFile)) {
    # parse logfile into pages hash
        while (my $logEntry = <IN>) {
            chomp $logEntry;
            my $fsexp = $PurpleWiki::Archive::UseMod::fs3;
            my @entries = split /$fsexp/, $logEntry;
            if (scalar @entries >= 6 && $entries[0] >= $timeStamp) {  # Check timestamp
                my $name = $entries[1];
                my $pageName = $name;

                if ($config->FreeLinks) {
                    $pageName =~ s/_/ /g;
                }
                if ( $pages{$name} &&
                    ($pages{$name}->{timeStamp} > $entries[0]) ) {
                    $pages{$name}->{numChanges}++;
                }
                else {
                    if ($pages{$name}) {
                        $pages{$name}->{numChanges}++;
                    }
                    else {
                        $pages{$name}->{numChanges} = 1;
                        $pages{$name}->{pageName} = $pageName;
                    }
                    $pages{$name}->{timeStamp} = $entries[0];
                    if ($entries[2] ne '' && $entries[2] ne '*') {
                        $pages{$name}->{summary} = $entries[2];
                    }
                    else {
                        $pages{$name}->{summary} = '';
                    }
                    $pages{$name}->{minorEdit} = $entries[3];
                    $pages{$name}->{host} = $entries[4];

                    # $entries[5] is garbage and so we ignore it...

                    # Get extra info
                    my $fsexp = $PurpleWiki::Archive::UseMod::fs2;
                    my %userInfo = split /$fsexp/, $entries[6];
                    if ($userInfo{id}) {
                        $pages{$name}->{userId} = $userInfo{id};
                    }
                    else {
                        $pages{$name}->{userId} = '';
                    }
                    if ($userInfo{name}) {
                        $pages{$name}->{userName} = $userInfo{name};
                    }
                    else {
                        $pages{$name}->{userName} = '';
                    }
                }
            }
        }
        close(IN);

    }
    # now parse pages hash into final data structure and return
    foreach my $name (sort { $pages{$b}->{timeStamp} <=> $pages{$a}->{timeStamp} } keys %pages) {
        push @recentChanges, { timeStamp => $pages{$name}->{timeStamp},
                               pageId => $name,
                               numChanges => $pages{$name}->{numChanges},
                               changeSummary => $pages{$name}->{summary},
                               userName => $pages{$name}->{userName},
                               userId => $pages{$name}->{userId},
                               host => $pages{$name}->{host} };
    }
    return \@recentChanges;
}

1;
