# PurpleWiki::Config.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Config.pm,v 1.2.2.1 2003/05/30 08:15:19 cdent Exp $
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

package PurpleWiki::Config;

# PurpleWiki Configuration 

# $Id: Config.pm,v 1.2.2.1 2003/05/30 08:15:19 cdent Exp $

use strict;
use vars qw(@ISA @EXPORT);
require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw(@RcDays
  $TempDir $LockDir $DataDir $HtmlDir $UserDir $KeepDir $PageDir
  $InterFile $RcFile $RcOldFile $IndexFile $FullUrl $SiteName $HomePage
  $LogoUrl $RcDefault $IndentLimit $RecentTop $EditAllowed $UseDiff
  $UseSubpage $SimpleLinks $NonEnglish $LogoLeft
  $KeepDays $HtmlTags $UseDiffLog $KeepMajor $KeepAuthor
  $FreeUpper $EmailNotify $SendMail $EmailFrom $EmbedWiki
  $ScriptTZ $BracketText $UseAmPm $UseConfig $UseIndex $UseLookup
  $RedirType $AdminPass $EditPass $UseHeadings $NetworkFile $BracketWiki
  $FreeLinks $WikiLinks $AdminDelete $FreeLinkPattern $RCName $RunCGI
  $ShowEdits $ThinLine $LinkPattern $InterLinkPattern $InterSitePattern
  $UrlProtocols $UrlPattern $ImageExtensions $RFCPattern $ISBNPattern
  $FS $FS1 $FS2 $FS3 $CookieName $SiteBase $StyleSheet $NotFoundPg
  $FooterNote $EditNote $MaxPost $NewText $NotifyDefault $HttpCharset
  $UserGotoBar);

use vars qw(@RcDays
  $TempDir $LockDir $DataDir $HtmlDir $UserDir $KeepDir $PageDir
  $InterFile $RcFile $RcOldFile $IndexFile $FullUrl $SiteName $HomePage
  $LogoUrl $RcDefault $IndentLimit $RecentTop $EditAllowed $UseDiff
  $UseSubpage $SimpleLinks $NonEnglish $LogoLeft
  $KeepDays $HtmlTags $UseDiffLog $KeepMajor $KeepAuthor
  $FreeUpper $EmailNotify $SendMail $EmailFrom $EmbedWiki
  $ScriptTZ $BracketText $UseAmPm $UseConfig $UseIndex $UseLookup
  $RedirType $AdminPass $EditPass $UseHeadings $NetworkFile $BracketWiki
  $FreeLinks $WikiLinks $AdminDelete $FreeLinkPattern $RCName $RunCGI
  $ShowEdits $ThinLine $LinkPattern $InterLinkPattern $InterSitePattern
  $UrlProtocols $UrlPattern $ImageExtensions $RFCPattern $ISBNPattern
  $FS $FS1 $FS2 $FS3 $CookieName $SiteBase $StyleSheet $NotFoundPg
  $FooterNote $EditNote $MaxPost $NewText $NotifyDefault $HttpCharset
  $UserGotoBar);

# == Configuration =====================================================
$DataDir     = "/home/cdent/testpurple"; # Main wiki directory
$UseConfig   = 1;       # 1 = use config file,    0 = do not look for config

# Default configuration (used if UseConfig is 0)
$CookieName  = "PurpleWiki";    # Name for this wiki (for multi-wiki sites)
$SiteName    = "PurpleWiki";    # Name of site (used for titles)
$HomePage    = "HomePage";      # Home page (change space to _)
$RCName      = "RecentChanges"; # Name of changes page (change space to _)
$LogoUrl     = "";              # URL for site logo ("" for no logo)
$ENV{PATH}   = "/usr/bin/";     # Path used to find "diff"
$ScriptTZ    = "";              # Local time zone ("" means do not print)
$RcDefault   = 30;              # Default number of RecentChanges days
@RcDays      = qw(1 3 7 30 90); # Days for links on RecentChanges
$KeepDays    = 14;              # Days to keep old revisions
$SiteBase    = "";              # Full URL for <BASE> header
$FullUrl     = "";              # Set if the auto-detected URL is wrong
$RedirType   = 1;               # 1 = CGI.pm, 2 = script, 3 = no redirect
$AdminPass   = "";              # Set to non-blank to enable password(s)
$EditPass    = "";              # Like AdminPass, but for editing only
$StyleSheet  = "";              # URL for CSS stylesheet (like "/wiki.css")
$NotFoundPg  = "";              # Page for not-found links ("" for blank pg)
$EmailFrom   = "Wiki";          # Text for "From: " field of email notes.
$SendMail    = "/usr/sbin/sendmail";  # Full path to sendmail executable
$FooterNote  = "";              # HTML for bottom of every page
$EditNote    = "";              # HTML notice above buttons on edit page
$MaxPost     = 1024 * 210;      # Maximum 210K posts (about 200K for pages)
$NewText     = "";              # New page text ("" for default message)
$HttpCharset = "";              # Charset for pages, like "iso-8859-2"
$UserGotoBar = "";              # HTML added to end of goto bar

# Major options:
$UseSubpage  = 1;       # 1 = use subpages,       0 = do not use subpages
$EditAllowed = 1;       # 1 = editing allowed,    0 = read-only
$UseDiff     = 1;       # 1 = use diff features,  0 = do not use diff
$FreeLinks   = 1;       # 1 = use [[word]] links, 0 = LinkPattern only
$WikiLinks   = 1;       # 1 = use LinkPattern,    0 = use [[word]] only
$AdminDelete = 1;       # 1 = Admin only page,    0 = Editor can delete pages
$RunCGI      = 1;       # 1 = Run script as CGI,  0 = Load but do not run
$EmailNotify = 0;       # 1 = use email notices,  0 = no email on changes
$EmbedWiki   = 0;       # 1 = no headers/footers, 0 = normal wiki pages

# Minor options:
$LogoLeft    = 0;       # 1 = logo on left,       0 = logo on right
$RecentTop   = 1;       # 1 = recent on top,      0 = recent on bottom
$UseDiffLog  = 1;       # 1 = save diffs to log,  0 = do not save diffs
$KeepMajor   = 1;       # 1 = keep major rev,     0 = expire all revisions
$KeepAuthor  = 1;       # 1 = keep author rev,    0 = expire all revisions
$ShowEdits   = 0;       # 1 = show minor edits,   0 = hide edits by default
$SimpleLinks = 0;       # 1 = only letters,       0 = allow _ and numbers
$NonEnglish  = 0;       # 1 = extra link chars,   0 = only A-Za-z chars
$ThinLine    = 0;       # 1 = fancy <hr> tags,    0 = classic wiki <hr>
$BracketText = 1;       # 1 = allow [URL text],   0 = no link descriptions
$UseAmPm     = 1;       # 1 = use am/pm in times, 0 = use 24-hour times
$UseIndex    = 0;       # 1 = use index file,     0 = slow/reliable method
$UseHeadings = 1;       # 1 = allow = h1 text =,  0 = no header formatting
$NetworkFile = 1;       # 1 = allow remote file:, 0 = no file:// links
$BracketWiki = 0;       # 1 = [WikiLnk txt] link, 0 = no local descriptions
$UseLookup   = 1;       # 1 = lookup host names,  0 = skip lookup (IP only)
$FreeUpper   = 1;       # 1 = force upper case,   0 = do not force case

# == You should not have to change anything below this line. =============
$IndentLimit = 20;                  # Maximum depth of nested lists
$PageDir     = "$DataDir/page";     # Stores page data
$HtmlDir     = "$DataDir/html";     # Stores HTML versions
$UserDir     = "$DataDir/user";     # Stores user data
$KeepDir     = "$DataDir/keep";     # Stores kept (old) page data
$TempDir     = "$DataDir/temp";     # Temporary files and locks
$LockDir     = "$TempDir/lock";     # DB is locked if this exists
$InterFile   = "$DataDir/intermap"; # Interwiki site->url map
$RcFile      = "$DataDir/rclog";    # New RecentChanges logfile
$RcOldFile   = "$DataDir/oldrclog"; # Old RecentChanges logfile
$IndexFile   = "$DataDir/pageidx";  # List of all pages

# == Static configuration. Do not chnage ============================
# Field separators that delimit page storage
$FS  = "\xb3";      # The FS character is a superscript "3"
$FS1 = $FS . "1";   # The FS values are used to separate fields
$FS2 = $FS . "2";   # in stored hashtables and other data structures.
$FS3 = $FS . "3";   # The FS character is not allowed in user data.

if ($UseConfig && (-f "$DataDir/config")) {
  do "$DataDir/config";  # Later consider error checking?
}

# Sets up the strings and regular expressions for matching
InitLinkPatterns();

# Creates the strings and regular expressions used for
# link matching. 
#
# FIXME: with the parsers in place these are really 
# only used for checking to see if an incoming request
# is kosher, which makes these a bit redundant. The
# fat has been trimmed but it still leaves a fair 
# piece.
sub InitLinkPatterns {
  my ($UpperLetter, $LowerLetter, $AnyLetter, $LpA, $LpB, $QDelim);

  $UpperLetter = "[A-Z";
  $LowerLetter = "[a-z";
  $AnyLetter   = "[A-Za-z";
  if ($NonEnglish) {
    $UpperLetter .= "\xc0-\xde";
    $LowerLetter .= "\xdf-\xff";
    $AnyLetter   .= "\xc0-\xff";
  }
  if (!$SimpleLinks) {
    $AnyLetter .= "_0-9";
  }
  $UpperLetter .= "]"; $LowerLetter .= "]"; $AnyLetter .= "]";

  # Main link pattern: lowercase between uppercase, then anything
  $LpA = $UpperLetter . "+" . $LowerLetter . "+" . $UpperLetter
         . $AnyLetter . "*";
  # Optional subpage link pattern: uppercase, lowercase, then anything
  $LpB = $UpperLetter . "+" . $LowerLetter . "+" . $AnyLetter . "*";

  if ($UseSubpage) {
    # Loose pattern: If subpage is used, subpage may be simple name
    $LinkPattern = "((?:(?:$LpA)?\\/$LpB)|$LpA)";
    # Strict pattern: both sides must be the main LinkPattern
    # $LinkPattern = "((?:(?:$LpA)?\\/)?$LpA)";
  } else {
    $LinkPattern = "($LpA)";
  }
  $QDelim = '(?:"")?';     # Optional quote delimiter (not in output)
  $LinkPattern .= $QDelim;

  if ($FreeLinks) {
    # Note: the - character must be first in $AnyLetter definition
    if ($NonEnglish) {
      $AnyLetter = "[-,.()' _0-9A-Za-z\xc0-\xff]";
    } else {
      $AnyLetter = "[-,.()' _0-9A-Za-z]";
    }
  }
  $FreeLinkPattern = "($AnyLetter+)";
  if ($UseSubpage) {
    $FreeLinkPattern = "((?:(?:$AnyLetter+)?\\/)?$AnyLetter+)";
  }
  $FreeLinkPattern .= $QDelim;
}

# ===========================================
# Experimental autoload access to config 
# variables. Eventually instead of 
# using PurpleWiki::Config everywhere
# we will pass Config objects around.

# FIXME: this should accept a config file
# location and do the 'do' that is done
# above on that file.
sub new {
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}

# FIXME: this is only for accessing package
# variables. It should be more flexible than this
# and more aware of error conditions.
sub AUTOLOAD {
    my $self = shift;
    my $auto = our $AUTOLOAD;
    return if $auto eq 'Config::DESTROY';
    no strict 'refs';
    return ${$auto};
}

  
1;
