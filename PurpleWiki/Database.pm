# PurpleWiki::Database.pm
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Database.pm,v 1.4 2003/06/24 22:22:29 cdent Exp $
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

package PurpleWiki::Database;

# PurpleWiki Page Data Access

# $Id: Database.pm,v 1.4 2003/06/24 22:22:29 cdent Exp $

use strict;

# Reads a string from a given filename and returns the data.
# If it cannot open the file, it dies with an error.
# Public
sub ReadFileOrDie {
  my $fileName = shift;
  my ($status, $data);

  ($status, $data) = &ReadFile($fileName);
  if (!$status) {
    die("Can not open $fileName: $!");
  }
  return $data;
}

# Reads a string from a given filename and returns a
# status value and the string. 1 for success, 0 for 
# failure.
# Public
sub ReadFile {
  my $fileName = shift;
  my ($data);
  local $/ = undef;   # Read complete files

  if (open(IN, "<$fileName")) {
    $data=<IN>;
    close IN;
    return (1, $data);
  }
  return (0, "");
}

# Creates a directory if it doesn't already exist.
# FIXME: there should be some error checking here.
# Public
sub CreateDir {
    my $newdir = shift;

    mkdir($newdir, 0775)  if (!(-d $newdir));
}

# Creates a diff using Text::Diff
# We require it in here rather than at the top in
# case we never need it in the current running
# process.
# Private
sub _GetDiff {
    require Text::Diff;
    my ($old, $new, $lock) = @_;

    my $diff_out = Text::Diff::diff(\$old, \$new, {STYLE => "OldStyle"});
    return $diff_out;
}

# Creates a directory that acts as a general locking
# mechanism for the system.
# FIXME: ForceReleaseLock (below) is not immediately accessible
# to mortals.
# Private.
sub _RequestLockDir {
    my ($name, $tries, $wait, $errorDie, $config) = @_;
    my ($lockName, $n);

    &CreateDir($config->TempDir);
    $lockName = $config->LockDir . $name;
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
    my ($name, $config) = @_;
    rmdir($config->LockDir . $name);
}

# Requests a general editing lock for the system.
# Public
sub RequestLock {
    my $config = shift;
    # 10 tries, 3 second wait, die on error
    return &_RequestLockDir("main", 10, 3, 1, $config);
}

# Releases the general editing lock
# Public
sub ReleaseLock {
    my $config = shift;
    &_ReleaseLockDir('main', $config);
}

# Forces the lock to be released
# Public
sub ForceReleaseLock {
    my ($name, $config) = @_;
    my $forced;

    # First try to obtain lock (in case of normal edit lock)
    # 5 tries, 3 second wait, do not die on error
    $forced = !&_RequestLockDir($name, 5, 3, 0, $config);
    &_ReleaseLockDir($name, $config);  # Release the lock, even if we didn't get it.
    return $forced;
}

# Writes the given string to the given file. Dies
# if it can't write.
# Public
sub WriteStringToFile {
    my $file = shift;
    my $string = shift;

    open (OUT, ">$file") or die("can't write $file: $!");
    print OUT  $string;
    close(OUT);
 }

# Not used?
sub AppendStringToFile {
    my ($file, $string) = @_;

    open (OUT, ">>$file") or die("can't write $file $!");
    print OUT  $string;
    close(OUT);
}

# Creates and returns an array containing a list of all the
# wiki pages in the database.
# Public
sub AllPagesList {
    my $config = shift;
    my (@pages, @dirs, $id, $dir, @pageFiles, @subpageFiles, $subId);

    @pages = ();
    # The following was inspired by the FastGlob code by Marc W. Mengel.
    # Thanks to Bob Showalter for pointing out the improvement.
    opendir(PAGELIST, $config->PageDir);
    @dirs = readdir(PAGELIST);
    closedir(PAGELIST);
    @dirs = sort(@dirs);
    foreach $dir (@dirs) {
        next  if (($dir eq '.') || ($dir eq '..'));
        my $directory = $config->PageDir . "/$dir";
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
                    if (substr($subId, -3) eq '.db') {
                        push(@pages, "$id/" . substr($subId, 0, -3));
                    }
                }
            }
        }
    }
    return sort(@pages);
}

# Updates the diffs keps for a page.
# Public
sub UpdateDiffs {
    my $page = shift;
    my $keptRevision = shift;
    my ($id, $editTime, $old, $new, $isEdit, $newAuthor, $config) = @_;
    my ($editDiff, $oldMajor, $oldAuthor);

    $editDiff  = &_GetDiff($old, $new, 0);     # 0 = already in lock
    $oldMajor  = $page->getPageCache('oldmajor');
    $oldAuthor = $page->getPageCache('oldauthor');
    if ($config->UseDiffLog) {
        &_WriteDiff($id, $editTime, $editDiff, $config);
    }
    $page->setPageCache('diff_default_minor', $editDiff);

    if (!$isEdit) {
        $page->setPageCache('diff_default_major', "1");
    } else {
        $page->setPageCache('diff_default_major',
            &GetKeptDiff($keptRevision, $new, $oldMajor, 0));
    }

    if ($newAuthor) {
        $page->setPageCache('diff_default_author', "1");
    } elsif ($oldMajor == $oldAuthor) {
        $page->setPageCache('diff_default_author', "2");
    } elsif ($oldMajor == $oldAuthor) {
        $page->setPageCache('diff_default_author', "2");
    } else {
        $page->setPageCache('diff_default_author',
            &GetKeptDiff($keptRevision, $new, $oldAuthor, 0));
    }
}

# Retrieves a cached diff for a page.
# Public
sub GetCacheDiff {
  my ($page, $type) = @_;
  my ($diffText);

  $diffText = $page->getPageCache("diff_default_$type");
  $diffText = &GetCacheDiff($page, 'minor')  if ($diffText eq "1");
  $diffText = &GetCacheDiff($page, 'major')  if ($diffText eq "2");
  return $diffText;
}

# Retrieves the diff of an old kept revision
# Public
sub GetKeptDiff {
    my $keptRevision = shift;
    my ($newText, $oldRevision, $lock) = @_;

    my $section = $keptRevision->getRevision($oldRevision);
    return "" if (!defined $section); # there is no old revision
    my $oldText = $section->getText()->getText();

    return ""  if ($oldText eq "");  # Old revision not found
    return &_GetDiff($oldText, $newText, $lock);
}

# Writes out a diff to the diff log.
# Private
sub _WriteDiff {
    my ($id, $editTime, $diffString, $config) = @_;

    my $directory = $config->DataDir;
    open (OUT, ">>$directory/diff_log") or die('can not write diff_log');
    print OUT  "------\n" . $id . "|" . $editTime . "\n";
    print OUT  $diffString;
    close(OUT);
}


1;
