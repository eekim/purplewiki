# PurpleWiki::Database.pm
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Database.pm,v 1.1.2.1 2003/01/24 12:18:22 cdent Exp $
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

# $Id: Database.pm,v 1.1.2.1 2003/01/24 12:18:22 cdent Exp $

use strict;
use PurpleWiki::Config;

# these should be made available as parameters
#my %KeptRevisions;
#my %Section;
#my %Text;
#my $UserID;
#my $Now; # definitely needs to be passed in as a parameter
my $OpenPageName;

sub OpenNewPage {
  my $id = shift;
  my $pagehash = shift;
  my $now = shift;

  $$pagehash{'version'} = 3;      # Data format version
  $$pagehash{'revision'} = 0;     # Number of edited times
  $$pagehash{'tscreate'} = $now;  # Set once at creation
  $$pagehash{'ts'} = $now;        # Updated every edit
}

sub OpenNewSection {
  my $name = shift;
  my $data = shift;
  my $userid = shift;
  my $username = shift;
  my $pagehash = shift;
  my $sectionhash = shift;
  my $now = shift;

  $$sectionhash{'name'} = $name;
  $$sectionhash{'version'} = 1;      # Data format version
  $$sectionhash{'revision'} = 0;     # Number of edited times
  $$sectionhash{'tscreate'} = $now;  # Set once at creation
  $$sectionhash{'ts'} = $now;        # Updated every edit
  $$sectionhash{'ip'} = $ENV{REMOTE_ADDR};
  $$sectionhash{'host'} = '';        # Updated only for real edits (can be slow)
  $$sectionhash{'id'} = $userid;
  $$sectionhash{'username'} = $username;
  $$sectionhash{'data'} = $data;
  $$pagehash{$name} = join($FS2, %$sectionhash);  # Replace with save?
}

sub OpenNewText {
  my $name = shift;  # Name of text (usually "default")
  my $userid = shift;
  my $username = shift;
  my $texthash = shift;
  my $pagehash = shift;
  my $sectionhash = shift;
  my $now = shift;

  # Later consider translation of new-page message? (per-user difference?)
  if ($NewText ne '') {
    $$texthash{'text'} = $NewText;
  } else {
    $$texthash{'text'} = 'Describe the new page here.' . "\n";
  }
  $$texthash{'text'} .= "\n"  if (substr($$texthash{'text'}, -1, 1) ne "\n");
  $$texthash{'minor'} = 0;      # Default as major edit
  $$texthash{'newauthor'} = 1;  # Default as new author
  $$texthash{'summary'} = '';
  &OpenNewSection("text_$name", join($FS3, %$texthash), $userid, $username, $pagehash, $sectionhash, $now);
}

sub GetPageFile {
  my ($id) = @_;

  return $PageDir . "/" . &GetPageDirectory($id) . "/$id.db";
}

sub OpenPage {
  my $id = shift;
  my $pagehash = shift;
  my $now = shift;
  my ($fname, $data);

  if ($OpenPageName eq $id) {
    return;
  }
  $fname = &GetPageFile($id);
  if (-f $fname) {
    print STDERR "OpenPage:fname: $fname\n";
    $data = &ReadFileOrDie($fname);
    %$pagehash = split(/$FS1/, $data, -1);  # -1 keeps trailing null fields
  } else {
    return &OpenNewPage($id, $pagehash, $now);
  }
  if ($$pagehash{'version'} != 3) {
    &UpdatePageVersion();
  }
  $OpenPageName = $id;
}

sub OpenSection {
  my $name = shift;
  my $userid = shift;
  my $username = shift;
  my $pagehash = shift;
  my $sectionhash = shift;
  my $now = shift;

  if (!defined($$pagehash{$name})) {
    &OpenNewSection($name, "", $username, $username, $pagehash, $sectionhash, $now);
  } else {
    %$sectionhash = split(/$FS2/, $$pagehash{$name}, -1);
  }

}

sub OpenText {
  my $name = shift;
  my $userid = shift;
  my $username = shift;
  my $pagehash = shift;
  my $texthash = shift;
  my $sectionhash = shift;
  my $now = shift;

  if (!defined($$pagehash{"text_$name"})) {
    return &OpenNewText($name, $username, $texthash, $sectionhash);
  } else {
    &OpenSection("text_$name", $userid, $username, $pagehash, $sectionhash, $now);
    %$texthash = split(/$FS3/, $$sectionhash{'data'}, -1);
  }
}

sub OpenDefaultText {
  my $userid = shift;
  my $username = shift;
  my $pagehash = shift;
  my $texthash = shift;
  my $sectionhash = shift;
  my $now = shift;
  &OpenText('default', $userid, $username, $pagehash, $texthash, $sectionhash, $now);
}

# Called after OpenKeptRevisions
sub OpenKeptRevision {
  my $revision = shift;
  my $keptrevisionshash = shift;
  my $sectionhash = shift;
  my $texthash = shift;

  %$sectionhash = split(/$FS2/, $$keptrevisionshash{$revision}, -1);
  %$texthash = split(/$FS3/, $$sectionhash{'data'}, -1);
}

sub GetPageCache {
  my $name = shift;
  my $pagehash = shift;

  return $$pagehash{"cache_$name"};
}

# Always call SavePage within a lock.
sub SavePage {
  my $pagehash = shift;
  my $now = shift;
  my $file = &GetPageFile($OpenPageName);

  $$pagehash{'revision'} += 1;    # Number of edited times
  $$pagehash{'ts'} = $now;        # Updated every edit
  &CreatePageDir($PageDir, $OpenPageName);
  print STDERR "SavePage: $file\n";
  &WriteStringToFile($file, join($FS1, %$pagehash));
}

sub SaveSection {
  my $name = shift;
  my $data = shift;
  my $username = shift;
  my $pagehash = shift;
  my $sectionhash = shift;
  my $userid = shift;
  my $now = shift;

  $$sectionhash{'revision'} += 1;   # Number of edited times
  $$sectionhash{'ts'} = $now;       # Updated every edit
  $$sectionhash{'ip'} = $ENV{REMOTE_ADDR};
  $$sectionhash{'id'} = $userid;
  $$sectionhash{'username'} = $username;
  $$sectionhash{'data'} = $data;
  $$pagehash{$name} = join($FS2, %$sectionhash);
}

sub SaveText {
  my $name = shift;
  my $texthash = shift;
  my $pagehash = shift;
  my $sectionhash = shift;
  my $userid = shift;
  my $username = shift;
  my $now = shift;
  &SaveSection("text_$name", join($FS3, %$texthash), $username, $pagehash, $sectionhash, $userid, $now);
}

sub SaveDefaultText {
  my $texthash = shift;
  my $pagehash = shift;
  my $sectionhash = shift;
  my $userid = shift;
  my $username = shift;
  my $now = shift;
  &SaveText('default', $texthash, $pagehash, $sectionhash, $userid, $username, $now);
}

sub SetPageCache {
  my $pagehash = shift;
  my $name = shift;
  my $data = shift;

  $$pagehash{"cache_$name"} = $data;
}

sub UpdatePageVersion {
  &ReportError('Bad page version (or corrupt page).');
}

sub KeepFileName {
  return $KeepDir . "/" . &GetPageDirectory($OpenPageName)
         . "/$OpenPageName.kp";
}

sub SaveKeepSection {
  my $sectionhash = shift;
  my $now = shift;
  my $file = &KeepFileName();
  my $data;

  return  if ($$sectionhash{'revision'} < 1);  # Don't keep "empty" revision
  $$sectionhash{'keepts'} = $now;
  $data = $FS1 . join($FS2, %$sectionhash);
  &CreatePageDir($KeepDir, $OpenPageName);
  &AppendStringToFile($file, $data);
}

sub ExpireKeepFile {
  my $pagehash = shift;
  my $now = shift;
  my ($fname, $data, @kplist, %tempSection, $expirets);
  my ($anyExpire, $anyKeep, $expire, %keepFlag, $sectName, $sectRev);
  my ($oldMajor, $oldAuthor);

  $fname = &KeepFileName();
  return  if (!(-f $fname));
  $data = &ReadFileOrDie($fname);
  @kplist = split(/$FS1/, $data, -1);  # -1 keeps trailing null fields
  return  if (length(@kplist) < 1);  # Also empty
  shift(@kplist)  if ($kplist[0] eq "");  # First can be empty
  return  if (length(@kplist) < 1);  # Also empty
  %tempSection = split(/$FS2/, $kplist[0], -1);
  if (!defined($tempSection{'keepts'})) {
#   die("Bad keep file." . join("|", %tempSection));
    return;
  }
  $expirets = $now - ($KeepDays * 24 * 60 * 60);
  return  if ($tempSection{'keepts'} >= $expirets);  # Nothing old enough

  $anyExpire = 0;
  $anyKeep   = 0;
  %keepFlag  = ();
  $oldMajor  = &GetPageCache('oldmajor', $pagehash);
  $oldAuthor = &GetPageCache('oldauthor', $pagehash);
  foreach (reverse @kplist) {
    %tempSection = split(/$FS2/, $_, -1);
    $sectName = $tempSection{'name'};
    $sectRev = $tempSection{'revision'};
    $expire = 0;
    if ($sectName eq "text_default") {
      if (($KeepMajor  && ($sectRev == $oldMajor)) ||
          ($KeepAuthor && ($sectRev == $oldAuthor))) {
        $expire = 0;
      } elsif ($tempSection{'keepts'} < $expirets) {
        $expire = 1;
      }
    } else {
      if ($tempSection{'keepts'} < $expirets) {
        $expire = 1;
      }
    }
    if (!$expire) {
      $keepFlag{$sectRev . "," . $sectName} = 1;
      $anyKeep = 1;
    } else {
      $anyExpire = 1;
    }
  }

  if (!$anyKeep) {  # Empty, so remove file
    unlink($fname);
    return;
  }
  return  if (!$anyExpire);  # No sections expired
  open (OUT, ">$fname") or die ("can't write $fname: $!");
  foreach (@kplist) {
    %tempSection = split(/$FS2/, $_, -1);
    $sectName = $tempSection{'name'};
    $sectRev = $tempSection{'revision'};
    if ($keepFlag{$sectRev . "," . $sectName}) {
      print OUT $FS1, $_;
    }
  }
  close(OUT);
}

sub OpenKeptList {
  my ($fname, $data);

  $fname = &KeepFileName();
  return  if (!(-f $fname));
  $data = &ReadFileOrDie($fname);
  return split(/$FS1/, $data, -1);  # -1 keeps trailing null fields
}

sub OpenKeptRevisions {
  my $name = shift;  # Name of section
  my $keptrevisionshash = shift;
  my ($fname, $data, %tempSection);

  my @KeptList = &OpenKeptList();

  foreach (@KeptList) {
    %tempSection = split(/$FS2/, $_, -1);
    next  if ($tempSection{'name'} ne $name);
    $$keptrevisionshash{$tempSection{'revision'}} = $_;
  }
}

sub LoadUserData {
  my $userid = shift;
  my $userdatahash = shift;
  my ($data, $status);

  ($status, $data) = &ReadFile(&UserDataFilename($userid));
  if (!$status) {
    return 0;
  }
  %$userdatahash = split(/$FS1/, $data, -1);  # -1 keeps trailing null fields
  return 1;
}

sub UserDataFilename {
  my ($id) = @_;

  return ""  if ($id < 1);
  return $UserDir . "/" . ($id % 10) . "/$id.db";
}

sub GetPageDirectory {
  my ($id) = @_;

  if ($id =~ /^([a-zA-Z])/) {
    return uc($1);
  }
  return "other";
}

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

# Later get user-level lock
sub SaveUserData {
    my $userdatahash = shift;
    my $userid = shift;
    my ($userFile, $data);

    &CreateUserDir();
    $userFile = &UserDataFilename($userid);
    $data = join($FS1, %$userdatahash);
    &WriteStringToFile($userFile, $data);
}

# Creates the directory where user information
# is store.
sub CreateUserDir {
    my ($n, $subdir);

    if (!(-d "$UserDir/0")) {
        &CreateDir($UserDir);

        foreach $n (0..9) {
            $subdir = "$UserDir/$n";
            &CreateDir($subdir);
        }
    }
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

sub GetLockedPageFile {
    my ($id) = @_;

    return $PageDir . "/" . GetPageDirectory($id) . "/$id.lck";
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

sub CreatePageDir {
    my ($dir, $id) = @_;
    my $subdir;

    &CreateDir($dir);  # Make sure main page exists
    $subdir = $dir . "/" . GetPageDirectory($id);
    &CreateDir($subdir);
    if ($id =~ m|([^/]+)/|) {
        $subdir = $subdir . "/" . $1;
        &CreateDir($subdir);
    }
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

sub GetNewUserId {
    my ($id);

    $id = 1001;
    while (-f &UserDataFilename($id+1000)) {
        $id += 1000;
    }
    while (-f &UserDataFilename($id+100)) {
        $id += 100;
    }
    while (-f &UserDataFilename($id+10)) {
        $id += 10;
    }
    &RequestLock() or die('Could not get user-ID lock');
    while (-f &UserDataFilename($id)) {
        $id++;
    }
    print STDERR "id: $id\n";
    &WriteStringToFile(&UserDataFilename($id), "lock");  # reserve the ID
    &ReleaseLock();
    return $id;
}

sub UpdateDiffs {
    my $pagehash = shift;
    my $keptrevisionshash = shift;
    my ($id, $editTime, $old, $new, $isEdit, $newAuthor) = @_;
    my ($editDiff, $oldMajor, $oldAuthor);

    $editDiff  = &GetDiff($old, $new, 0);     # 0 = already in lock
    $oldMajor  = &GetPageCache('oldmajor');
    $oldAuthor = &GetPageCache('oldauthor');
    if ($UseDiffLog) {
        &WriteDiff($id, $editTime, $editDiff);
    }
    &SetPageCache($pagehash, 'diff_default_minor', $editDiff);
    if ($isEdit || !$newAuthor) {
        &OpenKeptRevisions('text_default', $keptrevisionshash);
    }
    if (!$isEdit) {
        &SetPageCache($pagehash, 'diff_default_major', "1");
    } else {
        &SetPageCache($pagehash, 'diff_default_major', &GetKeptDiff($new, $oldMajor, 0));
    }
    if ($newAuthor) {
        &SetPageCache($pagehash, 'diff_default_author', "1");
    } elsif ($oldMajor == $oldAuthor) {
        &SetPageCache($pagehash, 'diff_default_author', "2");
    } elsif ($oldMajor == $oldAuthor) {
        &SetPageCache($pagehash, 'diff_default_author', "2");
    } else {
        &SetPageCache($pagehash, 'diff_default_author', &GetKeptDiff($new, $oldAuthor, 0));
    }
}

sub WriteDiff {
    my ($id, $editTime, $diffString) = @_;

    open (OUT, ">>$DataDir/diff_log") or die(T('can not write diff_log'));
    print OUT  "------\n" . $id . "|" . $editTime . "\n";
    print OUT  $diffString;
    close(OUT);
}





1;
