#!/usr/bin/perl
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# wiki.pl - PurpleWiki
#
# $Id: wiki.pl,v 1.5.2.8 2003/01/29 08:31:24 cdent Exp $
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

package UseModWiki;
use lib '/home/cdent/src/PurpleWiki.refactor';
use strict;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Config;
use PurpleWiki::Database;
use PurpleWiki::Database::Page;
use PurpleWiki::Database::KeptRevision;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

local $| = 1;  # Do not buffer output (localized for mod_perl)

# Global variables:
use vars qw(%UserCookie %SetCookie %UserData $MainPage
  $q $Now $UserID $TimeZoneOffset );

my $ScriptName;         # the name by which this script is called
my $wikiParser;         # the reference to the PurpleWiki Parser
my $InterSiteInit = 0;
my %InterSite;

# The "main" program, called from the end of this script file.
sub DoWikiRequest {
  &InitRequest() or return;

  # Instantiate PurpleWiki parser.
  $wikiParser = PurpleWiki::Parser::WikiText->new;

  if (!&DoBrowseRequest()) {
    &DoOtherRequest();
  }

}

# == Refactored functions for PurpleWiki ===============================
# FIXME: we should be able to now use the call in the Database
# module instead of this. In the meantime this just relays.
sub pageExists {
    my $id = shift;
    my (@temp);

    $id =~ s|^/|$MainPage/|;
    if ($FreeLinks) {
        $id = &FreeToNormal($id);
    }

    my $page = new PurpleWiki::Database::Page('id' => $id);

    return $page->pageExists();

}

# == Common and cache-browsing code ====================================

sub InitRequest {
  $CGI::POST_MAX = $MaxPost;
  $CGI::DISABLE_UPLOADS = 1;  # no uploads
  $q = new CGI;

  $Now = time;                     # Reset in case script is persistent
  $ScriptName = $q->url('relative' => 1);  # Name used in links
  $MainPage = ".";       # For subpages only, the name of the top-level page
  &PurpleWiki::Database::CreateDir($DataDir);  # Create directory if it doesn't exist
  if (!-d $DataDir) {
    &ReportError("Could not create $DataDir $!");
    return 0;
  }
  &InitCookie();         # Reads in user data
  return 1;
}

sub InitCookie {
  %SetCookie = ();
  $TimeZoneOffset = 0;
  undef $q->{'.cookies'};  # Clear cache if it exists (for SpeedyCGI)
  %UserCookie = $q->cookie($CookieName);
  $UserID = $UserCookie{'id'};
  $UserID =~ s/\D//g;  # Numeric only
  if ($UserID < 200) {
    $UserID = 111;
  } else {
    if (&PurpleWiki::Database::LoadUserData($UserID, \%UserData)) {
      if (($UserData{'id'}       != $UserCookie{'id'})      ||
        ($UserData{'randkey'}  != $UserCookie{'randkey'})) {
        $UserID = 113;
        %UserData = ();   # Invalid.  Later consider warning message.
      }
    }
  }
  if ($UserData{'tzoffset'} != 0) {
    $TimeZoneOffset = $UserData{'tzoffset'} * (60 * 60);
  }
}

sub DoBrowseRequest {
  my ($id, $action, $text);
  my $page;

  if (!$q->param) {             # No parameter
    &BrowsePage($HomePage);
    return 1;
  }
  $id = &GetParam('keywords', '');
  $page = new PurpleWiki::Database::Page('id' => $id);
  if ($id) {                    # Just script?PageName
    if ($FreeLinks && (!$page->pageExists())) {
      $id = &FreeToNormal($id);
    }
    if (($NotFoundPg ne '') && (!$page->pageExists())) {
      $id = $NotFoundPg;
    }
    &BrowsePage($id)  if &ValidIdOrDie($id);
    return 1;
  }
  $action = lc(&GetParam('action', ''));
  $id = &GetParam('id', '');
  $page = new PurpleWiki::Database::Page('id' => $id);
  if ($action eq 'browse') {
    if ($FreeLinks && (!$page->pageExists())) {
      $id = &FreeToNormal($id);
    }
    if (($NotFoundPg ne '') && (!$page->pageExists())) {
      $id = $NotFoundPg;
    }
    &BrowsePage($id)  if &ValidIdOrDie($id);
    return 1;
  } elsif ($action eq 'rc') {
    &BrowsePage($RCName);
    return 1;
  } elsif ($action eq 'random') {
    &DoRandom();
    return 1;
  } elsif ($action eq 'history') {
    &DoHistory($id)   if &ValidIdOrDie($id);
    return 1;
  }
  return 0;  # Request not handled
}

sub BrowsePage {
  my $id = shift;
  my ($fullHtml, $oldId, $allDiff, $showDiff, $openKept);
  my ($revision, $goodRevision, $diffRevision, $newText);

  my ($page, $section, $text, $keptRevision, $keptSection);

  print STDERR "id: $id\n";
  $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now,
                                    'userID' => $UserID, 
                                    'username' => GetParam("username", ""));
  $page->openPage();
  $section = $page->getSection();
  $text = $page->getText();
  $newText = $text->getText();
  $keptRevision = new PurpleWiki::Database::KeptRevision($id);

  $revision = &GetParam('revision', '');
  $revision =~ s/\D//g;           # Remove non-numeric chars
  $goodRevision = $revision;      # Non-blank only if exists
  if ($revision ne '') {
    if (!$keptRevision->hasRevision($revision)) {
      $goodRevision = '';
    }
  }
  
  # Handle a single-level redirect
  $oldId = &GetParam('oldid', '');
  if (($oldId eq '') && (substr($text->getText(), 0, 10) eq '#REDIRECT ')) {
    $oldId = $id;
    if (($FreeLinks) && ($text->getText() =~ /\#REDIRECT\s+\[\[.+\]\]/)) {
      ($id) = ($text->getText() =~ /\#REDIRECT\s+\[\[(.+)\]\]/);
      $id = &FreeToNormal($id);
    } else {
      ($id) = ($text->getText() =~ /\#REDIRECT\s+(\S+)/);
    }
    if (&ValidId($id) eq '') {
      # Later consider revision in rebrowse?
      &ReBrowsePage($id, $oldId, 0);
      return;
    } else {  # Not a valid target, so continue as normal page
      $id = $oldId;
      $oldId = '';
    }
  }
  $MainPage = $id;
  $MainPage =~ s|/.*||;  # Only the main page name (remove subpage)
  $fullHtml = &GetHeader($id, &QuoteHtml($id), $oldId);

  if ($revision ne '') {
    # Later maybe add edit time?
    if ($goodRevision ne '') {
      $fullHtml .= '<b>' . "Showing revision $revision</b><br>";
      $text = $keptRevision->getRevision($revision)->getText();
    } else {
      $fullHtml .= '<b>' . "Revision $revision not available"
                   . ' (' . 'showing current revision instead'
                   . ')</b><br>';
    }
  }
  $allDiff  = &GetParam('alldiff', 0);

  if ($allDiff != 0) {
    $allDiff = &GetParam('defaultdiff', 1);
  }

  if (($id eq $RCName) && &GetParam('norcdiff', 1)) {
    $allDiff = 0;  # Only show if specifically requested
  }

  $showDiff = &GetParam('diff', $allDiff);

  if ($UseDiff && $showDiff) {
    $diffRevision = $goodRevision;
    $diffRevision = &GetParam('diffrevision', $diffRevision);

    $fullHtml .= &PurpleWiki::Database::GetDiffHTML($page,
        $keptRevision, $showDiff, $id, $diffRevision, $newText);
  }

  $fullHtml .= &WikiToHTML($text->getText());

  $fullHtml .= "<hr>\n"  if (!&GetParam('embed', $EmbedWiki));
  if ($id eq $RCName) {
    print $fullHtml;
    &DoRc();
    print "<hr>\n"  if (!&GetParam('embed', $EmbedWiki));
    print &GetFooterText($section, $id, $goodRevision);
    return;
  }
  $fullHtml .= &GetFooterText($section, $id, $goodRevision);

  print $fullHtml;

  return  if ($showDiff || ($revision ne ''));  # Don't cache special version
}

sub ReBrowsePage {
  my ($id, $oldId, $isEdit) = @_;

  if ($oldId ne "") {   # Target of #REDIRECT (loop breaking)
    print &GetRedirectpage("action=browse&id=$id&oldid=$oldId",
                           $id, $isEdit);
  } else {
    print &GetRedirectPage($id, $id, $isEdit);
  }
}

sub DoRc {
  my ($fileData, $rcline, $i, $daysago, $lastTs, $ts, $idOnly);
  my (@fullrc, $status, $oldFileData, $firstTs, $errorText);
  my $starttime = 0;
  my $showbar = 0;

  if (&GetParam("from", 0)) {
    $starttime = &GetParam("from", 0);
    print "<h2>" . "Updates since " . &TimeToText($starttime)
          . "</h2>\n";
  } else {
    $daysago = &GetParam("days", 0);
    $daysago = &GetParam("rcdays", 0)  if ($daysago == 0);
    if ($daysago) {
      $starttime = $Now - ((24*60*60)*$daysago);
      print "<h2>" . sprintf("Updates in the last %s day" .
                    (($daysago != 1)?"s":""), $daysago) . "</h2>\n";
    }
  }
  if ($starttime == 0) {
    $starttime = $Now - ((24*60*60)*$RcDefault);
    print "<h2>" . sprintf("Updates in the last %s day"
                      . (($RcDefault != 1)?"s":""), $RcDefault) . "</h2>\n";
    # Translation of above line is identical to previous version
  }

  # Read rclog data (and oldrclog data if needed)
  ($status, $fileData) = &PurpleWiki::Database::ReadFile($RcFile);
  $errorText = "";
  if (!$status) {
    # Save error text if needed.
    $errorText = '<p><strong>' . "Could not open $RCName log file"
                 . ":</strong> $RcFile<p>"
                 . 'Error was' . ":\n<pre>$!</pre>\n" . '<p>'
    . 'Note: This error is normal if no changes have been made.' . "\n";
  }
  @fullrc = split(/\n/, $fileData);
  $firstTs = 0;
  if (@fullrc > 0) {  # Only false if no lines in file
    ($firstTs) = split(/$FS3/, $fullrc[0]);
  }
  if (($firstTs == 0) || ($starttime <= $firstTs)) {
    ($status, $oldFileData) = &PurpleWiki::Database::ReadFile($RcOldFile);
    if ($status) {
      @fullrc = split(/\n/, $oldFileData . $fileData);
    } else {
      if ($errorText ne "") {  # could not open either rclog file
        print $errorText;
        print "<p><strong>"
              . "Could not open old $RCName log file"
              . ":</strong> $RcOldFile<p>"
              . 'Error was' . ":\n<pre>$!</pre>\n";
        return;
      }
    }
  }
  $lastTs = 0;
  if (@fullrc > 0) {  # Only false if no lines in file
    ($lastTs) = split(/$FS3/, $fullrc[$#fullrc]);
  }
  $lastTs++  if (($Now - $lastTs) > 5);  # Skip last unless very recent

  $idOnly = &GetParam("rcidonly", "");
  if ($idOnly ne "") {
    print '<b>(' . sprintf("for %s only", &ScriptLink($idOnly, $idOnly))
          . ')</b><br>';
  }
  foreach $i (@RcDays) {
    print " | "  if $showbar;
    $showbar = 1;
    print &ScriptLink("action=rc&days=$i",
                      sprintf("%s day" . (($i != 1)?'s':''), $i));
      # Note: must have two translations (for "day" and "days")
      # Following comment line is for translation helper script
      # Ts('%s days', '');
  }
  print "<br>" . &ScriptLink("action=rc&from=$lastTs",
                             'List new changes starting from');
  print " " . &TimeToText($lastTs) . "<br>\n";

  # Later consider a binary search?
  $i = 0;
  while ($i < @fullrc) {  # Optimization: skip old entries quickly
    ($ts) = split(/$FS3/, $fullrc[$i]);
    if ($ts >= $starttime) {
      $i -= 1000  if ($i > 0);
      last;
    }
    $i += 1000;
  }
  $i -= 1000  if (($i > 0) && ($i >= @fullrc));
  for (; $i < @fullrc ; $i++) {
    ($ts) = split(/$FS3/, $fullrc[$i]);
    last if ($ts >= $starttime);
  }
  if ($i == @fullrc) {
    print '<br><strong>' . 'No updates since ' .
                              &TimeToText($starttime) . "</strong><br>\n";
  } else {
    splice(@fullrc, 0, $i);  # Remove items before index $i
    # Later consider an end-time limit (items older than X)
    print &GetRcHtml(@fullrc);
  }
  print '<p>' . 'Page generated ' . &TimeToText($Now) . "<br>\n";
}

sub GetRcHtml {
  my @outrc = @_;
  my ($rcline, $html, $date, $sum, $edit, $count, $newtop, $author);
  my ($showedit, $inlist, $link, $all, $idOnly);
  my ($ts, $pagename, $summary, $isEdit, $host, $kind, $extraTemp);
  my ($tEdit, $tChanges, $tDiff);
  my %extra = ();
  my %changetime = ();
  my %pagecount = ();

  $tEdit    = '(edit)';    # Optimize translations out of main loop
  $tDiff    = '(diff)';
  $tChanges = 'changes';
  $showedit = &GetParam("rcshowedit", $ShowEdits);
  $showedit = &GetParam("showedit", $showedit);
  if ($showedit != 1) {
    my @temprc = ();
    foreach $rcline (@outrc) {
      ($ts, $pagename, $summary, $isEdit, $host) = split(/$FS3/, $rcline);
      if ($showedit == 0) {  # 0 = No edits
        push(@temprc, $rcline)  if (!$isEdit);
      } else {               # 2 = Only edits
        push(@temprc, $rcline)  if ($isEdit);
      }
    }
    @outrc = @temprc;
  }

  # Later consider folding into loop above?
  # Later add lines to assoc. pagename array (for new RC display)
  foreach $rcline (@outrc) {
    ($ts, $pagename) = split(/$FS3/, $rcline);
    $pagecount{$pagename}++;
    $changetime{$pagename} = $ts;
  }
  $date = "";
  $inlist = 0;
  $html = "";
  $all = &GetParam("rcall", 0);
  $all = &GetParam("all", $all);
  $newtop = &GetParam("rcnewtop", $RecentTop);
  $newtop = &GetParam("newtop", $newtop);
  $idOnly = &GetParam("rcidonly", "");

  @outrc = reverse @outrc if ($newtop);
  foreach $rcline (@outrc) {
    ($ts, $pagename, $summary, $isEdit, $host, $kind, $extraTemp)
      = split(/$FS3/, $rcline);
    # Later: need to change $all for new-RC?
    next  if ((!$all) && ($ts < $changetime{$pagename}));
    next  if (($idOnly ne "") && ($idOnly ne $pagename));
    %extra = split(/$FS2/, $extraTemp, -1);
    if ($date ne &CalcDay($ts)) {
      $date = &CalcDay($ts);
      if ($inlist) {
        $html .= "</UL>\n";
        $inlist = 0;
      }
      $html .= "<p><strong>" . $date . "</strong><p>\n";
    }
    if (!$inlist) {
      $html .= "<UL>\n";
      $inlist = 1;
    }
    $host = &QuoteHtml($host);
    if (defined($extra{'name'}) && defined($extra{'id'})) {
      $author = &GetAuthorLink($host, $extra{'name'}, $extra{'id'});
    } else {
      $author = &GetAuthorLink($host, "", 0);
    }
    $sum = "";
    if (($summary ne "") && ($summary ne "*")) {
      $summary = &QuoteHtml($summary);
      $sum = "<strong>[$summary]</strong> ";
    }
    $edit = "";
    $edit = "<em>$tEdit</em> "  if ($isEdit);
    $count = "";
    if ((!$all) && ($pagecount{$pagename} > 1)) {
      $count = "($pagecount{$pagename} ";
      if (&GetParam("rcchangehist", 1)) {
        $count .= &GetHistoryLink($pagename, $tChanges);
      } else {
        $count .= $tChanges;
      }
      $count .= ") ";
    }
    $link = "";
    if ($UseDiff && &GetParam("diffrclink", 1)) {
      $link .= &ScriptLinkDiff(4, $pagename, $tDiff, "") . "  ";
    }
    $link .= &GetPageLink($pagename);
    $html .= "<li>$link ";
    # Later do new-RC looping here.
    $html .=  &CalcTime($ts) . " $count$edit" . " $sum";
    $html .= ". . . . . $author\n";  # Make dots optional?
  }
  $html .= "</UL>\n" if ($inlist);
  return $html;
}

sub DoRandom {
  my ($id, @pageList);

  @pageList = &PurpleWiki::Database::AllPagesList();  # Optimize?
  $id = $pageList[int(rand($#pageList + 1))];
  &ReBrowsePage($id, "", 0);
}

sub DoHistory {
  my ($id) = @_;
  my ($html, $canEdit);
  my $page;
  my $text;
  my $keptRevision;

  print &GetHeader("",&QuoteHtml("History of $id"), "") . "<br>";
  $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now);
  $page->openPage();

  $canEdit = &UserCanEdit($id);
  $canEdit = 0;  # Turn off direct "Edit" links
  $html = &GetHistoryLine($id, $page->getSection(), $canEdit, 1);
  $keptRevision = new PurpleWiki::Database::KeptRevision($id);
  foreach my $section (reverse sort {$a->getRevision() <=> $b->getRevision()}
                    $keptRevision->getSections()) {
    next if (!defined($section ));
    $html .= &GetHistoryLine($id, $section, $canEdit, 0);
  }
  print $html;
  print &GetCommonFooter();
}

sub GetHistoryLine {
  my ($id, $section, $canEdit, $isCurrent) = @_;
  my ($html, $expirets, $rev, $summary, $host, $user, $uid, $ts, $minor);
  my (%sect, %revtext);

  my $text = $section->getText();
  $rev = $section->getRevision();
  $summary = $text->getSummary();
  if ((defined($section->getHost())) && ($section->getHost() ne '')) {
    $host = $section->getHost();
  } else {
    $host = $section->getIP();
    $host =~ s/\d+$/xxx/;      # Be somewhat anonymous (if no host)
  }
  $user = $section->getUsername();
  $uid = $section->getID();
  $ts = $section->getTS();
  $minor = '';
  $minor = '<i>' . '(edit)' . '</i> '  if ($text->isMinor());
  $expirets = $Now - ($KeepDays * 24 * 60 * 60);

  $html = "Revision $rev" . ": ";
  if ($isCurrent) {
    $html .= &GetPageLinkText($id, 'View') . ' ';
    if ($canEdit) {
      $html .= &GetEditLink($id, 'Edit') . ' ';
    }
    if ($UseDiff) {
      $html .= 'Diff' . ' ';
    }
  } else {
    $html .= &GetOldPageLink('browse', $id, $rev, 'View') . ' ';
    if ($canEdit) {
      $html .= &GetOldPageLink('edit',   $id, $rev, 'Edit') . ' ';
    }
    if ($UseDiff) {
      $html .= &ScriptLinkDiffRevision(1, $id, $rev, 'Diff') . ' ';
    }
  }
  $html .= ". . " . $minor . &TimeToText($ts) . " ";
  $html .= 'by' . ' ' . &GetAuthorLink($host, $user, $uid) . " ";
  if (defined($summary) && ($summary ne "") && ($summary ne "*")) {
    $summary = &QuoteHtml($summary);   # Thanks Sunir! :-)
    $html .= "<b>[$summary]</b> ";
  }
  $html .= "<br>\n";
  return $html;
}

# ==== HTML and page-oriented functions ====
sub ScriptLink {
  my ($action, $text) = @_;

  return "<a href=\"$ScriptName?$action\">$text</a>";
}

sub GetPageLink {
  my ($id) = @_;
  my $name = $id;

  $id =~ s|^/|$MainPage/|;
  if ($FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink($id, $name);
}

sub GetPageLinkText {
  my ($id, $name) = @_;

  $id =~ s|^/|$MainPage/|;
  if ($FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink($id, $name);
}

sub GetEditLink {
  my ($id, $name) = @_;

  if ($FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink("action=edit&id=$id", $name);
}

sub GetOldPageLink {
  my ($kind, $id, $revision, $name) = @_;

  if ($FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink("action=$kind&id=$id&revision=$revision", $name);
}

sub GetPageOrEditLink {
  my ($id, $name) = @_;
  my (@temp);

  if ($name eq "") {
    $name = $id;
    if ($FreeLinks) {
      $name =~ s/_/ /g;
    }
  }
  $id =~ s|^/|$MainPage/|;
  if ($FreeLinks) {
    $id = &FreeToNormal($id);
  }
  my $page = new PurpleWiki::Database::Page('id' => $id);
  if ($page->pageExists()) {      # Page file exists
    return &GetPageLinkText($id, $name);
  }
  if ($FreeLinks) {
    if ($name =~ m| |) {  # Not a single word
      $name = "[$name]";  # Add brackets so boundaries are obvious
    }
  }
  return $name . &GetEditLink($id,"?");
}

sub InterPageLink {
    my ($id) = @_;
    my ($name, $site, $remotePage, $url, $punct);

    ($id, $punct) = &SplitUrlPunct($id);

    $name = $id;
    ($site, $remotePage) = split(/:/, $id, 2);
    $url = &GetSiteUrl($site);
    return ("", $id . $punct)  if ($url eq "");
    $remotePage =~ s/&amp;/&/g;  # Unquote common URL HTML
    $url .= $remotePage;
    return ("<a href=\"$url\">$name</a>", $punct);
}

sub SplitUrlPunct {
    my ($url) = @_;
    my ($punct);

    if ($url =~ s/\"\"$//) {
      return ($url, "");   # Delete double-quote delimiters here
    }
    $punct = "";
    ($punct) = ($url =~ /([^a-zA-Z0-9\/\xc0-\xff]+)$/);
    $url =~ s/([^a-zA-Z0-9\/\xc0-\xff]+)$//;
    return ($url, $punct);
}




sub GetSiteUrl {
    my ($site) = @_;
    my ($data, $url, $status);

    if (!$InterSiteInit) {
      $InterSiteInit = 1;
      ($status, $data) = &PurpleWiki::Database::ReadFile($InterFile);
      return ""  if (!$status);
      %InterSite = split(/\s+/, $data);  # Later consider defensive code
    }
    $url = $InterSite{$site}  if (defined($InterSite{$site}));
    return $url;
}



sub GetSearchLink {
  my ($id) = @_;
  my $name = $id;

  $id =~ s|.+/|/|;   # Subpage match: search for just /SubName
  if ($FreeLinks) {
    $name =~ s/_/ /g;  # Display with spaces
    $id =~ s/_/+/g;    # Search for url-escaped spaces
  }
  return &ScriptLink("search=$id", $name);
}

sub GetPrefsLink {
  return &ScriptLink("action=editprefs", 'Preferences');
}

sub GetRandomLink {
  return &ScriptLink("action=random", 'Random Page');
}

sub ScriptLinkDiff {
  my ($diff, $id, $text, $rev) = @_;

  $rev = "&revision=$rev"  if ($rev ne "");
  $diff = &GetParam("defaultdiff", 1)  if ($diff == 4);
  return &ScriptLink("action=browse&diff=$diff&id=$id$rev", $text);
}

sub ScriptLinkDiffRevision {
  my ($diff, $id, $rev, $text) = @_;

  $rev = "&diffrevision=$rev"  if ($rev ne "");
  $diff = &GetParam("defaultdiff", 1)  if ($diff == 4);
  return &ScriptLink("action=browse&diff=$diff&id=$id$rev", $text);
}

sub ScriptLinkTitle {
  my ($action, $text, $title) = @_;

  if ($FreeLinks) {
    $action =~ s/ /_/g;
  }
  return "<a href=\"$ScriptName?$action\" title=\"$title\">$text</a>";
}

sub GetAuthorLink {
  my ($host, $userName, $uid) = @_;
  my ($html, $title, $userNameShow);

  $userNameShow = $userName;
  if ($FreeLinks) {
    $userName     =~ s/ /_/g;
    $userNameShow =~ s/_/ /g;
  }
  if (&ValidId($userName) ne "") {  # Invalid under current rules
    $userName = "";  # Just pretend it isn't there.
  }
  # Later have user preference for link titles and/or host text?
  if (($uid > 0) && ($userName ne "")) {
    $html = &ScriptLinkTitle($userName, $userNameShow,
            "ID $uid" . ' ' . "from $host");
  } else {
    $html = $host;
  }
  return $html;
}

sub GetHistoryLink {
  my ($id, $text) = @_;

  if ($FreeLinks) {
    $id =~ s/ /_/g;
  }
  return &ScriptLink("action=history&id=$id", $text);
}

sub GetHeader {
  my ($id, $title, $oldId) = @_;
  my $header = "";
  my $logoImage = "";
  my $result = "";
  my $embed = &GetParam('embed', $EmbedWiki);
  my $altText = '[Home]';

  $result = &GetHttpHeader();
  if ($FreeLinks) {
    $title =~ s/_/ /g;   # Display as spaces
  }
  $result .= &GetHtmlHeader("$SiteName: $title");
  return $result  if ($embed);

  if ($oldId ne '') {
    $result .= $q->h3('(' . "redirected from " . 
                               &GetEditLink($oldId, $oldId) . ')');
  }
  if ((!$embed) && ($LogoUrl ne "")) {
    $logoImage = "img src=\"$LogoUrl\" alt=\"$altText\" border=0";
    if (!$LogoLeft) {
      $logoImage .= " align=\"right\"";
    }
    $header = &ScriptLink($HomePage, "<$logoImage>");
  }
  if ($id ne '') {
    $result .= $q->h1($header . &GetSearchLink($id));
  } else {
    $result .= $q->h1($header . $title);
  }
  if (&GetParam("toplinkbar", 1)) {
    # Later consider smaller size?
    $result .= &GetGotoBar($id) . "<hr>";
  }
  return $result;
}

sub GetHttpHeader {
  my $cookie;
  if (defined($SetCookie{'id'})) {
    $cookie = "$CookieName="
            . "rev&" . $SetCookie{'rev'}
            . "&id&" . $SetCookie{'id'}
            . "&randkey&" . $SetCookie{'randkey'};
    $cookie .= ";expires=Fri, 08-Sep-2010 19:48:23 GMT";
    if ($HttpCharset ne '') {
      return $q->header(-cookie=>$cookie,
                        -type=>"text/html; charset=$HttpCharset");
    }
    return $q->header(-cookie=>$cookie);
  }
  if ($HttpCharset ne '') {
    return $q->header(-type=>"text/html; charset=$HttpCharset");
  }
  return $q->header();
}

sub GetHtmlHeader {
  my ($title) = @_;
  my ($dtd, $bgcolor, $html, $bodyExtra);

  $html = '';
  $dtd = '-//IETF//DTD HTML//EN';
  $bgcolor = 'white';  # Later make an option
  $html = qq(<!DOCTYPE HTML PUBLIC "$dtd">\n);
  $title = $q->escapeHTML($title);
  $html .= "<HTML><HEAD><TITLE>$title</TITLE>\n";
  if ($SiteBase ne "") {
    $html .= qq(<BASE HREF="$SiteBase">\n);
  }
  if ($StyleSheet ne '') {
    $html .= qq(<LINK REL="stylesheet" HREF="$StyleSheet">\n);
  }
  # Insert other header stuff here (like inline style sheets?)
  $bodyExtra = '';
  if ($bgcolor ne '') {
    $bodyExtra = qq( BGCOLOR="$bgcolor");
  }
  # Insert any other body stuff (like scripts) into $bodyExtra here
  # (remember to add a space at the beginning to separate from prior text)
  $html .= "</HEAD><BODY$bodyExtra>\n";
  return $html;
}

sub GetFooterText {
  my $section = shift;
  my ($id, $rev) = @_;
  my $result = '';

  if (&GetParam('embed', $EmbedWiki)) {
    return $q->end_html;
  }
  $result = &GetFormStart();
  $result .= &GetGotoBar($id);
  if (&UserCanEdit($id, 0)) {
    if ($rev ne '') {
      $result .= &GetOldPageLink('edit',   $id, $rev,
                                 "Edit revision $rev of this page");
    } else {
      $result .= &GetEditLink($id, 'Edit text of this page');
    }
  } else {
    $result .= 'This page is read-only';
  }
  $result .= ' | ';
  $result .= &GetHistoryLink($id, 'View other revisions');
  if ($rev ne '') {
    $result .= ' | ';
    $result .= &GetPageLinkText($id, 'View current revision');
  }
  if ($section->getRevision() > 0) {
    $result .= '<br>';
    if ($rev eq '') {  # Only for most current rev
      $result .= 'Last edited';
    } else {
      $result .= 'Edited';
    }
    $result .= ' ' . &TimeToText($section->getTS());
  }
  if ($UseDiff) {
    $result .= ' ' . &ScriptLinkDiff(4, $id, '(diff)', $rev);
  }
  $result .= '<br>' . &GetSearchForm();
  if ($DataDir =~ m|/tmp/|) {
    $result .= '<br><b>' . 'Warning' . ':</b> '
               . 'Database is stored in temporary directory '
               . $DataDir . '<br>';
  }
  $result .= $q->endform;
  $result .= &GetMinimumFooter();
  return $result;
}

sub GetCommonFooter {
  return "<hr>" . &GetFormStart() . &GetGotoBar("") .
         &GetSearchForm() . $q->endform . &GetMinimumFooter();
}

sub GetMinimumFooter {
  if ($FooterNote ne '') {
    return $FooterNote . $q->end_html;  # Allow local translations
  }
  return $q->end_html;
}

sub GetFormStart {
  return $q->startform("POST", "$ScriptName",
                       "application/x-www-form-urlencoded");
}

sub GetGotoBar {
  my ($id) = @_;
  my ($main, $bartext);

  $bartext  = &GetPageLink($HomePage);
  if ($id =~ m|/|) {
    $main = $id;
    $main =~ s|/.*||;  # Only the main page name (remove subpage)
    $bartext .= " | " . &GetPageLink($main);
  }
  $bartext .= " | " . &GetPageLink($RCName);
  $bartext .= " | " . &GetPrefsLink();
  if (&GetParam("linkrandom", 0)) {
    $bartext .= " | " . &GetRandomLink();
  }
  if ($UserGotoBar ne '') {
    $bartext .= " | " . $UserGotoBar;
  }
  $bartext .= "<br>\n";
  return $bartext;
}

sub GetSearchForm {
  my ($result);

  $result = 'Search:' . ' ' . $q->textfield(-name=>'search', -size=>20)
            . &GetHiddenValue("dosearch", 1);
  return $result;
}

sub GetRedirectPage {
  my ($newid, $name, $isEdit) = @_;
  my ($url, $html);
  my ($nameLink);

  # Normally get URL from script, but allow override.
  $FullUrl = $q->url(-full=>1)  if ($FullUrl eq "");
  $url = $FullUrl . "?" . $newid;
  $nameLink = "<a href=\"$url\">$name</a>";
  if ($RedirType < 3) {
    if ($RedirType == 1) {             # Use CGI.pm
      # NOTE: do NOT use -method (does not work with old CGI.pm versions)
      # Thanks to Daniel Neri for fixing this problem.
      $html = $q->redirect(-uri=>$url);
    } else {                           # Minimal header
      $html  = "Status: 302 Moved\n";
      $html .= "Location: $url\n";
      $html .= "Content-Type: text/html\n";  # Needed for browser failure
      $html .= "\n";
    }
    $html .= "\n" . "Your browser should go to the $newid page.";
    $html .= ' ' . "If it does not, click $nameLink to continue.";
  } else {
    if ($isEdit) {
      $html  = &GetHeader('', 'Thanks for editing...', '');
      $html .= "Thank you for editing $nameLink";
    } else {
      $html  = &GetHeader('', 'Link to another page...', '');
    }
    $html .= "\n<p>";
    $html .= "Follow the $nameLink link to continue.";
    $html .= &GetMinimumFooter();
  }
  return $html;
}

# ==== Common wiki markup ====
sub WikiToHTML {
  # Use the PurpleWiki::View::wikihtml driver to parse wiki pages to HTML
  my ($pageText) = @_;

  my $wiki = $wikiParser->parse($pageText);
  return $wiki->view('wikihtml');
}

sub QuoteHtml {
  my ($html) = @_;

  $html =~ s/&/&amp;/g;
  $html =~ s/</&lt;/g;
  $html =~ s/>/&gt;/g;
  if (1) {   # Make an official option?
    $html =~ s/&amp;([#a-zA-Z0-9]+);/&$1;/g;  # Allow character references
  }
  return $html;
}

# ==== Misc. functions ====
sub ReportError {
  my ($errmsg) = @_;

  print $q->header, "<H2>", $errmsg, "</H2>", $q->end_html;
}

sub ValidId {
  my ($id) = @_;

  if (length($id) > 120) {
    return "Page name is too long: $id";
  }
  if ($id =~ m| |) {
    return "Page name may not contain space characters: $id";
  }
  if ($UseSubpage) {
    if ($id =~ m|.*/.*/|) {
      return "Too many / characters in page $id";
    }
    if ($id =~ /^\//) {
      return "Invalid Page $id (subpage without main page)";
    }
    if ($id =~ /\/$/) {
      return "Invalid Page $id (missing subpage name)";
    }
  }
  if ($FreeLinks) {
    $id =~ s/ /_/g;
    if (!$UseSubpage) {
      if ($id =~ /\//) {
        return "Invalid Page $id (/ not allowed)";
      }
    }
    if (!($id =~ m|^$FreeLinkPattern$|)) {
      return "Invalid Page $id";
    }
    if ($id =~ m|\.db$|) {
      return "Invalid Page $id (must not end with .db)";
    }
    if ($id =~ m|\.lck$|) {
      return "Invalid Page $id (must not end with .lck)";
    }
    return "";
  } else {
    if (!($id =~ /^$LinkPattern$/)) {
      return "Invalid Page $id";
    }
  }
  return "";
}

sub ValidIdOrDie {
  my ($id) = @_;
  my $error;

  $error = &ValidId($id);
  if ($error ne "") {
    &ReportError($error);
    return 0;
  }
  return 1;
}

sub UserCanEdit {
  my ($id, $deepCheck) = @_;

  # Optimized for the "everyone can edit" case (don't check passwords)
  if (($id ne "") && (-f &PurpleWiki::Database::GetLockedPageFile($id))) {
    return 1  if (&UserIsAdmin());  # Requires more privledges
    # Later option for editor-level to edit these pages?
    return 0;
  }
  if (!$EditAllowed) {
    return 1  if (&UserIsEditor());
    return 0;
  }
  if (-f "$DataDir/noedit") {
    return 1  if (&UserIsEditor());
    return 0;
  }
  if ($deepCheck) {   # Deeper but slower checks (not every page)
    return 1  if (&UserIsEditor());
    return 0  if (&UserIsBanned());
  }
  return 1;
}

sub UserIsBanned {
  my ($host, $ip, $data, $status);

  ($status, $data) = &PurpleWiki::Database::ReadFile("$DataDir/banlist");
  return 0  if (!$status);  # No file exists, so no ban
  $ip = $ENV{'REMOTE_ADDR'};
  $host = &GetRemoteHost(0);
  foreach (split(/\n/, $data)) {
    next  if ((/^\s*$/) || (/^#/));  # Skip empty, spaces, or comments
    return 1  if ($ip   =~ /$_/i);
    return 1  if ($host =~ /$_/i);
  }
  return 0;
}

sub UserIsAdmin {
  my (@pwlist, $userPassword);

  return 0  if ($AdminPass eq "");
  $userPassword = &GetParam("adminpw", "");
  return 0  if ($userPassword eq "");
  foreach (split(/\s+/, $AdminPass)) {
    next  if ($_ eq "");
    return 1  if ($userPassword eq $_);
  }
  return 0;
}

sub UserIsEditor {
  my (@pwlist, $userPassword);

  return 1  if (&UserIsAdmin());             # Admin includes editor
  return 0  if ($EditPass eq "");
  $userPassword = &GetParam("adminpw", "");  # Used for both
  return 0  if ($userPassword eq "");
  foreach (split(/\s+/, $EditPass)) {
    next  if ($_ eq "");
    return 1  if ($userPassword eq $_);
  }
  return 0;
}


sub CalcDay {
  my ($ts) = @_;

  $ts += $TimeZoneOffset;
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime($ts);

  return ("January", "February", "March", "April", "May", "June",
          "July", "August", "September", "October", "November",
          "December")[$mon]. " " . $mday . ", " . ($year+1900);
}

sub CalcDayNow {
  return CalcDay($Now);
}

sub CalcTime {
  my ($ts) = @_;
  my ($ampm, $mytz);

  $ts += $TimeZoneOffset;
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime($ts);

  $mytz = "";
  if (($TimeZoneOffset == 0) && ($ScriptTZ ne "")) {
    $mytz = " " . $ScriptTZ;
  }
  $ampm = "";
  if ($UseAmPm) {
    $ampm = " am";
    if ($hour > 11) {
      $ampm = " pm";
      $hour = $hour - 12;
    }
    $hour = 12   if ($hour == 0);
  }
  $min = "0" . $min   if ($min<10);
  return $hour . ":" . $min . $ampm . $mytz;
}

sub TimeToText {
  my ($t) = @_;

  return &CalcDay($t) . " " . &CalcTime($t);
}

sub GetParam {
  my ($name, $default) = @_;
  my $result;

  $result = $q->param($name);
  if (!defined($result)) {
    if (defined($UserData{$name})) {
      $result = $UserData{$name};
    } else {
      $result = $default;
    }
  }
  return $result;
}

sub GetHiddenValue {
  my ($name, $value) = @_;

  $q->param($name, $value);
  return $q->hidden($name);
}

sub GetRemoteHost {
  my ($doMask) = @_;
  my ($rhost, $iaddr);

  $rhost = $ENV{REMOTE_HOST};
  if ($UseLookup && ($rhost eq "")) {
    # Catch errors (including bad input) without aborting the script
    eval 'use Socket; $iaddr = inet_aton($ENV{REMOTE_ADDR});'
         . '$rhost = gethostbyaddr($iaddr, AF_INET)';
  }
  if ($rhost eq "") {
    $rhost = $ENV{REMOTE_ADDR};
    $rhost =~ s/\d+$/xxx/  if ($doMask);      # Be somewhat anonymous
  }
  return $rhost;
}

sub FreeToNormal {
  my ($id) = @_;

  $id =~ s/ /_/g;
  $id = ucfirst($id);
  if (index($id, '_') > -1) {  # Quick check for any space/underscores
    $id =~ s/__+/_/g;
    $id =~ s/^_//;
    $id =~ s/_$//;
    if ($UseSubpage) {
      $id =~ s|_/|/|g;
      $id =~ s|/_|/|g;
    }
  }
  if ($FreeUpper) {
    # Note that letters after ' are *not* capitalized
    if ($id =~ m|[-_.,\(\)/][a-z]|) {    # Quick check for non-canonical case
      $id =~ s|([-_.,\(\)/])([a-z])|$1 . uc($2)|ge;
    }
  }
  return $id;
}
#END_OF_BROWSE_CODE

# == Page-editing and other special-action code ========================

sub DoOtherRequest {
  my ($id, $action, $text, $search);

  $action = &GetParam("action", "");
  $id = &GetParam("id", "");
  if ($action ne "") {
    $action = lc($action);
    if      ($action eq "edit") {
      &DoEdit($id, 0, 0, "", 0)  if &ValidIdOrDie($id);
    } elsif ($action eq "unlock") {
      &DoUnlock();
    } elsif ($action eq "index") {
      &DoIndex();
    } elsif ($action eq "pagelock") {
      &DoPageLock();
    } elsif ($action eq "editlock") {
      &DoEditLock();
    } elsif ($action eq "editprefs") {
      &DoEditPrefs();
    } elsif ($action eq "editbanned") {
      &DoEditBanned();
    } elsif ($action eq "login") {
      &DoEnterLogin();
    } elsif ($action eq "newlogin") {
      $UserID = 0;
      &DoEditPrefs();  # Also creates new ID
    } elsif ($action eq "version") {
      &DoShowVersion();
    } else {
      # Later improve error reporting
      &ReportError("Invalid action parameter $action");
    }
    return;
  }
  if (&GetParam("edit_prefs", 0)) {
    &DoUpdatePrefs();
    return;
  }
  if (&GetParam("edit_ban", 0)) {
    &DoUpdateBanned();
    return;
  }
  if (&GetParam("enter_login", 0)) {
    &DoLogin();
    return;
  }
  $search = &GetParam("search", "");
  if (($search ne "") || (&GetParam("dosearch", "") ne "")) {
    &DoSearch($search);
    return;
  }
  # Handle posted pages
  if (&GetParam("oldtime", "") ne "") {
    $id = &GetParam("title", "");
    &DoPost()  if &ValidIdOrDie($id);
    return;
  }
  # Later improve error message
  &ReportError('Invalid URL.');
}

sub DoEdit {
  my ($id, $isConflict, $oldTime, $newText, $preview) = @_;
  my ($header, $editRows, $editCols, $userName, $revision, $oldText);
  my ($summary, $isEdit, $pageTime);

  my $page;
  my $section;
  my $text;
  my $keptRevision;

  if (!&UserCanEdit($id, 1)) {
    print &GetHeader("", 'Editing Denied', "");
    if (&UserIsBanned()) {
      print 'Editing not allowed: user, ip, or network is blocked.';
      print "<p>";
      print 'Contact the wiki administrator for more information.';
    } else {
      print "Editing not allowed: $SiteName is read-only.";
    }
    print &GetCommonFooter();
    return;
  }
  # Consider sending a new user-ID cookie if user does not have one
  $keptRevision = new PurpleWiki::Database::KeptRevision($id);
  $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now,
                                 'username' => &GetParam("username", ""),
                                 'userID' => $UserID);
  $page->openPage();
  # FIXME: ordering is import in these next two, it shouldn't be
  $text = $page->getText();
  $section = $page->getSection();
  $pageTime = $section->getTS();
  $header = "Editing $id";
  
  # Old revision handling
  $revision = &GetParam('revision', '');
  $revision =~ s/\D//g;  # Remove non-numeric chars
  if ($revision ne '') {
    if (!$keptRevision->hasRevision($revision)) {
      $revision = '';
      # Later look for better solution, like error message?
    } else {
      # replace text with the revision we care about
      $text = $keptRevision->getRevision($revision)->getText();
      $header = "Editing revision $revision of $id";
    }
  }

  $oldText = $text->getText();

  if ($preview && !$isConflict) {
    $oldText = $newText;
  }

  $editRows = &GetParam("editrows", 20);
  $editCols = &GetParam("editcols", 65);
  print &GetHeader('', &QuoteHtml($header), '');

  if ($revision ne '') {
    print "\n<b>"
          . "Editing old revision $revision "
    . 'Saving this page will replace the latest revision with this text.'
          . '</b><br>'
  }

  if ($isConflict) {
    $editRows -= 10  if ($editRows > 19);
    print "\n<H1>" . 'Edit Conflict!' . "</H1>\n";

    if ($isConflict>1) {
      # The main purpose of a new warning is to display more text
      # and move the save button down from its old location.
      print "\n<H2>" . '(This is a new conflict)' . "</H2>\n";
    }

    print "<p><strong>",
          'Someone saved this page after you started editing.', " ",
          'The top textbox contains the saved text.', " ",
          'Only the text in the top textbox will be saved.',
          "</strong><br>\n",
          'Scroll down to see your edited text.', "<br>\n";
    print 'Last save time:', ' ', &TimeToText($oldTime),
          " (", 'Current time is:', ' ', &TimeToText($Now), ")<br>\n";
  }
  print &GetFormStart();
  print &GetHiddenValue("title", $id), "\n",
        &GetHiddenValue("oldtime", $pageTime), "\n",
        &GetHiddenValue("oldconflict", $isConflict), "\n";
  if ($revision ne "") {
    print &GetHiddenValue("revision", $revision), "\n";
  }
  print &GetTextArea('text', $oldText, $editRows, $editCols);
  $summary = &GetParam("summary", "*");
  print "<p>", 'Summary:',
        $q->textfield(-name=>'summary',
                      -default=>$summary, -override=>1,
                      -size=>60, -maxlength=>200);
  if (&GetParam("recent_edit") eq "on") {
    print "<br>", $q->checkbox(-name=>'recent_edit', -checked=>1,
                               -label=>'This change is a minor edit.');
  } else {
    print "<br>", $q->checkbox(-name=>'recent_edit',
                               -label=>'This change is a minor edit.');
  }
  if ($EmailNotify) {
    print "&nbsp;&nbsp;&nbsp;" .
           $q->checkbox(-name=> 'do_email_notify',
      -label=> "Send email notification that $id has been changed.");
  }
  print "<br>";
  if ($EditNote ne '') {
    print $EditNote . '<br>';  # Allow translation
  }
  print $q->submit(-name=>'Save', -value=>'Save'), "\n";
  $userName = &GetParam("username", "");
  if ($userName ne "") {
    print ' (', 'Your user name is', ' ',
          &GetPageLink($userName) . ') ';
  } else {
    print ' (', sprintf("Visit %s to set your user name.", &GetPrefsLink()), ') ';
  }
  print $q->submit(-name=>'Preview', -value=>'Preview'), "\n";

  if ($isConflict) {
    print "\n<br><hr><p><strong>", 'This is the text you submitted:',
          "</strong><p>",
          &GetTextArea('newtext', $newText, $editRows, $editCols),
          "<p>\n";
  }
  print "<hr>\n";
  if ($preview) {
    print "<h2>", 'Preview:', "</h2>\n";
    if ($isConflict) {
      print "<b>",
            'NOTE: This preview shows the revision of the other author.',
            "</b><hr>\n";
    }
    $MainPage = $id;
    $MainPage =~ s|/.*||;  # Only the main page name (remove subpage)
    print &WikiToHTML($oldText) . "<hr>\n";
    print "<h2>", 'Preview only, not yet saved', "</h2>\n";
  }
  print &GetHistoryLink($id, 'View other revisions') . "<br>\n";
  print &GetGotoBar($id);
  print $q->endform;
  print &GetMinimumFooter();
}

sub GetTextArea {
  my ($name, $text, $rows, $cols) = @_;

  if (&GetParam("editwide", 1)) {
    return $q->textarea(-name=>$name, -default=>$text,
                        -rows=>$rows, -columns=>$cols, -override=>1,
                        -style=>'width:100%', -wrap=>'virtual');
  }
  return $q->textarea(-name=>$name, -default=>$text,
                      -rows=>$rows, -columns=>$cols, -override=>1,
                      -wrap=>'virtual');
}

sub DoEditPrefs {
  my ($check, $recentName, %labels);

  $recentName = $RCName;
  $recentName =~ s/_/ /g;
  &DoNewLogin()  if ($UserID < 400);
  print &GetHeader('', 'Editing Preferences', "");
  print &GetFormStart();
  print GetHiddenValue("edit_prefs", 1), "\n";
  print '<b>' . 'User Information:' . "</b>\n";
  print '<br>' . "Your User ID number: $UserID" . "\n";
  print '<br>' . 'UserName:' . ' ', &GetFormText('username', "", 20, 50);
  print ' ' . '(blank to remove, or valid page name)';
  print '<br>' . 'Set Password:' . ' ',
        $q->password_field(-name=>'p_password', -value=>'*', 
                           -size=>15, -maxlength=>50),
        ' ', '(blank to remove password)', '<br>(',
        'Passwords allow sharing preferences between multiple systems.',
        ' ', 'Passwords are completely optional.', ')';
  if ($AdminPass ne '') {
    print '<br>', 'Administrator Password:', ' ',
          $q->password_field(-name=>'p_adminpw', -value=>'*', 
                             -size=>15, -maxlength=>50),
          ' ', '(blank to remove password)', '<br>',
          '(Administrator passwords are used for special maintenance.)';
  }
  if ($EmailNotify) {
    print "<br>";
    print &GetFormCheck('notify', 1,
          'Include this address in the site email list.'), ' ',
          '(Uncheck the box to remove the address.)';
    print '<br>', 'Email Address:', ' ',
          &GetFormText('email', "", 30, 60);
  }
  print "<hr><b>$recentName:</b>\n";
  print '<br>', 'Default days to display:', ' ',
        &GetFormText('rcdays', $RcDefault, 4, 9);
  print "<br>", &GetFormCheck('rcnewtop', $RecentTop,
                              'Most recent changes on top');
  print "<br>", &GetFormCheck('rcall', 0,
                              'Show all changes (not just most recent)');
  %labels = (0=>'Hide minor edits', 1=>'Show minor edits',
             2=>'Show only minor edits');
  print '<br>', 'Minor edit display:', ' ';
  print $q->popup_menu(-name=>'p_rcshowedit',
                       -values=>[0,1,2], -labels=>\%labels,
                       -default=>&GetParam("rcshowedit", $ShowEdits));
  print "<br>", &GetFormCheck('rcchangehist', 1,
                              'Use "changes" as link to history');
  if ($UseDiff) {
    print '<hr><b>', 'Differences:', "</b>\n";
    print "<br>", &GetFormCheck('diffrclink', 1,
                                "Show (diff) links on $recentName");
    print "<br>", &GetFormCheck('alldiff', 0,
                                'Show differences on all pages');
    print "  (",  &GetFormCheck('norcdiff', 1,
                                "No differences on $recentName"), ")";
    %labels = (1=>'Major', 2=>'Minor', 3=>'Author');
    print '<br>', 'Default difference type:', ' ';
    print $q->popup_menu(-name=>'p_defaultdiff',
                         -values=>[1,2,3], -labels=>\%labels,
                         -default=>&GetParam("defaultdiff", 1));
  }
  print '<hr><b>', 'Misc:', "</b>\n";
  # Note: TZ offset is added by TimeToText, so pre-subtract to cancel.
  print '<br>', 'Server time:', ' ', &TimeToText($Now-$TimeZoneOffset);
  print '<br>', 'Time Zone offset (hours):', ' ',
        &GetFormText('tzoffset', 0, 4, 9);
  print '<br>', &GetFormCheck('editwide', 1,
                              'Use 100% wide edit area (if supported)');
  print '<br>',
        'Edit area rows:', ' ', &GetFormText('editrows', 20, 4, 4),
        ' ', 'columns:',   ' ', &GetFormText('editcols', 65, 4, 4);

  print '<br>', &GetFormCheck('toplinkbar', 1,
                              'Show link bar on top');
  print '<br>', &GetFormCheck('linkrandom', 0,
                              'Add "Random Page" link to link bar');
  print '<br>', $q->submit(-name=>'Save', -value=>'Save'), "\n";
  print "<hr>\n";
  print &GetGotoBar('');
  print $q->endform;
  print &GetMinimumFooter();
}

sub GetFormText {
  my ($name, $default, $size, $max) = @_;
  my $text = &GetParam($name, $default);

  return $q->textfield(-name=>"p_$name", -default=>$text,
                       -override=>1, -size=>$size, -maxlength=>$max);
}

sub GetFormCheck {
  my ($name, $default, $label) = @_;
  my $checked = (&GetParam($name, $default) > 0);

  return $q->checkbox(-name=>"p_$name", -override=>1, -checked=>$checked,
                      -label=>$label);
}

sub DoUpdatePrefs {
  my ($username, $password);

  # All link bar settings should be updated before printing the header
  &UpdatePrefCheckbox("toplinkbar");
  &UpdatePrefCheckbox("linkrandom");
  print &GetHeader('','Saving Preferences', '');
  print '<br>';
  if ($UserID < 1001) {
    print '<b>',
          "Invalid UserID $UserID, preferences not saved.</b>";
    if ($UserID == 111) {
      print '<br>',
            '(Preferences require cookies, but no cookie was sent.)';
    }
    print &GetCommonFooter();
    return;
  }
  $username = &GetParam("p_username",  "");
  if ($FreeLinks) {
    $username =~ s/^\[\[(.+)\]\]/$1/;  # Remove [[ and ]] if added
    $username =  &FreeToNormal($username);
    $username =~ s/_/ /g;
  }
  if ($username eq "") {
    print 'UserName removed.', '<br>';
    undef $UserData{'username'};
  } elsif ((!$FreeLinks) && (!($username =~ /^$LinkPattern$/))) {
    print "Invalid UserName $username: not saved.<br>\n";
  } elsif ($FreeLinks && (!($username =~ /^$FreeLinkPattern$/))) {
    print "Invalid UserName $username: not saved.<br>\n";
  } elsif (length($username) > 50) {  # Too long
    print 'UserName must be 50 characters or less. (not saved)', "<br>\n";
  } else {
    print "UserName $username saved.<br>";
    $UserData{'username'} = $username;
  }
  $password = &GetParam("p_password",  "");
  if ($password eq "") {
    print 'Password removed.', '<br>';
    undef $UserData{'password'};
  } elsif ($password ne "*") {
    print 'Password changed.', '<br>';
    $UserData{'password'} = $password;
  }
  if ($AdminPass ne "") {
    $password = &GetParam("p_adminpw",  "");
    if ($password eq "") {
      print 'Administrator password removed.', '<br>';
      undef $UserData{'adminpw'};
    } elsif ($password ne "*") {
      print 'Administrator password changed.', '<br>';
      $UserData{'adminpw'} = $password;
      if (&UserIsAdmin()) {
        print 'User has administrative abilities.', '<br>';
      } elsif (&UserIsEditor()) {
        print 'User has editor abilities.', '<br>';
      } else {
        print 'User does not have administrative abilities.', ' ',
              '(Password does not match administrative password(s).)',
              '<br>';
      }
    }
  }
  if ($EmailNotify) {
    &UpdatePrefCheckbox("notify");
    &UpdateEmailList();
  }
  &UpdatePrefNumber("rcdays", 0, 0, 999999);
  &UpdatePrefCheckbox("rcnewtop");
  &UpdatePrefCheckbox("rcall");
  &UpdatePrefCheckbox("rcchangehist");
  &UpdatePrefCheckbox("editwide");
  if ($UseDiff) {
    &UpdatePrefCheckbox("norcdiff");
    &UpdatePrefCheckbox("diffrclink");
    &UpdatePrefCheckbox("alldiff");
    &UpdatePrefNumber("defaultdiff", 1, 1, 3);
  }
  &UpdatePrefNumber("rcshowedit", 1, 0, 2);
  &UpdatePrefNumber("tzoffset", 0, -999, 999);
  &UpdatePrefNumber("editrows", 1, 1, 999);
  &UpdatePrefNumber("editcols", 1, 1, 999);
  print 'Server time:', ' ', &TimeToText($Now-$TimeZoneOffset), '<br>';
  $TimeZoneOffset = &GetParam("tzoffset", 0) * (60 * 60);
  print 'Local time:', ' ', &TimeToText($Now), '<br>';

  &PurpleWiki::Database::SaveUserData(\%UserData, $UserID);
  print '<b>', 'Preferences saved.', '</b>';
  print &GetCommonFooter();
}

# add or remove email address from preferences to $DatDir/emails
sub UpdateEmailList {
  my (@old_emails);

  local $/ = "\n";  # don't slurp whole files in this sub.
  if (my $new_email = $UserData{'email'} = &GetParam("p_email", "")) {
    my $notify = $UserData{'notify'};
    if (-f "$DataDir/emails") {
      open(NOTIFY, "$DataDir/emails")
        or die("Could not read from $DataDir/emails: $!\n");
      @old_emails = <NOTIFY>;
      close(NOTIFY);
    } else {
      @old_emails = ();
    }
    my $already_in_list = grep /$new_email/, @old_emails;
    if ($notify and (not $already_in_list)) {
      &RequestLock() or die('Could not get mail lock');
      open(NOTIFY, ">>$DataDir/emails")
        or die("Could not append to $DataDir/emails: $!\n");
      print NOTIFY $new_email, "\n";
      close(NOTIFY);
      &PurpleWiki::Database::ReleaseLock();
    }
    elsif ((not $notify) and $already_in_list) {
      &RequestLock() or die('Could not get mail lock');
      open(NOTIFY, ">$DataDir/emails")
        or die("Could not overwrite $DataDir/emails: $!\n");
      foreach (@old_emails) {
        print NOTIFY "$_" unless /$new_email/;
      }
      close(NOTIFY);
      &PurpleWiki::Database::ReleaseLock();
    }
  }
}

sub UpdatePrefCheckbox {
  my ($param) = @_;
  my $temp = &GetParam("p_$param", "*");

  $UserData{$param} = 1  if ($temp eq "on");
  $UserData{$param} = 0  if ($temp eq "*");
  # It is possible to skip updating by using another value, like "2"
}

sub UpdatePrefNumber {
  my ($param, $integer, $min, $max) = @_;
  my $temp = &GetParam("p_$param", "*");

  return  if ($temp eq "*");
  $temp =~ s/[^-\d\.]//g;
  $temp =~ s/\..*//  if ($integer);
  return  if ($temp eq "");
  return  if (($temp < $min) || ($temp > $max));
  $UserData{$param} = $temp;
  # Later consider returning status?
}

sub DoIndex {
  print &GetHeader('', 'Index of all pages', '');
  print '<br>';
  &PrintPageList(&PurpleWiki::Database::AllPagesList());
  print &GetCommonFooter();
}

# Create a new user file/cookie pair
sub DoNewLogin {
  # Later consider warning if cookie already exists
  # (maybe use "replace=1" parameter)
  &PurpleWiki::Database::CreateUserDir();
  $SetCookie{'id'} = &PurpleWiki::Database::GetNewUserId;
  $SetCookie{'randkey'} = int(rand(1000000000));
  $SetCookie{'rev'} = 1;
  %UserCookie = %SetCookie;
  $UserID = $SetCookie{'id'};
  # The cookie will be transmitted in the next header
  %UserData = %UserCookie;
  $UserData{'createtime'} = $Now;
  $UserData{'createip'} = $ENV{REMOTE_ADDR};
  &PurpleWiki::Database::SaveUserData(\%UserData, $UserID);
}

sub DoEnterLogin {
  print &GetHeader('', 'Login', "");
  print &GetFormStart();
  print &GetHiddenValue('enter_login', 1), "\n";
  print '<br>', 'User ID number:', ' ',
        $q->textfield(-name=>'p_userid', -value=>'',
                      -size=>15, -maxlength=>50);
  print '<br>', 'Password:', ' ',
        $q->password_field(-name=>'p_password', -value=>'', 
                           -size=>15, -maxlength=>50);
  print '<br>', $q->submit(-name=>'Login', -value=>'Login'), "\n";
  print "<hr>\n";
  print &GetGotoBar('');
  print $q->endform;
  print &GetMinimumFooter();
}

sub DoLogin {
  my ($uid, $password, $success);

  $success = 0;
  $uid = &GetParam("p_userid", "");
  $uid =~ s/\D//g;
  $password = &GetParam("p_password",  "");
  if (($uid > 199) && ($password ne "") && ($password ne "*")) {
    $UserID = $uid;
    if (&PurpleWiki::Database::LoadUserData($UserID, \%UserData)) {
      if (defined($UserData{'password'}) &&
          ($UserData{'password'} eq $password)) {
        $SetCookie{'id'} = $uid;
        $SetCookie{'randkey'} = $UserData{'randkey'};
        $SetCookie{'rev'} = 1;
        $success = 1;
      }
    }
  }
  print &GetHeader('', 'Login Results', '');
  if ($success) {
    print "Login for user ID $uid complete.";
  } else {
    print "Login for user ID $uid failed.";
  }
  print "<hr>\n";
  print &GetGotoBar('');
  print $q->endform;
  print &GetMinimumFooter();
}


sub DoSearch {
  my ($string) = @_;

  if ($string eq '') {
    &DoIndex();
    return;
  }
  print &GetHeader('', &QuoteHtml("Search for: $string"), '');
  print '<br>';
  &PrintPageList(&SearchTitleAndBody($string));
  print &GetCommonFooter();
}

sub PrintPageList {
  my $pagename;

  print "<h2>", sprintf("%s pages found:", ($#_ + 1)), "</h2>\n";
  foreach $pagename (@_) {
    print ".... "  if ($pagename =~ m|/|);
    print &GetPageLink($pagename), "<br>\n";
  }
}

sub DoPost {
  my ($editDiff, $old, $newAuthor, $pgtime, $oldrev, $preview, $user);
  my $string = &GetParam("text", undef);
  my $id = &GetParam("title", "");
  my $summary = &GetParam("summary", "");
  my $oldtime = &GetParam("oldtime", "");
  my $oldconflict = &GetParam("oldconflict", "");
  my $isEdit = 0;
  my $editTime = $Now;
  my $authorAddr = $ENV{REMOTE_ADDR};

  # adjust the contents of $string with the wiki drivers to save purple
  # numbers

  # clean \r out of string
  $string =~ s/\r//g;

  my $wiki = $wikiParser->parse($string, 'add_node_ids'=>1);
  my $output = $wiki->view('wikitext');

  $string = $output;

  # clean \r out of string
  $string =~ s/\r//g;

  if (!&UserCanEdit($id, 1)) {
    # This is an internal interface--we don't need to explain
    &ReportError("Editing not allowed for $id.");
    return;
  }

  if (($id eq 'SampleUndefinedPage') || ($id eq 'SampleUndefinedPage')) {
    &ReportError("$id cannot be defined.");
    return;
  }
  if (($id eq 'Sample_Undefined_Page')
      || ($id eq 'Sample_Undefined_Page')) {
    &ReportError("[[$id]] cannot be defined.");
    return;
  }
  $string =~ s/$FS//g;
  $summary =~ s/$FS//g;
  $summary =~ s/[\r\n]//g;
  # Add a newline to the end of the string (if it doesn't have one)
  $string .= "\n"  if (!($string =~ /\n$/));

  # Lock before getting old page to prevent races
  &PurpleWiki::Database::RequestLock() or die('Could not get editing lock');
  # Consider extracting lock section into sub, and eval-wrap it?
  # (A few called routines can die, leaving locks.)
  my $keptRevision = new PurpleWiki::Database::KeptRevision($id);
  my $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now);
  $page->openPage();
  my $text = $page->getText();
  my $section = $page->getSection();
  $old = $text->getText();
  $oldrev = $section->getRevision();
  $pgtime = $section->getTS();

  $preview = 0;
  $preview = 1  if (&GetParam("Preview", "") ne "");
  if (!$preview && ($old eq $string)) {  # No changes (ok for preview)
    &PurpleWiki::Database::ReleaseLock();
    &ReBrowsePage($id, "", 1);
    return;
  }
  # Later extract comparison?
  if (($UserID > 399) || ($section->getID() > 399))  {
    $newAuthor = ($UserID ne $section->getID());       # known user(s)
  } else {
    $newAuthor = ($section->getIP() ne $authorAddr);  # hostname fallback
  }
  $newAuthor = 1  if ($oldrev == 0);  # New page
  $newAuthor = 0  if (!$newAuthor);   # Standard flag form, not empty
  # Detect editing conflicts and resubmit edit
  if (($oldrev > 0) && ($newAuthor && ($oldtime != $pgtime))) {
    &PurpleWiki::Database::ReleaseLock();
    if ($oldconflict>0) {  # Conflict again...
      &DoEdit($id, 2, $pgtime, $string, $preview);
    } else {
      &DoEdit($id, 1, $pgtime, $string, $preview);
    }
    return;
  }
  if ($preview) {
    &PurpleWiki::Database::ReleaseLock();
    &DoEdit($id, 0, $pgtime, $string, 1);
    return;
  }

  $user = &GetParam("username", "");
  # If the person doing editing chooses, send out email notification
  if ($EmailNotify) {
    EmailNotify($page, $id, $user) if &GetParam("do_email_notify", "") eq 'on';
  }
  if (&GetParam("recent_edit", "") eq 'on') {
    $isEdit = 1;
  }
  if (!$isEdit) {
    $page->setPageCache('oldmajor', $section->getRevision());
  }
  if ($newAuthor) {
    $page->setPageCache('oldauthor', $section->getRevision());
  }

  $keptRevision->addSection($section, $Now);
  $keptRevision->trimKepts($Now);
  $keptRevision->save();

  if ($UseDiff) {
    &PurpleWiki::Database::UpdateDiffs($page, $keptRevision, $id, $editTime, $old, $string, $isEdit, $newAuthor);
  }
  $text->setText($string);
  $text->setMinor($isEdit);
  $text->setNewAuthor($newAuthor);
  $text->setSummary($summary);
  $section->setHost(&GetRemoteHost(1));
  # FIXME: redundancy in data structure here
  $section->setRevision($section->getRevision() + 1);
  $section->setTS($Now);
  $page->setRevision($section->getRevision());
  $page->setTS($Now);
  $page->save();
  &WriteRcLog($id, $summary, $isEdit, $editTime, $user, $section->getHost());
  &PurpleWiki::Database::ReleaseLock();
  &ReBrowsePage($id, "", 1);
}

# Translation note: the email messages are still sent in English
# Send an email message.
sub SendEmail {
  my ($to, $from, $reply, $subject, $message) = @_;
    ### debug
    ## print "Content-type: text/plain\n\n";
    ## print " to: '$to'\n";
    ## return;
  # sendmail options:
  #    -odq : send mail to queue (i.e. later when convenient)
  #    -oi  : do not wait for "." line to exit
  #    -t   : headers determine recipient.
  open (SENDMAIL, "| $SendMail -oi -t ") or die "Can't send email: $!\n";
  print SENDMAIL <<"EOF";
From: $from
To: $to
Reply-to: $reply
Subject: $subject\n
$message
EOF
  close(SENDMAIL) or warn "sendmail didn't close nicely";
}

## Email folks who want to know a note that a page has been modified. - JimM.
sub EmailNotify {
  local $/ = "\n";   # don't slurp whole files in this sub.
  if ($EmailNotify) {
    my ($page, $id, $user) = @_;
    if ($user) {
      $user = " by $user";
    }
    my $address;
    open(EMAIL, "$DataDir/emails")
      or die "Can't open $DataDir/emails: $!\n";
    $address = join ",", <EMAIL>;
    $address =~ s/\n//g;
    close(EMAIL);
    my $revision = $page->getRevision();
    my $home_url = $q->url();
    my $page_url = $home_url . "?$id";
    my $editors_summary = $q->param("summary");
    if (($editors_summary eq "*") or ($editors_summary eq "")){
      $editors_summary = "";
    }
    else {
      $editors_summary = "\n Summary: $editors_summary";
    }
    my $content = <<"END_MAIL_CONTENT";

 The $SiteName page $id at
   $page_url
 has been changed$user to revision $revision . $editors_summary

 (Replying to this notification will
  send email to the entire mailing list,
  so only do that if you mean to.

  To remove yourself from this list, visit
  ${home_url}?action=editprefs .)
END_MAIL_CONTENT
    my $subject = "The $id page at $SiteName has been changed.";
    # I'm setting the "reply-to" field to be the same as the "to:" field
    # which seems appropriate for a mailing list, especially since the
    # $EmailFrom string needn't be a real email address.
    &SendEmail($address, $EmailFrom, $address, $subject, $content);
  }
}

sub SearchTitleAndBody {
  my ($string) = @_;
  my ($name, $freeName, @found);
  my $page;
  my $text;

  foreach $name (&PurpleWiki::Database::AllPagesList()) {
    $page = new PurpleWiki::Database::Page('id' => $name, 'now' => $Now);
    $page->openPage();
    $text = $page->getText();
    if (($text->getText() =~ /$string/i) || ($name =~ /$string/i)) {
      push(@found, $name);
    } elsif ($FreeLinks && ($name =~ m/_/)) {
      $freeName = $name;
      $freeName =~ s/_/ /g;
      if ($freeName =~ /$string/i) {
        push(@found, $name);
      }
    }
  }
  return @found;
}

sub SearchBody {
  my ($string) = @_;
  my ($name, @found);
  my $page;
  my $text;

  foreach $name (&PurpleWiki::Database::AllPagesList()) {
    $page = new PurpleWiki::Database::Page('id' => $name, 'now' => $Now);
    $page->openPage();
    $text = $page->getText();
    if ($text->getText() =~ /$string/i) {
      push(@found, $name);
    }
  }
  return @found;
}

# Note: all diff and recent-list operations should be done within locks.
sub DoUnlock {
  my $LockMessage = 'Normal Unlock.';

  print &GetHeader('', 'Removing edit lock', '');
  print '<p>', 'This operation may take several seconds...', "\n";
  if (&ForceReleaseLock('main')) {
    $LockMessage = 'Forced Unlock.';
  }
  # Later display status of other locks?
  &ForceReleaseLock('cache');
  &ForceReleaseLock('diff');
  &ForceReleaseLock('index');
  print "<br><h2>$LockMessage</h2>";
  print &GetCommonFooter();
}

# Note: all diff and recent-list operations should be done within locks.
sub WriteRcLog {
  my ($id, $summary, $isEdit, $editTime, $name, $rhost) = @_;
  my ($extraTemp, %extra);

  %extra = ();
  $extra{'id'} = $UserID  if ($UserID > 0);
  $extra{'name'} = $name  if ($name ne "");
  $extraTemp = join($FS2, %extra);
  # The two fields at the end of a line are kind and extension-hash
  my $rc_line = join($FS3, $editTime, $id, $summary,
                     $isEdit, $rhost, "0", $extraTemp);
  if (!open(OUT, ">>$RcFile")) {
    die("$RCName log error: $!");
  }
  print OUT  $rc_line . "\n";
  close(OUT);
}

sub UserIsEditorOrError {
  if (!&UserIsEditor()) {
    print '<p>', 'This operation is restricted to site editors only...';
    print &GetCommonFooter();
    return 0;
  }
  return 1;
}

sub UserIsAdminOrError {
  if (!&UserIsAdmin()) {
    print '<p>', 'This operation is restricted to administrators only...';
    print &GetCommonFooter();
    return 0;
  }
  return 1;
}

sub DoEditLock {
  my ($fname);

  print &GetHeader('', 'Set or Remove global edit lock', '');
  return  if (!&UserIsAdminOrError());
  $fname = "$DataDir/noedit";
  if (&GetParam("set", 1)) {
    &WriteStringToFile($fname, "editing locked.");
  } else {
    unlink($fname);
  }
  if (-f $fname) {
    print '<p>', 'Edit lock created.', '<br>';
  } else {
    print '<p>', 'Edit lock removed.', '<br>';
  }
  print &GetCommonFooter();
}

sub DoPageLock {
  my ($fname, $id);

  print &GetHeader('', 'Set or Remove page edit lock', '');
  # Consider allowing page lock/unlock at editor level?
  return  if (!&UserIsAdminOrError());
  $id = &GetParam("id", "");
  if ($id eq "") {
    print '<p>', 'Missing page id to lock/unlock...';
    return;
  }
  return  if (!&ValidIdOrDie($id));       # Later consider nicer error?
  $fname = &PurpleWiki::Database::GetLockedPageFile($id);
  if (&GetParam("set", 1)) {
    &WriteStringToFile($fname, "editing locked.");
  } else {
    unlink($fname);
  }
  if (-f $fname) {
    print '<p>', "Lock for $id created.", '<br>';
  } else {
    print '<p>', "Lock for $id removed.", '<br>';
  }
  print &GetCommonFooter();
}

sub DoEditBanned {
  my ($banList, $status);

  print &GetHeader("", "Editing Banned list", "");
  return  if (!&UserIsAdminOrError());
  ($status, $banList) = &PurpleWiki::Database::ReadFile("$DataDir/banlist");
  $banList = ""  if (!$status);
  print &GetFormStart();
  print GetHiddenValue("edit_ban", 1), "\n";
  print "<b>Banned IP/network/host list:</b><br>\n";
  print "<p>Each entry is either a commented line (starting with #), ",
        "or a Perl regular expression (matching either an IP address or ",
        "a hostname).  <b>Note:</b> To test the ban on yourself, you must ",
        "give up your admin access (remove password in Preferences).";
  print "<p>Examples:<br>",
        "\\.foocorp.com\$  (blocks hosts ending with .foocorp.com)<br>",
        "^123.21.3.9\$  (blocks exact IP address)<br>",
        "^123.21.3.  (blocks whole 123.21.3.* IP network)<p>";
  print &GetTextArea('banlist', $banList, 12, 50);
  print "<br>", $q->submit(-name=>'Save'), "\n";
  print "<hr>\n";
  print &GetGotoBar("");
  print $q->endform;
  print &GetMinimumFooter();
}

sub DoUpdateBanned {
  my ($newList, $fname);

  print &GetHeader("", "Updating Banned list", "");
  return  if (!&UserIsAdminOrError());
  $fname = "$DataDir/banlist";
  $newList = &GetParam("banlist", "#Empty file");
  if ($newList eq "") {
    print "<p>Empty banned list or error.";
    print "<p>Resubmit with at least one space character to remove.";
  } elsif ($newList =~ /^\s*$/s) {
    unlink($fname);
    print "<p>Removed banned list";
  } else {
    &WriteStringToFile($fname, $newList);
    print "<p>Updated banned list";
  }
  print &GetCommonFooter();
}

sub DoShowVersion {
  print &GetHeader("", "Displaying Wiki Version", "");
  print "<p>UseModWiki version 0.92<p>\n";
  print &GetCommonFooter();
}
#END_OF_OTHER_CODE

&DoWikiRequest()  if ($RunCGI && ($_ ne 'nocgi'));   # Do everything.
1; # In case we are loaded from elsewhere
# == End of UseModWiki script. ===========================================
