#!/usr/bin/perl
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# wiki.pl - PurpleWiki
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

package UseModWiki;
use strict;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Config;
use PurpleWiki::Database;
use PurpleWiki::Database::Page;
use PurpleWiki::Database::User;
use PurpleWiki::Database::KeptRevision;
use PurpleWiki::Search::Engine;
use PurpleWiki::Syndication::Rss;
use PurpleWiki::Template::TT;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Session;

my $CONFIG_DIR='/var/www/wikidb';

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

local $| = 1;  # Do not buffer output (localized for mod_perl)

my $ScriptName;         # the name by which this script is called
my $wikiParser;         # the reference to the PurpleWiki Parser
my $wikiTemplate;       # the reference to the PurpleWiki template driver
my $config;             # our PurpleWiki::Config reference
my $InterSiteInit = 0;
my %InterSite;
my $user;               # our reference to the logged in user
my $session;            # CGI::Session object

my $q;                  # CGI query reference
my $Now;                # The time at the beginning of the request
my $UserID;             # UserID of the current session. FIXME: can we
                        # get this off $user reliably?
my $TimeZoneOffset;     # User's prefernce for timezone. FIXME: can we
                        # get this off $user reliably? Doesn't look
                        # worth it.

# we only need one of each these per run
$config = new PurpleWiki::Config($CONFIG_DIR);
$wikiParser = PurpleWiki::Parser::WikiText->new;
# FIXME: would be cool if there were a way to factory this based off a
#        config value.
$wikiTemplate = new PurpleWiki::Template::TT(templateDir => "$CONFIG_DIR/templates");

# Set our umask if one was put in the config file. - matthew
umask(oct($config->Umask)) if defined $config->Umask;

# The "main" program, called from the end of this script file.
sub DoWikiRequest {
  &InitRequest() or return;

  # Instantiate PurpleWiki parser.

  if (!&DoBrowseRequest()) {
    &DoOtherRequest();
  }

}

# == Common and cache-browsing code ====================================

sub InitRequest {
  $CGI::POST_MAX = $config->MaxPost;
  $CGI::DISABLE_UPLOADS = 1;  # no uploads
  $q = new CGI;

  $Now = time;                     # Reset in case script is persistent
  $ScriptName = $q->url('relative' => 1);  # Name used in links
  $PurpleWiki::Page::MainPage = ".";  # For subpages only, the name of the top-level page
  &PurpleWiki::Database::CreateDir($config->DataDir);  # Create directory if it doesn't exist
  if (!-d $config->DataDir) {
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          dataDir => $config->DataDir,
                          preferencesUrl => $config->ScriptName . '?action=editprefs');
      print &GetHttpHeader . $wikiTemplate->process('errors/dataDirCannotCreate');
      return 0;
  }
  &InitCookie();         # Reads in user data
  return 1;
}

sub InitCookie {
  $TimeZoneOffset = 0;
  undef $q->{'.cookies'};  # Clear cache if it exists (for SpeedyCGI)

  my $sid = $q->cookie($config->SiteName);
  $session = CGI::Session->new("driver:File", $sid,
                               {Directory => "$CONFIG_DIR/sessions"});
  $UserID = $session->param('userId');
  $UserID =~ s/\D//g;  # Numeric only
  if ($UserID < 1001) {
    $UserID = 200;
    $user = new PurpleWiki::Database::User('id' => $UserID);
    $session->param('userId', 200);
  }
  else {
    $user = new PurpleWiki::Database::User('id' => $UserID);
    if ($user->userExists()) {
      if ($user->getField('id') != $session->param('userId')) {
        $UserID = 200;
        $session->param('userId', 200);
      }
    }
  }
  if ($user->getField('tzoffset') != 0) {
    $TimeZoneOffset = $user->getField('tzoffset') * (60 * 60);
  }
}

sub DoBrowseRequest {
  my ($id, $action, $text);
  my $page;

  if (!$q->param) {             # No parameter
    &BrowsePage($config->HomePage);
    return 1;
  }
  $id = &GetParam('keywords', '');
  $page = new PurpleWiki::Database::Page('id' => $id);
  if ($id) {                    # Just script?PageName
    if ($config->FreeLinks && (!$page->pageExists())) {
      $id = &FreeToNormal($id);
    }
    &BrowsePage($id)  if &ValidIdOrDie($id);
    return 1;
  }
  $action = lc(&GetParam('action', ''));
  $id = &GetParam('id', '');
  $page = new PurpleWiki::Database::Page('id' => $id);
  if ($action eq 'browse') {
    if ($config->FreeLinks && (!$page->pageExists())) {
      $id = &FreeToNormal($id);
    }
    &BrowsePage($id)  if &ValidIdOrDie($id);
    return 1;
  } elsif ($action eq 'rc') {
    &BrowsePage($config->RCName);
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
  my $body;
  my ($fullHtml, $oldId, $allDiff, $showDiff, $openKept);
  my ($revision, $goodRevision, $diffRevision, $newText);

  my ($page, $section, $text, $keptRevision, $keptSection);

  $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now,
                                    'userID' => $UserID, 
                                    'username' => GetParam("username", ""));
  $page->openPage();
  $section = $page->getSection();
  $text = $page->getText();
  $newText = $text->getText();
  $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id);

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
    if (($config->FreeLinks) && ($text->getText() =~ /\#REDIRECT\s+\[\[.+\]\]/)) {
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
  $PurpleWiki::Page::MainPage = $id;
  $PurpleWiki::Page::MainPage =~ s|/.*||;  # Only the main page name (remove subpage)

  if ($revision ne '') {
    # Later maybe add edit time?
    if ($goodRevision ne '') {
      $text = $keptRevision->getRevision($revision)->getText();
    }
  }
  $allDiff  = &GetParam('alldiff', 0);

  if ($allDiff != 0) {
    $allDiff = &GetParam('defaultdiff', 1);
  }

  if (($id eq $config->RCName) && &GetParam('norcdiff', 1)) {
    $allDiff = 0;  # Only show if specifically requested
  }

  $showDiff = &GetParam('diff', $allDiff);

  my $pageName = $id;
  if ($config->FreeLinks) {
      $pageName =~ s/_/ /g;
  }

  my $lastEdited = &TimeToText($section->getTS());

  if ($config->UseDiff && $showDiff) {
    $diffRevision = $goodRevision;
    $diffRevision = &GetParam('diffrevision', $diffRevision);

    &DoDiff($page, $keptRevision, $showDiff, $id, $pageName, $lastEdited,
            $diffRevision, $newText);
    return;
  }

  $body = &WikiToHTML($id, $text->getText());

  if ($id eq $config->RCName) {
      &DoRc($id, $pageName, $revision, $goodRevision, $lastEdited, $body);
      return;
  }
  $wikiTemplate->vars(siteName => $config->SiteName,
                      pageName => $pageName,
                      cssFile => $config->StyleSheet,
                      siteBase => $config->SiteBase,
                      baseUrl => $config->ScriptName,
                      homePage => $config->HomePage,
                      showRevision => $revision,
                      revision => $goodRevision,
                      body => $body,
                      lastEdited => $lastEdited,
                      pageUrl => $config->ScriptName . "?$id",
                      backlinksUrl => $config->ScriptName . "?search=$id",
                      preferencesUrl => $config->ScriptName . '?action=editprefs',
                      editUrl => $config->ScriptName . "?action=edit&id=$id",
                      revisionsUrl => $config->ScriptName . "?action=history&id=$id",
                      diffUrl => $config->ScriptName . "?action=browse&diff=1&id=$id");
  print &GetHttpHeader . $wikiTemplate->process('viewPage');
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
    my ($id, $pageName, $revision, $goodRevision, $lastEdited, $body) = @_;
    my $starttime = 0;
    my $daysago;
    my @rcDays;

    foreach my $days (@{$config->RcDays}) {
        push @rcDays, { num => $days,
                        url => $config->ScriptName .
                            "?action=rc&days=$days" };
    }
    if (&GetParam("from", 0)) {
        $starttime = &GetParam("from", 0);
    }
    else {
        $daysago = &GetParam("days", 0);
        $daysago = &GetParam("rcdays", 0)  if ($daysago == 0);
        if ($daysago) {
            $starttime = $Now - ((24*60*60)*$daysago);
        }
    }
    if ($starttime == 0) {
        $starttime = $Now - ((24*60*60) * $config->RcDefault);
        $daysago = $config->RcDefault;
    }
    my $rcRef = &PurpleWiki::Database::recentChanges($config, $starttime);
    my @recentChanges;
    my $prevDate;
    foreach my $page (@{$rcRef}) {
        my $date = &CalcDay($page->{timeStamp});
        if ($date ne $prevDate) {
            push @recentChanges, { date => $date, pages => [] };
            $prevDate = $date;
        }
        push @{$recentChanges[$#recentChanges]->{pages}},
            { name => $page->{name},
              time => &CalcTime($page->{timeStamp}),
              numChanges => $page->{numChanges},
              summary => &QuoteHtml($page->{summary}),
              userName => $page->{userName},
              userId => $page->{userId},
              host => $page->{host},
              diffUrl => $config->ScriptName .
                  '?action=browse&diff=1&id=' . $page->{name},
              changeUrl => $config->ScriptName .
                  '?action=history&id=' . $page->{name} };
    }
    $wikiTemplate->vars(siteName => $config->SiteName,
                        pageName => $pageName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        showRevision => $revision,
                        revision => $goodRevision,
                        body => $body,
                        daysAgo => $daysago,
                        rcDays => \@rcDays,
                        changesFrom => &TimeToText($starttime),
                        currentDate => &TimeToText($Now),
                        recentChanges => \@recentChanges,
                        lastEdited => $lastEdited,
                        pageUrl => $config->ScriptName . "?$id",
                        backlinksUrl => $config->ScriptName . "?search=$id",
                        preferencesUrl => $config->ScriptName . '?action=editprefs',
                        editUrl => $config->ScriptName . "?action=edit&id=$id",
                        revisionsUrl => $config->ScriptName . "?action=history&id=$id",
                        diffUrl => $config->ScriptName . "?action=browse&diff=1&id=$id");
    print &GetHttpHeader . $wikiTemplate->process('viewRecentChanges');
}

sub DoRandom {
  my ($id, @pageList);

  @pageList = &PurpleWiki::Database::AllPagesList($config);  # Optimize?
  $id = $pageList[int(rand($#pageList + 1))];
  &ReBrowsePage($id, "", 0);
}

sub DoHistory {
    my ($id) = @_;
    my $page;
    my $text;
    my $keptRevision;
    my @pageHistory;

    $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now);
    $page->openPage();

    push @pageHistory, &getRevisionHistory($id, $page->getSection, 1);
    $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id);
    foreach my $section (reverse sort {$a->getRevision() <=> $b->getRevision()}
                         $keptRevision->getSections()) {
        # If KeptRevision == Current Revision don't print it. - matthew
        if ($section->getRevision() != $page->getSection()->getRevision()) {
            push @pageHistory, &getRevisionHistory($id, $section, 0);
        }
    }

    $wikiTemplate->vars(siteName => $config->SiteName,
                        pageName => $id,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        pageHistory => \@pageHistory,
                        preferencesUrl => $config->ScriptName . '?action=editprefs');
    print &GetHttpHeader . $wikiTemplate->process('viewPageHistory');
}

sub getRevisionHistory {
    my ($id, $section, $isCurrent) = @_;
    my ($rev, $summary, $host, $user, $uid, $ts, $pageUrl, $diffUrl);

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

    if ($isCurrent) {
        $pageUrl = $config->ScriptName . "?$id";
    }
    else {
        $pageUrl = $config->ScriptName . "?action=browse&id=$id&revision=$rev";
        $diffUrl = $config->ScriptName .
            "?action=browse&diff=1&id=$id&diffrevision=$rev";
    }
    if (defined($summary) && ($summary ne "") && ($summary ne "*")) {
        $summary = &QuoteHtml($summary);   # Thanks Sunir! :-)
    }
    else {
        $summary = '';
    }
    return { revision => $rev,
             dateTime => &TimeToText($ts),
             host => $host,
             user => $user,
             summary => $summary,
             pageUrl => $pageUrl,
             diffUrl => $diffUrl };
}

# ==== page-oriented functions ====
sub GetHttpHeader {
    my $cookie = $q->cookie(-name => $config->SiteName,
                            -value => $session->id,
                            -path => '/cgi-bin/',
                            -expires => '+7d');
    if ($config->HttpCharset ne '') {
        return $q->header(-cookie=>$cookie,
                          -type=>"text/html; charset=" . $config->HttpCharset);
    }
    return $q->header(-cookie=>$cookie);
}

# Returns the URL of a page after it has 
# been edited. This used to do lots of
# hoops if CGI.pm was not being used,
# but we don't worry about that anymore.
sub GetRedirectPage {
  my ($newid, $name, $isEdit) = @_;
  my ($url, $html);

  if ($config->FullUrl ne "") {
    $url = $config->FullUrl;
  } else {
    $url = $q->url(-full=>1);
  }

  $url = $url . "?" . $newid;

  $html = $q->redirect(-uri=>$url);
  return $html;
}

# ==== Common wiki markup ====
sub WikiToHTML {
  # Use the PurpleWiki::View::wikihtml driver to parse wiki pages to HTML
  my $id = shift;
  my $pageText = shift;

  my $wiki = $wikiParser->parse($pageText, 'freelink' => $config->FreeLinks);
  my $url = $q->url(-full => 1) . '?' . $id;
  return $wiki->view('wikihtml', url => $url, pageName => $id);
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
sub ValidId {
  my ($id) = @_;

  if (length($id) > 120) {
    return "pageNameTooLong";
  }
  if ($id =~ m| |) {
    return "pageNameTooManyChars";
  }
  if ($config->UseSubpage()) {
    if ($id =~ m|.*/.*/|) {
      return "pageNameTooManySlashes";
    }
    if ($id =~ /^\//) {
      return "pageNameNoMainPage";
    }
    if ($id =~ /\/$/) {
      return "pageNameMissingSubpage";
    }
  }

  my $linkpattern = $config->LinkPattern;
  my $freelinkpattern = $config->FreeLinkPattern;

  if ($config->FreeLinks()) {
    $id =~ s/ /_/g;
    if (!$config->UseSubpage()) {
      if ($id =~ /\//) {
        return "pageNameSlashNotAllowed";
      }
    }
    if (!($id =~ m|^$freelinkpattern$|)) {
      return "pageNameInvalid";
    }
    if ($id =~ m|\.db$|) {
      return "pageNameInvalid";
    }
    if ($id =~ m|\.lck$|) {
      return "pageNameInvalid";
    }
    return "";
  } else {
    if (!($id =~ /^$linkpattern$/)) {
      return "pageNameInvalid";
    }
  }
  return "";
}

sub ValidIdOrDie {
    my $id = shift;
    my $error;

    $wikiTemplate->vars(siteName => $config->SiteName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        pageName => $id,
                        preferencesUrl => $config->ScriptName . '?action=editprefs');
    $error = &ValidId($id);
    if ($error ne "") {
        print &GetHttpHeader . $wikiTemplate->process('errors/$error');
        return 0;
    }
    return 1;
}

sub UserCanEdit {
  my ($id, $deepCheck) = @_;

  # Optimized for the "everyone can edit" case (don't check passwords)
  if ($id ne "") {
    my $page = new PurpleWiki::Database::Page('id' => $id);
    if (-f $page->getLockedPageFile()) {
      return 1  if (&UserIsAdmin());  # Requires more privledges
      # Later option for editor-level to edit these pages?
      return 0;
    }
  }
  if (!$config->EditAllowed) {
    return 1  if (&UserIsEditor());
    return 0;
  }
  if (-f $config->DataDir . "/noedit") {
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

  ($status, $data) = &PurpleWiki::Database::ReadFile($config->DataDir . "/banlist");
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

  return 0  if ($config->AdminPass eq "");
  $userPassword = &GetParam("adminpw", "");
  return 0  if ($userPassword eq "");
  foreach (split(/\s+/, $config->AdminPass)) {
    next  if ($_ eq "");
    return 1  if ($userPassword eq $_);
  }
  return 0;
}

sub UserIsEditor {
  my (@pwlist, $userPassword);

  return 1  if (&UserIsAdmin());             # Admin includes editor
  return 0  if ($config->EditPass eq "");
  $userPassword = &GetParam("adminpw", "");  # Used for both
  return 0  if ($userPassword eq "");
  foreach (split(/\s+/, $config->EditPass)) {
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

sub CalcTime {
  my ($ts) = @_;
  my ($ampm, $mytz);

  $ts += $TimeZoneOffset;
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime($ts);

  $mytz = "";
  if (($TimeZoneOffset == 0) && ($config->ScriptTZ ne "")) {
    $mytz = " " . $config->ScriptTZ;
  }
  $ampm = "";
  if ($config->UseAmPm) {
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
    if (length($user->getField($name))) {
      $result = $user->getField($name);
    } else {
      $result = $default;
    }
  }
  return $result;
}

sub GetRemoteHost {
  my ($doMask) = @_;
  my ($rhost, $iaddr);

  $rhost = $ENV{REMOTE_HOST};
  if ($config->UseLookup && ($rhost eq "")) {
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
    if ($config->UseSubpage) {
      $id =~ s|_/|/|g;
      $id =~ s|/_|/|g;
    }
  }
  if ($config->FreeUpper) {
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
    if ($action eq "edit") {
      &DoEdit($id, 0, 0, "", 0)  if &ValidIdOrDie($id);
    } elsif ($action eq "unlock") {
      &DoUnlock();
    } elsif ($action eq "index") {
      &DoIndex();
    } elsif ($action eq "editprefs") {
      &DoEditPrefs();
    } elsif ($action eq "login") {
      &DoEnterLogin();
    } elsif ($action eq "newlogin") {
      $UserID = 0;
      &DoEditPrefs();  # Also creates new ID
    } elsif ($action eq "logout") {
      &DoLogout;
    } elsif ($action eq 'rss') {
      my $rss = new PurpleWiki::Syndication::Rss;
      print $q->header(-type => 'text/xml') .
          $rss->getRSS;
    } else {
      # Later improve error reporting
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          action => $action,
                          preferencesUrl => $config->ScriptName . '?action=editprefs');
      print &GetHttpHeader . $wikiTemplate->process('errors/actionInvalid');
    }
    return;
  }
  if (&GetParam("edit_prefs", 0)) {
    &DoUpdatePrefs();
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
  $wikiTemplate->vars(siteName => $config->SiteName,
                      cssFile => $config->StyleSheet,
                      siteBase => $config->SiteBase,
                      baseUrl => $config->ScriptName,
                      homePage => $config->HomePage,
                      preferencesUrl => $config->ScriptName . '?action=editprefs');
  print &GetHttpHeader . $wikiTemplate->process('errors/urlInvalid');
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
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          preferencesUrl => $config->ScriptName . '?action=editprefs');
      if (&UserIsBanned()) {
          print &GetHttpHeader . $wikiTemplate->process('errors/editBlocked');
      }
      else {
          print &GetHttpHeader . $wikiTemplate->process('errors/editSiteReadOnly');
      }
      return;
  }
  # Consider sending a new user-ID cookie if user does not have one
  $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id);
  $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now,
                                 'username' => &GetParam("username", ""),
                                 'userID' => $UserID);
  $page->openPage();
  # FIXME: ordering is import in these next two, it shouldn't be
  $text = $page->getText();
  $section = $page->getSection();
  $pageTime = $section->getTS();
  
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
    }
  }

  $oldText = $text->getText();

  if ($preview && !$isConflict) {
    $oldText = $newText;
  }

  $userName = &GetParam("username", "");
  if ($isConflict) {
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          pageName => $id,
                          revision => $revision,
                          isConflict => $isConflict,
                          lastSavedTime => &TimeToText($oldTime),
                          currentTime => &TimeToText($Now),
                          pageTime => $pageTime,
                          userName => $userName,
                          oldText => $oldText,
                          newText => $newText,
                          preferencesUrl => $config->ScriptName . '?action=editprefs',
                          revisionsUrl => $config->ScriptName . "?action=history&id=$id");
      print &GetHttpHeader . $wikiTemplate->process('editConflict');
  }
  elsif ($preview) {
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          pageName => $id,
                          revision => $revision,
                          isConflict => $isConflict,
                          pageTime => $pageTime,
                          userName => $userName,
                          oldText => $oldText,
                          body => &WikiToHTML($id, $oldText),
                          preferencesUrl => $config->ScriptName . '?action=editprefs',
                          revisionsUrl => $config->ScriptName . "?action=history&id=$id");
      print &GetHttpHeader . $wikiTemplate->process('previewPage');
  }
  else {
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          pageName => $id,
                          revision => $revision,
                          pageTime => $pageTime,
                          userName => $userName,
                          oldText => $oldText,
                          preferencesUrl => $config->ScriptName . '?action=editprefs',
                          revisionsUrl => $config->ScriptName . "?action=history&id=$id");
      print &GetHttpHeader . $wikiTemplate->process('editPage');
  }

  $summary = &GetParam("summary", "*");
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

  $recentName = $config->RCName;
  $recentName =~ s/_/ /g;
  &DoNewLogin()  if ($UserID < 400);
  $wikiTemplate->vars(siteName => $config->SiteName,
                      cssFile => $config->StyleSheet,
                      siteBase => $config->SiteBase,
                      baseUrl => $config->ScriptName,
                      homePage => $config->HomePage,
                      userId => $UserID,
                      userName => &GetParam('username', ""),
                      rcDefault => $config->RcDefault,
                      recentTop => $config->RecentTop,
                      showEdits => &GetParam("rcshowedit", $config->ShowEdits),
                      defaultDiff => &GetParam("defaultdiff", 1),
                      serverTime => &TimeToText($Now - $TimeZoneOffset),
                      tzOffset => &GetParam('tzoffset', 0),
                      preferencesUrl => $config->ScriptName . '?action=editprefs');
  print &GetHttpHeader . $wikiTemplate->process('preferencesEdit');
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

  if ($UserID < 1001) {
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          userId => $UserID,
                          preferencesUrl => $config->ScriptName . '?action=editprefs');
      print &GetHttpHeader . $wikiTemplate->process('errors/prefsInvalidUserId');
      return;
  }

  $username = &GetParam("p_username",  "");

  if ($config->FreeLinks) {
    $username =~ s/^\[\[(.+)\]\]/$1/;  # Remove [[ and ]] if added
    $username =  &FreeToNormal($username);
    $username =~ s/_/ /g;
  }

  my $linkpattern = $config->LinkPattern;
  my $freelinkpattern = $config->FreeLinkPattern;

  my $errorUserName = 0;
  if ($username eq "") { # remove username
      $user->setField('username', undef);
  }
  elsif ((!$config->FreeLinks) && (!($username =~ /^$linkpattern$/))) {
      $errorUserName = 1;
  }
  elsif ($config->FreeLinks && (!($username =~ /^$freelinkpattern$/))) {
      $errorUserName = 1;
  }
  elsif (length($username) > 50) {  # Too long
      $errorUserName = 1;
  }
  else {
      $user->setField('username', $username);
  }

  $password = &GetParam("p_password",  "");

  my $passwordRemoved = 0;
  my $passwordChanged = 0;
  if ($password eq "") {
      $passwordRemoved = 1;
      $user->setField('password', undef);
  }
  elsif ($password ne "*") {
      $passwordChanged = 1;
      $user->setField('password', $password);
  }

  &UpdatePrefNumber("rcdays", 0, 0, 999999);
  &UpdatePrefCheckbox("rcnewtop");
  &UpdatePrefCheckbox("rcall");
  &UpdatePrefCheckbox("rcchangehist");
  &UpdatePrefCheckbox("editwide");

  if ($config->UseDiff) {
    &UpdatePrefCheckbox("norcdiff");
    &UpdatePrefCheckbox("diffrclink");
    &UpdatePrefCheckbox("alldiff");
    &UpdatePrefNumber("defaultdiff", 1, 1, 3);
  }

  &UpdatePrefNumber("rcshowedit", 1, 0, 2);
  &UpdatePrefNumber("tzoffset", 0, -999, 999);
  &UpdatePrefNumber("editrows", 1, 1, 999);
  &UpdatePrefNumber("editcols", 1, 1, 999);

  $TimeZoneOffset = &GetParam("tzoffset", 0) * (60 * 60);

  $user->save();

  $wikiTemplate->vars(siteName => $config->SiteName,
                      cssFile => $config->StyleSheet,
                      siteBase => $config->SiteBase,
                      baseUrl => $config->ScriptName,
                      homePage => $config->HomePage,
                      userName => $username,
                      errorUserName => $errorUserName,
                      passwordRemoved => $passwordRemoved,
                      passwordChanged => $passwordChanged,
                      serverTime => &TimeToText($Now-$TimeZoneOffset),
                      localTime => &TimeToText($Now),
                      preferencesUrl => $config->ScriptName . '?action=editprefs');
  print &GetHttpHeader . $wikiTemplate->process('preferencesUpdated');
}

sub UpdatePrefCheckbox {
  my ($param) = @_;
  my $temp = &GetParam("p_$param", "*");

  $user->setField($param, 1)  if ($temp eq "on");
  $user->setField($param, 0)  if ($temp eq "*");
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
  $user->setField($param, $temp);
  # Later consider returning status?
}

sub DoIndex {
    my @pages = &PurpleWiki::Database::AllPagesList($config);
    $wikiTemplate->vars(siteName => $config->SiteName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        pages => \@pages,
                        preferencesUrl => $config->ScriptName . '?action=editprefs');
    print &GetHttpHeader . $wikiTemplate->process('pageIndex');
}

# Create a new user file/cookie pair
sub DoNewLogin {
  # Later consider warning if cookie already exists
  # (maybe use "replace=1" parameter)
  $user = new PurpleWiki::Database::User(config => $config);
  $user->_openNewUser;
  $session->param('userId', $user->getID);
  $user->setField('rev', 1);
  $UserID = $session->param('userId');
  # The cookie will be transmitted in the next header
  $user->setField('createtime', $Now);
  $user->setField('createip', $ENV{REMOTE_ADDR});
  $user->save();
}

sub DoEnterLogin {
    $wikiTemplate->vars(siteName => $config->SiteName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        preferencesUrl => $config->ScriptName . '?action=editprefs');
    print &GetHttpHeader . $wikiTemplate->process('login');
}

sub DoLogin {
  my ($uid, $password, $success);

  $success = 0;
  $uid = &GetParam("p_userid", "");
  $uid =~ s/\D//g;
  $password = &GetParam("p_password",  "");
  if (($uid > 199) && ($password ne "") && ($password ne "*")) {
    $UserID = $uid;
    $user = new PurpleWiki::Database::User('id' => $UserID);
    if ($user->userExists()) {
      if (defined($user->getField('password')) &&
          ($user->getField('password') eq $password)) {
          $session->param('userId', $uid);
          $success = 1;
      }
    }
  }
  $wikiTemplate->vars(siteName => $config->SiteName,
                      cssFile => $config->StyleSheet,
                      siteBase => $config->SiteBase,
                      baseUrl => $config->ScriptName,
                      homePage => $config->HomePage,
                      userId => $uid,
                      loginSuccess => $success,
                      preferencesUrl => $config->ScriptName . '?action=editprefs');
  print &GetHttpHeader . $wikiTemplate->process('loginResults');
}

sub DoLogout {
    $session->delete;
    my $userName = $user->getField('username');
    my $cookie = $q->cookie(-name => $config->SiteName,
                            -value => '',
                            -path => '/cgi-bin/',
                            -expires => '-1d');
    my $header;
    if ($config->HttpCharset ne '') {
        $header = $q->header(-cookie=>$cookie,
                             -type=>"text/html; charset=" . $config->HttpCharset);
    }
    $header = $q->header(-cookie=>$cookie);
    $wikiTemplate->vars(siteName => $config->SiteName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        userName => $userName,
                        preferencesUrl => $config->ScriptName . '?action=editprefs');
    print $header . $wikiTemplate->process('logout');
}

sub DoSearch {
    my ($string) = @_;

    if ($string eq '') {
        &DoIndex();
        return;
    }
    # do the new pluggable search
    my $search = new PurpleWiki::Search::Engine(config => $config);
    $search->search($string);

    $wikiTemplate->vars(siteName => $config->SiteName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        keywords => $string,
                        modules => $search->modules,
                        results => $search->results,
                        preferencesUrl => $config->ScriptName . '?action=editprefs');
    print &GetHttpHeader . $wikiTemplate->process('searchResults');
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

  my $fsexp = $config->FS;

  # adjust the contents of $string with the wiki drivers to save purple
  # numbers

  # clean \r out of string
  $string =~ s/\r//g;

  my $url = $q->url() . "?$id";
  my $wiki = $wikiParser->parse($string,
                                'add_node_ids'=>1,
                                'url'=>$url,
                                'freelink' => $config->FreeLinks);
  my $output = $wiki->view('wikitext');

  $string = $output;

  # clean \r out of string
  $string =~ s/\r//g;

  $wikiTemplate->vars(siteName => $config->SiteName,
                      cssFile => $config->StyleSheet,
                      siteBase => $config->SiteBase,
                      baseUrl => $config->ScriptName,
                      homePage => $config->HomePage,
                      pageName => $id,
                      preferencesUrl => $config->ScriptName . '?action=editprefs');
  if (!&UserCanEdit($id, 1)) {
    # This is an internal interface--we don't need to explain
    print &GetHttpHeader . $wikiTemplate->process('errors/editNotAllowed');
    return;
  }

  if (($id eq 'SampleUndefinedPage') || ($id eq 'SampleUndefinedPage')) {
    print &GetHttpHeader . $wikiTemplate->process('errors/pageCannotBeDefined');
    return;
  }
  if (($id eq 'Sample_Undefined_Page')
      || ($id eq 'Sample_Undefined_Page')) {
    print &GetHttpHeader . $wikiTemplate->process('errors/pageCannotBeDefined');
    return;
  }
  $string =~ s/$fsexp//g;
  $summary =~ s/$fsexp//g;
  $summary =~ s/[\r\n]//g;
  # Add a newline to the end of the string (if it doesn't have one)
  $string .= "\n"  if (!($string =~ /\n$/));

  # Lock before getting old page to prevent races
  &PurpleWiki::Database::RequestLock() or die('Could not get editing lock');
  # Consider extracting lock section into sub, and eval-wrap it?
  # (A few called routines can die, leaving locks.)
  my $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id);
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
    PurpleWiki::Database::ReleaseLock();
    if ($oldconflict>0) {  # Conflict again...
      &DoEdit($id, 2, $pgtime, $string, $preview);
    } else {
      &DoEdit($id, 1, $pgtime, $string, $preview);
    }
    return;
  }
  if ($preview) {
    PurpleWiki::Database::ReleaseLock();
    &DoEdit($id, 0, $pgtime, $string, 1);
    return;
  }

  $user = &GetParam("username", "");
  # If the person doing editing chooses, send out email notification
  if (&GetParam("recent_edit", "") eq 'on') {
    $isEdit = 1;
  }
  if (!$isEdit) {
    $page->setPageCache('oldmajor', $section->getRevision());
  }
  if ($newAuthor) {
    $page->setPageCache('oldauthor', $section->getRevision());
  }

  # I removed the if statement and moved the 3 lines of code down below 
  #     -matthew
  #
  # only save section if it is not the first
  #if ($section->getRevision() > 0) {
  #  $keptRevision->addSection($section, $Now);
  #  $keptRevision->trimKepts($Now);
  #  $keptRevision->save();
  #}

  if ($config->UseDiff) {
    # FIXME: how many args does it take to screw a pooch?
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
  $keptRevision->addSection($section, $Now);
  $keptRevision->trimKepts($Now);
  $keptRevision->save();
  $page->setRevision($section->getRevision());
  $page->setTS($Now);
  $page->save();
  &WriteRcLog($id, $summary, $isEdit, $editTime, $user, $section->getHost());
  &PurpleWiki::Database::ReleaseLock();
  &ReBrowsePage($id, "", 1);
}

# Note: all diff and recent-list operations should be done within locks.
sub DoUnlock {
    my $forcedUnlock = 0;

    if (&PurpleWiki::Database::ForceReleaseLock('main', $config)) {
        $forcedUnlock = 1;
    }
    # Later display status of other locks?
    &PurpleWiki::Database::ForceReleaseLock('cache', $config);
    &PurpleWiki::Database::ForceReleaseLock('diff', $config);
    &PurpleWiki::Database::ForceReleaseLock('index', $config);
    $wikiTemplate->vars(siteName => $config->SiteName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        forcedUnlock => $forcedUnlock,
                        preferencesUrl => $config->ScriptName . '?action=editprefs');
    print &GetHttpHeader . $wikiTemplate->process('removeEditLock');

}

# Note: all diff and recent-list operations should be done within locks.
sub WriteRcLog {
  my ($id, $summary, $isEdit, $editTime, $name, $rhost) = @_;
  my ($extraTemp, %extra);

  %extra = ();
  $extra{'id'} = $UserID  if ($UserID > 0);
  $extra{'name'} = $name  if ($name ne "");
  $extraTemp = join($config->FS2, %extra);
  # The two fields at the end of a line are kind and extension-hash
  my $rc_line = join($config->FS3, $editTime, $id, $summary,
                     $isEdit, $rhost, "0", $extraTemp);
  my $rc_file = $config->RcFile;
  if (!open(OUT, ">>$rc_file")) {
    die($config->RCName . " log error: $!");
  }
  print OUT  $rc_line . "\n";
  close(OUT);
}

# ==== Difference markup and HTML ====
sub DoDiff {
    my ($page, $keptRevision, $diffType, $id, $pageName, $lastEdited,
        $rev, $newText) = @_;
    my $cacheName;
    my $diffText;
    my $diffTypeString;
    my @diffLinks;
    my $noDiff = 0;

    my $useMajor = 1;
    my $useMinor = 1;
    my $useAuthor = 1;
    if ($diffType == 1) {
        $diffTypeString = 'major';
        $cacheName = 'major';
        $useMajor = 0;
    }
    elsif ($diffType == 2) {
        $diffTypeString = 'minor';
        $cacheName = 'minor';
        $useMinor = 0;
    }
    elsif ($diffType == 3) {
        $diffTypeString = 'author';
        $cacheName = 'author';
        $useAuthor = 0;
    }
    if ($rev ne "") {
        $diffText = PurpleWiki::Database::GetKeptDiff($keptRevision,
                                                      $newText, $rev, 1);  # 1 = get lock
        if ($diffText eq "") {
            $diffText = '(The revisions are identical or unavailable.)';
        }
    }
    else {
        $diffText  = &PurpleWiki::Database::GetCacheDiff($page, $cacheName);
    }
    $useMajor  = 0 
        if ($useMajor  && ($diffText eq PurpleWiki::Database::GetCacheDiff($page, "major")));
    $useMinor  = 0 
        if ($useMinor  && ($diffText eq PurpleWiki::Database::GetCacheDiff($page, "minor")));
    $useAuthor = 0 
        if ($useAuthor && ($diffText eq PurpleWiki::Database::GetCacheDiff($page, "author")));
    $useMajor  = 0
        if ((!defined($page->getPageCache('oldmajor'))) ||
            ($page->getPageCache("oldmajor") < 1));
    $useAuthor = 0
        if ((!defined($page->getPageCache('oldauthor'))) ||
            ($page->getPageCache("oldauthor") < 1));
    push @diffLinks, { type => 'major', url => $config->ScriptName . "?action=browse&diff=1&id=$id" }
        if ($useMajor);
    push @diffLinks, { type => 'minor', url => $config->ScriptName . "?action=browse&diff=2&id=$id" }
        if ($useMinor);
    push @diffLinks, { type => 'author', url => $config->ScriptName . "?action=browse&diff=3&id=$id" }
        if ($useAuthor);
    if (($rev eq '') && ($diffType != 2) &&
        ((!defined($page->getPageCache("old$cacheName"))) ||
         ($page->getPageCache("old$cacheName") < 1))) {
        $noDiff = 1;
    }
    $wikiTemplate->vars(siteName => $config->SiteName,
                        pageName => $pageName,
                        cssFile => $config->StyleSheet,
                        siteBase => $config->SiteBase,
                        baseUrl => $config->ScriptName,
                        homePage => $config->HomePage,
                        revision => $rev,
                        diffType => $diffTypeString,
                        diffLinks => \@diffLinks,
                        nodiff => $noDiff,
                        diffs => &getDiffs($diffText),
                        lastEdited => $lastEdited,
                        pageUrl => $config->ScriptName . "?$id",
                        backlinksUrl => $config->ScriptName . "?search=$id",
                        preferencesUrl => $config->ScriptName . '?action=editprefs',
                        revisionsUrl => $config->ScriptName . "?action=history&id=$id");
    print &GetHttpHeader . $wikiTemplate->process('viewDiff');
}

# @diffs = ( { type => (status|removed|added), text => [] }, ... )
sub getDiffs {
    my $diffText = shift;
    my @diffs;

    my $added;
    my $removed;
    foreach my $line (split /\n/, $diffText) {
        my $statusMessage;
        if ($line =~ /^(\d+.*[adc].*)/) {
            my $statusMessage = $1;
            my $statusType;
            if ($statusMessage =~ /a/) {
                $statusType = 'Added: ';
            }
            elsif ($statusMessage =~ /d/) {
                $statusType = 'Removed: ';
            }
            else {
                $statusType = 'Changed: ';
            }
            if ($added) {
                $added = &QuoteHtml($added);
                $added =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'added', text => $added };
                $added = '';
            }
            elsif ($removed) {
                $removed = &QuoteHtml($removed);
                $removed =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'removed', text => $removed };
                $removed = '';
            }
            push @diffs, { type => 'status', text => "$statusType$statusMessage" };
        }
        elsif ($line =~ /^</) { # removed
            if ($added) {
                $added = &QuoteHtml($added);
                $added =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'added', text => $added };
                $added = '';
            }
            $line =~ s/^< //;
            $removed .= "$line\n";
        }
        elsif ($line =~ /^>/) { # added
            if ($removed) {
                $removed = &QuoteHtml($removed);
                $removed =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'removed', text => $removed };
                $removed = '';
            }
            $line =~ s/^> //;
            $added .= "$line\n";
        }
    }
    if ($added) {
        $added = &QuoteHtml($added);
        $added =~ s/\n/<br \/>\n/sg;
        push @diffs, { type => 'added', text => $added };
        $added = '';
    }
    elsif ($removed) {
        $removed = &QuoteHtml($removed);
        $removed =~ s/\n/<br \/>\n/sg;
        push @diffs, { type => 'removed', text => $removed };
        $removed = '';
    }
    return \@diffs;
}

&DoWikiRequest()  if ($config->RunCGI && ($_ ne 'nocgi'));   # Do everything.
1; # In case we are loaded from elsewhere
# == End of UseModWiki script. ===========================================
