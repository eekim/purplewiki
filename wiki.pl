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
use PurpleWiki::Template::TT;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

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
my %UserCookie;         # The cookie received from the user
my %SetCookie;          # The cookie to be sent to the user

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
    &ReportError("Could not create " . $config->DataDir . "$!");
    return 0;
  }
  &InitCookie();         # Reads in user data
  return 1;
}

sub InitCookie {
  %SetCookie = ();
  $TimeZoneOffset = 0;
  undef $q->{'.cookies'};  # Clear cache if it exists (for SpeedyCGI)
  %UserCookie = $q->cookie($config->CookieName);
  $UserID = $UserCookie{'id'};
  $UserID =~ s/\D//g;  # Numeric only
  if ($UserID < 200) {
    $UserID = 111;
    $user = new PurpleWiki::Database::User('id' => $UserID, config => $config);
  } else {
    $user = new PurpleWiki::Database::User('id' => $UserID, config => $config);
    if ($user->userExists()) {
      if (($user->getID() != $UserCookie{'id'}) ||
          ($user->getField('randkey') != $UserCookie{'randkey'})) {
        $UserID = 113;
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
  $page = new PurpleWiki::Database::Page('id' => $id, config => $config);
  if ($id) {                    # Just script?PageName
    if ($config->FreeLinks && (!$page->pageExists())) {
      $id = &FreeToNormal($id);
    }
    &BrowsePage($id)  if &ValidIdOrDie($id);
    return 1;
  }
  $action = lc(&GetParam('action', ''));
  $id = &GetParam('id', '');
  $page = new PurpleWiki::Database::Page('id' => $id, config => $config);
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
                                    'username' => GetParam("username", ""),
                                    'config' => $config);
  $page->openPage();
  $section = $page->getSection();
  $text = $page->getText();
  $newText = $text->getText();
  $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id,
      config => $config);

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
  my ($html, $canEdit);
  my $page;
  my $text;
  my $keptRevision;

  print &GetHeader("",&QuoteHtml("History of $id"), "") . "<br>";
  $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now,
    config => $config);
  $page->openPage();

  $canEdit = &UserCanEdit($id);
  $canEdit = 0;  # Turn off direct "Edit" links
  $html = &GetHistoryLine($id, $page->getSection(), $canEdit, 1);
  $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id,
    config => $config);
  foreach my $section (reverse sort {$a->getRevision() <=> $b->getRevision()}
                    $keptRevision->getSections()) {
    # If KeptRevision == Current Revision don't print it. - matthew
    if ($section->getRevision() != $page->getSection()->getRevision()) {
      $html .= &GetHistoryLine($id, $section, $canEdit, 0);
    }
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
  $expirets = $Now - ($config->KeepDays * 24 * 60 * 60);

  $html = "Revision $rev" . ": ";
  if ($isCurrent) {
    $html .= &GetPageLinkText($id, 'View') . ' ';
    if ($canEdit) {
      $html .= &GetEditLink($id, 'Edit') . ' ';
    }
    if ($config->UseDiff) {
      $html .= 'Diff' . ' ';
    }
  } else {
    $html .= &GetOldPageLink('browse', $id, $rev, 'View') . ' ';
    if ($canEdit) {
      $html .= &GetOldPageLink('edit',   $id, $rev, 'Edit') . ' ';
    }
    if ($config->UseDiff) {
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

  my $MainPage = $PurpleWiki::Page::MainPage;
  $id =~ s|^/|$MainPage/|;
  if ($config->FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink($id, $name);
}

sub GetPageLinkText {
  my ($id, $name) = @_;

  my $MainPage = $PurpleWiki::Page::MainPage;
  $id =~ s|^/|$MainPage/|;
  if ($config->FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink($id, $name);
}

sub GetEditLink {
  my ($id, $name) = @_;

  if ($config->FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink("action=edit&id=$id", $name);
}

sub GetOldPageLink {
  my ($kind, $id, $revision, $name) = @_;

  if ($config->FreeLinks) {
    $id = &FreeToNormal($id);
    $name =~ s/_/ /g;
  }
  return &ScriptLink("action=$kind&id=$id&revision=$revision", $name);
}

sub GetSiteUrl {
    my ($site) = @_;
    my ($data, $url, $status);

    if (!$InterSiteInit) {
      $InterSiteInit = 1;
      ($status, $data) = &PurpleWiki::Database::ReadFile($config->InterFile);
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
  if ($config->FreeLinks) {
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

  if ($config->FreeLinks) {
    $action =~ s/ /_/g;
  }
  return "<a href=\"$ScriptName?$action\" title=\"$title\">$text</a>";
}

sub GetAuthorLink {
  my ($host, $userName, $uid) = @_;
  my ($html, $title, $userNameShow);

  $userNameShow = $userName;
  if ($config->FreeLinks) {
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

  if ($config->FreeLinks) {
    $id =~ s/ /_/g;
  }
  return &ScriptLink("action=history&id=$id", $text);
}

sub GetHeader {
  my ($id, $title, $oldId) = @_;
  my $header = "";
  my $logoImage = "";
  my $result = "";
  my $embed = &GetParam('embed', $config->EmbedWiki);
  my $altText = '[Home]';

  $result = &GetHttpHeader();
  if ($config->FreeLinks) {
    $title =~ s/_/ /g;   # Display as spaces
  }
  $result .= &GetHtmlHeader($config->SiteName. ": $title");
  return $result  if ($embed);

  if ($oldId ne '') {
    $result .= $q->h3('(' . "redirected from " . 
                               &GetEditLink($oldId, $oldId) . ')');
  }
  if ((!$embed) && ($config->LogoUrl ne "")) {
    $logoImage = "img src=\"" . $config->LogoUrl . "\" alt=\"$altText\" border=0";
    if (!$config->LogoLeft) {
      $logoImage .= " align=\"right\"";
    }
    $header = &ScriptLink($config->HomePage, "<$logoImage>");
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
    $cookie = $config->CookieName. "="
            . "rev&" . $SetCookie{'rev'}
            . "&id&" . $SetCookie{'id'}
            . "&randkey&" . $SetCookie{'randkey'};
    $cookie .= ";expires=Fri, 08-Sep-2010 19:48:23 GMT";
    if ($config->HttpCharset ne '') {
      return $q->header(-cookie=>$cookie,
                        -type=>"text/html; charset=" . $config->HttpCharset);
    }
    return $q->header(-cookie=>$cookie);
  }
  if ($config->HttpCharset ne '') {
    return $q->header(-type=>"text/html; charset=" . $config->HttpCharset);
  }
  return $q->header();
}

sub GetHtmlHeader {
  my ($title) = @_;
  my ($dtd, $html);

  $html = '';
  $dtd = '-//IETF//DTD HTML//EN';
  $html = qq(<!DOCTYPE HTML PUBLIC "$dtd">\n);
  $title = $q->escapeHTML($title);
  $html .= "<html><head><title>$title</title>\n";
  if ($config->SiteBase ne "") {
    $html .= qq(<base href=") . $config->SiteBase . qq(">\n);
  }
  if ($config->StyleSheet ne '') {
    $html .= qq(<link rel="stylesheet" href=") . $config->StyleSheet .
    qq(" />\n);
  }
  # Insert any other body stuff (like scripts) into $bodyExtra here
  # (remember to add a space at the beginning to separate from prior text)
  $html .= "</head><body>\n";
  return $html;
}

sub GetFooterText {
  my $section = shift;
  my ($id, $rev) = @_;
  my $result = '';

  if (&GetParam('embed', $config->EmbedWiki)) {
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
  if ($config->UseDiff) {
    $result .= ' ' . &ScriptLinkDiff(4, $id, '(diff)', $rev);
  }
  $result .= '<br>' . &GetSearchForm();
  if ($config->DataDir =~ m|/tmp/|) {
    $result .= '<br><b>' . 'Warning' . ':</b> '
               . 'Database is stored in temporary directory '
               . $config->DataDir . '<br>';
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
  if ($config->FooterNote ne '') {
    return $config->FooterNote . $q->end_html;  # Allow local translations
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

  $bartext  = &GetPageLink($config->HomePage);
  if ($id =~ m|/|) {
    $main = $id;
    $main =~ s|/.*||;  # Only the main page name (remove subpage)
    $bartext .= " | " . &GetPageLink($main);
  }
  $bartext .= " | " . &GetPageLink($config->RCName);
  $bartext .= " | " . &GetPrefsLink();
  if (&GetParam("linkrandom", 0)) {
    $bartext .= " | " . &GetRandomLink();
  }
  if ($config->UserGotoBar ne '') {
    $bartext .= " | " . $config->UserGotoBar;
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

  my $wiki = $wikiParser->parse($pageText, config => $config, 'freelink' => $config->FreeLinks);
  my $url = $q->url(-full => 1) . '?' . $id;
  return $wiki->view('wikihtml', config => $config, url => $url,
                     pageName => $id);
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
  if ($config->UseSubpage()) {
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

  my $linkpattern = $config->LinkPattern;
  my $freelinkpattern = $config->FreeLinkPattern;

  if ($config->FreeLinks()) {
    $id =~ s/ /_/g;
    if (!$config->UseSubpage()) {
      if ($id =~ /\//) {
        return "Invalid Page $id (/ not allowed)";
      }
    }
    if (!($id =~ m|^$freelinkpattern$|)) {
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
    if (!($id =~ /^$linkpattern$/)) {
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
  if ($id ne "") {
    my $page = new PurpleWiki::Database::Page('id' => $id, config => $config);
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

sub GetHiddenValue {
  my ($name, $value) = @_;

  $q->param($name, $value);
  return $q->hidden($name);
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
      # FIXME: Should really have one template per error message.
      my $errorMessage;
      if (&UserIsBanned()) {
          $errorMessage = 'Editing not allowed: user, ip, or network is blocked.  Contact the wiki administrator for more information.';
      }
      else {
          $errorMessage = "Editing not allowed: " . $config->SiteName . " is read-only.";
      }
      $wikiTemplate->vars(siteName => $config->SiteName,
                          cssFile => $config->StyleSheet,
                          siteBase => $config->SiteBase,
                          baseUrl => $config->ScriptName,
                          homePage => $config->HomePage,
                          errorTitle => 'Editing Denied',
                          errorMessage => $errorMessage,
                          preferencesUrl => $config->ScriptName . '?action=editprefs');
      print &GetHttpHeader . $wikiTemplate->process('error');
      return;
  }
  # Consider sending a new user-ID cookie if user does not have one
  $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id,
    config => $config);
  $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now,
                                 'username' => &GetParam("username", ""),
                                 'userID' => $UserID, config => $config);
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

  if ($config->FreeLinks) {
    $username =~ s/^\[\[(.+)\]\]/$1/;  # Remove [[ and ]] if added
    $username =  &FreeToNormal($username);
    $username =~ s/_/ /g;
  }

  my $linkpattern = $config->LinkPattern;
  my $freelinkpattern = $config->FreeLinkPattern;

  if ($username eq "") {
    print 'UserName removed.', '<br>';
    $user->setField('username', undef);
  } elsif ((!$config->FreeLinks) && (!($username =~ /^$linkpattern$/))) {
    print "Invalid UserName $username: not saved.<br>\n";
  } elsif ($config->FreeLinks && (!($username =~ /^$freelinkpattern$/))) {
    print "Invalid UserName $username: not saved.<br>\n";
  } elsif (length($username) > 50) {  # Too long
    print 'UserName must be 50 characters or less. (not saved)', "<br>\n";
  } else {
    print "UserName $username saved.<br>";
    $user->setField('username', $username);
  }

  $password = &GetParam("p_password",  "");

  if ($password eq "") {
    print 'Password removed.', '<br>';
    $user->setField('password', undef);
  } elsif ($password ne "*") {
    print 'Password changed.', '<br>';
    $user->setField('password', $password);
  }

  if ($config->AdminPass ne "") {
    $password = &GetParam("p_adminpw",  "");
    if ($password eq "") {
      print 'Administrator password removed.', '<br>';
      $user->setField('adminpw', undef);
    } elsif ($password ne "*") {
      print 'Administrator password changed.', '<br>';
      $user->setField('adminpw', $password);
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

  if ($config->EmailNotify) {
    &UpdatePrefCheckbox("notify");
    &UpdateEmailList();
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

  print 'Server time:', ' ', &TimeToText($Now-$TimeZoneOffset), '<br>';
  $TimeZoneOffset = &GetParam("tzoffset", 0) * (60 * 60);
  print 'Local time:', ' ', &TimeToText($Now), '<br>';

  $user->save();

  print '<b>', 'Preferences saved.', '</b>';
  print &GetCommonFooter();
}

# add or remove email address from preferences to $DatDir/emails
sub UpdateEmailList {
  my (@old_emails);

  local $/ = "\n";  # don't slurp whole files in this sub.

  my $new_email = &GetParam("p_email", "");
  if ($new_email) {
    $user->setField('email', $new_email);
    my $notify = $user->getField('notify');
    if (-f $config->DataDir . "/emails") {
      open(NOTIFY, $config->DataDir . "/emails")
        or die("Could not read from " . $config->DataDir . "/emails: $!\n");
      @old_emails = <NOTIFY>;
      close(NOTIFY);
    } else {
      @old_emails = ();
    }
    my $already_in_list = grep /$new_email/, @old_emails;
    if ($notify and (not $already_in_list)) {
      PurpleWiki::Database::RequestLock($config) or die('Could not get mail lock');
      my $notifyfile = $config->DataDir . '/emails';
      open(NOTIFY, ">>$notifyfile")
        or die("Could not append to $notifyfile: $!\n");
      print NOTIFY $new_email, "\n";
      close(NOTIFY);
      PurpleWiki::Database::ReleaseLock($config);
    }
    elsif ((not $notify) and $already_in_list) {
      &PurpleWiki::Database::RequestLock($config) or die('Could not get mail lock');
      my $notifyfile = $config->DataDir . '/emails';
      open(NOTIFY, ">$notifyfile")
        or die("Could not overwrite $notifyfile: $!\n");
      foreach (@old_emails) {
        print NOTIFY "$_" unless /$new_email/;
      }
      close(NOTIFY);
      &PurpleWiki::Database::ReleaseLock($config);
    }
  }
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
  my $randkey = int(rand(1000000000));
  $SetCookie{'id'} = $user->getID();
  $SetCookie{'randkey'} = $randkey;
  $SetCookie{'rev'} = 1;
  $user->setField('randkey', $randkey);
  $user->setField('rev', 1);
  %UserCookie = %SetCookie;
  $UserID = $SetCookie{'id'};
  # The cookie will be transmitted in the next header
  $user->setField('createtime', $Now);
  $user->setField('createip', $ENV{REMOTE_ADDR});
  $user->save();
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
    $user = new PurpleWiki::Database::User('id' => $UserID, config => $config);
    if ($user->userExists()) {
      if (defined($user->getField('password')) &&
          ($user->getField('password') eq $password)) {
        $SetCookie{'id'} = $uid;
        $SetCookie{'randkey'} = $user->getField('randkey');
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

  # do the new pluggable search
  my $search = new PurpleWiki::Search::Engine(config => $config);
  $search->search($string);
  print $search->asHTML();

  print &GetCommonFooter();
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
                                'config' => $config,
                                'freelink' => $config->FreeLinks);
  my $output = $wiki->view('wikitext', config => $config);

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
  $string =~ s/$fsexp//g;
  $summary =~ s/$fsexp//g;
  $summary =~ s/[\r\n]//g;
  # Add a newline to the end of the string (if it doesn't have one)
  $string .= "\n"  if (!($string =~ /\n$/));

  # Lock before getting old page to prevent races
  &PurpleWiki::Database::RequestLock($config) or die('Could not get editing lock');
  # Consider extracting lock section into sub, and eval-wrap it?
  # (A few called routines can die, leaving locks.)
  my $keptRevision = new PurpleWiki::Database::KeptRevision(id => $id,
    config => $config);
  my $page = new PurpleWiki::Database::Page('id' => $id, 'now' => $Now,
    config => $config);
  $page->openPage();
  my $text = $page->getText();
  my $section = $page->getSection();
  $old = $text->getText();
  $oldrev = $section->getRevision();
  $pgtime = $section->getTS();

  $preview = 0;
  $preview = 1  if (&GetParam("Preview", "") ne "");
  if (!$preview && ($old eq $string)) {  # No changes (ok for preview)
    &PurpleWiki::Database::ReleaseLock($config);
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
    PurpleWiki::Database::ReleaseLock($config);
    if ($oldconflict>0) {  # Conflict again...
      &DoEdit($id, 2, $pgtime, $string, $preview);
    } else {
      &DoEdit($id, 1, $pgtime, $string, $preview);
    }
    return;
  }
  if ($preview) {
    PurpleWiki::Database::ReleaseLock($config);
    &DoEdit($id, 0, $pgtime, $string, 1);
    return;
  }

  $user = &GetParam("username", "");
  # If the person doing editing chooses, send out email notification
  if ($config->EmailNotify) {
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
    &PurpleWiki::Database::UpdateDiffs($page, $keptRevision, $id, $editTime, $old, $string, $isEdit, $newAuthor, $config);
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
  &PurpleWiki::Database::ReleaseLock($config);
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
  my $sendmail = $config->SendMail;
  open (SENDMAIL, "| $sendmail -oi -t ") or die "Can't send email: $!\n";
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
  if ($config->EmailNotify) {
    my ($page, $id, $user) = @_;
    if ($user) {
      $user = " by $user";
    }
    my $address;
    my $emailfile = $config->DataDir . '/emails';
    open(EMAIL, "$emailfile")
      or die "Can't open $emailfile: $!\n";
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

 The $config->SiteName page $id at
   $page_url
 has been changed$user to revision $revision . $editors_summary

 (Replying to this notification will
  send email to the entire mailing list,
  so only do that if you mean to.

  To remove yourself from this list, visit
  ${home_url}?action=editprefs .)
END_MAIL_CONTENT
    my $subject = "The $id page at " . $config->SiteName . " has been changed.";
    # I'm setting the "reply-to" field to be the same as the "to:" field
    # which seems appropriate for a mailing list, especially since the
    # $EmailFrom string needn't be a real email address.
    &SendEmail($address, $config->EmailFrom, $address, $subject, $content);
  }
}

# Note: all diff and recent-list operations should be done within locks.
sub DoUnlock {
  my $LockMessage = 'Normal Unlock.';

  print &GetHeader('', 'Removing edit lock', '');
  print '<p>', 'This operation may take several seconds...', "\n";
  if (&PurpleWiki::Database::ForceReleaseLock('main', $config)) {
    $LockMessage = 'Forced Unlock.';
  }
  # Later display status of other locks?
  &PurpleWiki::Database::ForceReleaseLock('cache', $config);
  &PurpleWiki::Database::ForceReleaseLock('diff', $config);
  &PurpleWiki::Database::ForceReleaseLock('index', $config);
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
  $fname = $config->DataDir . '/noedit';
  if (&GetParam("set", 1)) {
    PurpleWiki::Database::WriteStringToFile($fname, "editing locked.");
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
  my $page = new PurpleWiki::Database::Page('id' => $id, config => $config);
  $fname = $page->getLockedPageFile();
  if (&GetParam("set", 1)) {
    PurpleWiki::Database::WriteStringToFile($fname, "editing locked.");
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
  ($status, $banList) = &PurpleWiki::Database::ReadFile($config->DataDir .
      '/banlist');
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
  $fname = $config->DataDir . '/banlist';
  $newList = &GetParam("banlist", "#Empty file");
  if ($newList eq "") {
    print "<p>Empty banned list or error.";
    print "<p>Resubmit with at least one space character to remove.";
  } elsif ($newList =~ /^\s*$/s) {
    unlink($fname);
    print "<p>Removed banned list";
  } else {
    PurpleWiki::Database::WriteStringToFile($fname, $newList);
    print "<p>Updated banned list";
  }
  print &GetCommonFooter();
}

sub DoShowVersion {
  print &GetHeader("", "Displaying Wiki Version", "");
  print "<p>PurpleWiki version $VERSION<p>\n";
  print &GetCommonFooter();
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
    my $html;
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
                $html = $wikiParser->parse($added,
                    'freelink' => $config->FreeLinks,
                    'config' => $config,
                    'add_node_ids' => 0)->view('wikihtml', config => $config);
                push @diffs, { type => 'added', text => $html };
                $added = '';
            }
            elsif ($removed) {
                $html = $wikiParser->parse($removed,
                    'freelink' => $config->FreeLinks,
                    'config' => $config,
                    'add_node_ids' => 0)->view('wikihtml', config => $config);
                push @diffs, { type => 'removed', text => $html };
                $removed = '';
            }
            push @diffs, { type => 'status', text => "$statusType$statusMessage" };
        }
        elsif ($line =~ /^</) { # removed
            if ($added) {
                $html = $wikiParser->parse($added,
                    'freelink' => $config->FreeLinks,
                    'config' => $config,
                    'add_node_ids' => 0)->view('wikihtml', config => $config);
                push @diffs, { type => 'added', text => $html };
                $added = '';
            }
            $line =~ s/^< //;
            $removed .= "$line\n";
        }
        elsif ($line =~ /^>/) { # added
            if ($removed) {
                $html = $wikiParser->parse($removed,
                    'freelink' => $config->FreeLinks,
                    'config' => $config,
                    'add_node_ids' => 0)->view('wikihtml', config => $config);
                push @diffs, { type => 'removed', text => $html };
                $removed = '';
            }
            $line =~ s/^> //;
            $added .= "$line\n";
        }
    }
    if ($added) {
        $html = $wikiParser->parse($added,
            'freelink' => $config->FreeLinks,
            'config' => $config,
            'add_node_ids' => 0)->view('wikihtml', config => $config);
        push @diffs, { type => 'added', text => $html };
        $added = '';
    }
    elsif ($removed) {
        $html = $wikiParser->parse($removed,
            'freelink' => $config->FreeLinks,
            'config' => $config,
            'add_node_ids' => 0)->view('wikihtml', config => $config);
        push @diffs, { type => 'removed', text => $html };
        $removed = '';
    }
    return \@diffs;
}

&DoWikiRequest()  if ($config->RunCGI && ($_ ne 'nocgi'));   # Do everything.
1; # In case we are loaded from elsewhere
# == End of UseModWiki script. ===========================================
