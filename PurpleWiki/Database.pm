# PurpleWiki::Database.pm
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Database.pm,v 1.1.2.9 2003/01/31 06:22:08 cdent Exp $
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

# $Id: Database.pm,v 1.1.2.9 2003/01/31 06:22:08 cdent Exp $

use strict;
use PurpleWiki::Config;

sub ReadFileOrDie {
  my $fileName = shift;
  my ($status, $data);

  ($status, $data) = &ReadFile($fileName);
  if (!$status) {
    die("Can not open $fileName: $!");
  }
  return $data;
}

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

sub CreateDir {
    my $newdir = shift;

    mkdir($newdir, 0775)  if (!(-d $newdir));
}

sub GetDiff {
    my ($old, $new, $lock) = @_;
    my ($diff_out, $oldName, $newName);

    &CreateDir($TempDir);
    $oldName = "$TempDir/old_diff";
    $newName = "$TempDir/new_diff";
    if ($lock) {
        &RequestDiffLock() or return "";
        $oldName .= "_locked";
        $newName .= "_locked";
    }
    &WriteStringToFile($oldName, $old);
    &WriteStringToFile($newName, $new);
    $diff_out = `diff $oldName $newName`;
    &ReleaseDiffLock()  if ($lock);
    $diff_out =~ s/\\ No newline.*\n//g;   # Get rid of common complaint.
    # No need to unlink temp files--next diff will just overwrite.
    return $diff_out;
}

sub RequestLockDir {
    my ($name, $tries, $wait, $errorDie) = @_;
    my ($lockName, $n);

    &CreateDir($TempDir);
    $lockName = $LockDir . $name;
    $n = 0;
    while (mkdir($lockName, 0555) == 0) {
        if ($! != 17) {
            die("can not make $LockDir: $!\n")  if $errorDie;
            return 0;
        }
        return 0  if ($n++ >= $tries);
        sleep($wait);
    }
    return 1;
}

sub ReleaseLockDir {
    my ($name) = @_;
    rmdir($LockDir . $name);
}

sub RequestLock {
    # 10 tries, 3 second wait, die on error
    return &RequestLockDir("main", 10, 3, 1);
}

sub ReleaseLock {
    &ReleaseLockDir('main');
}

sub ForceReleaseLock {
    my ($name) = @_;
    my $forced;

    # First try to obtain lock (in case of normal edit lock)
    # 5 tries, 3 second wait, do not die on error
    $forced = !&RequestLockDir($name, 5, 3, 0);
    &ReleaseLockDir($name);  # Release the lock, even if we didn't get it.
    return $forced;
}

sub RequestDiffLock {
    # 4 tries, 2 second wait, do not die on error
    return &RequestLockDir('diff', 4, 2, 0);
}

sub ReleaseDiffLock {
    &ReleaseLockDir('diff');
}

sub WriteStringToFile {
    my $file = shift;
    my $string = shift;

    open (OUT, ">$file") or die("can't write $file: $!");
    print OUT  $string;
    close(OUT);
 }

sub AppendStringToFile {
    my ($file, $string) = @_;

    open (OUT, ">>$file") or die("can't write $file $!");
    print OUT  $string;
    close(OUT);
}

sub AllPagesList {
    my (@pages, @dirs, $id, $dir, @pageFiles, @subpageFiles, $subId);

    @pages = ();
    # The following was inspired by the FastGlob code by Marc W. Mengel.
    # Thanks to Bob Showalter for pointing out the improvement.
    opendir(PAGELIST, $PageDir);
    @dirs = readdir(PAGELIST);
    closedir(PAGELIST);
    @dirs = sort(@dirs);
    foreach $dir (@dirs) {
        next  if (($dir eq '.') || ($dir eq '..'));
        opendir(PAGELIST, "$PageDir/$dir");
        @pageFiles = readdir(PAGELIST);
        closedir(PAGELIST);
        foreach $id (@pageFiles) {
            next  if (($id eq '.') || ($id eq '..'));
            if (substr($id, -3) eq '.db') {
                push(@pages, substr($id, 0, -3));
            } elsif (substr($id, -4) ne '.lck') {
                opendir(PAGELIST, "$PageDir/$dir/$id");
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

sub UpdateDiffs {
    my $page = shift;
    my $keptRevision = shift;
    my ($id, $editTime, $old, $new, $isEdit, $newAuthor) = @_;
    my ($editDiff, $oldMajor, $oldAuthor);

    $editDiff  = &GetDiff($old, $new, 0);     # 0 = already in lock
    $oldMajor  = $page->getPageCache('oldmajor');
    $oldAuthor = $page->getPageCache('oldauthor');
    if ($UseDiffLog) {
        &WriteDiff($id, $editTime, $editDiff);
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

sub GetCacheDiff {
  my ($page, $type) = @_;
  my ($diffText);

  $diffText = $page->getPageCache("diff_default_$type");
  $diffText = &GetCacheDiff($page, 'minor')  if ($diffText eq "1");
  $diffText = &GetCacheDiff($page, 'major')  if ($diffText eq "2");
  return $diffText;
}

sub GetKeptDiff {
    my $keptRevision = shift;
    my ($newText, $oldRevision, $lock) = @_;

    my $section = $keptRevision->getRevision($oldRevision);
    my $oldText = $section->getText()->getText();

    return ""  if ($oldText eq "");  # Old revision not found
    return &GetDiff($oldText, $newText, $lock);
}

sub WriteDiff {
    my ($id, $editTime, $diffString) = @_;

    open (OUT, ">>$DataDir/diff_log") or die('can not write diff_log');
    print OUT  "------\n" . $id . "|" . $editTime . "\n";
    print OUT  $diffString;
    close(OUT);
}


1;
