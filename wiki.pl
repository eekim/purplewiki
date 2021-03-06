#!/usr/bin/perl
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# wiki.pl - PurpleWiki
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2005.  All rights reserved.
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
my $useCap = 0;
eval "use Authen::Captcha";
$useCap = 1 if (!$@);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Digest::MD5;
use PurpleWiki::Config;
use PurpleWiki::Search::Engine;
use PurpleWiki::Session;

my $CONFIG_DIR = $ENV{PW_CONFIG_DIR} || '/var/www/wikidb';

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

local $| = 1;  # Do not buffer output (localized for mod_perl)

my $InterSiteInit = 0;
my %InterSite;
my $user;               # our reference to the logged in user
my $session;            # CGI::Session object

my $q;                  # CGI query reference

my $TimeZoneOffset;     # User's preference for timezone. FIXME: can we
                        # get this off $user reliably? Doesn't look
                        # worth it.

# we only need one of each these per run
my $config = new PurpleWiki::Config($CONFIG_DIR);
my $pages = $config->{pages};

my $parserDriver = $config->ParserDriver;
my $templateDriver = $config->TemplateDriver;
my $userDbDriver = $config->UserDatabaseDriver;
my $aclDriver = $config->ACLDriver;

eval "require $parserDriver";
die "Parser Driver Error ($parserDriver) $@" if ($@);
eval "require $templateDriver";
die "Template Driver Error ($templateDriver) $@" if ($@);
eval "require $userDbDriver";
die "User DB Driver Error ($userDbDriver) $@" if ($@);
eval "require $aclDriver";
die "ACL Driver Error ($aclDriver) $@" if ($@);

my $wikiParser = $parserDriver->new;
my $wikiTemplate = $templateDriver->new;
my $userDb = $userDbDriver->new;
my $acl = $aclDriver->new;

# check for i-names support
if ($config->UseINames) {
    require XDI::SSO;
    require XDI::Registry;
}

# Set our umask if one was put in the config file. - matthew
umask(oct($config->Umask)) if defined $config->Umask;

# The "main" program, called from the end of this script file.
sub DoWikiRequest {
  InitRequest(@_) or return;

  $PurpleWiki::Misc::MainPage = '';

  if (not DoBrowseRequest()) {
    DoOtherRequest();
  }
  &logSession;
}

sub dumpParams {
  my $q = shift;
  my $F;
  open($F, ">>/tmp/form_log");
  print $F $q->url(-path_info=>1),"\n";
  $q->save($F);
  close $F;
}

# == Common and cache-browsing code ====================================

sub InitRequest {
  my $req = shift;
  if ($req) {
    $q = $req;
  } else {
    $CGI::POST_MAX = $config->MaxPost;
    $CGI::DISABLE_UPLOADS = 1;  # no uploads
    $q = new CGI;
#dumpParams($q);
  }

  if (!$pages) {
    # technically, we failed to create the pages object which represents
    # the database, so maybe the message should change (FIXME)
    $wikiTemplate->vars(&globalTemplateVars,
                        dataDir => $config->DataDir);
    print GetHttpHeader($q),
          $wikiTemplate->process('errors/dataDirCannotCreate');
    return 0;
  }
  $config->{pages} = $pages;   # use the config to store context vars for now

  InitCookie();         # Reads in user data
  # tell the template object which language dir to use
  $wikiTemplate->language(&preferredLanguages);
  return 1;
}

sub InitCookie {
  $TimeZoneOffset = 0;
  undef $q->{'.cookies'};  # Clear cache if it exists (for SpeedyCGI)

  my $sid = ($config->CookieName) ? $q->cookie($config->CookieName) :
      $q->cookie($config->SiteName);
  $session = PurpleWiki::Session->new($sid);
  my $userId = $session->param('userId');
  if ($userId) {
      $user = $userDb->loadUser($userId);
  }
  $session->clear(['userId']) if (!$user);

  if ($user && $user->tzOffset != 0) {
    $TimeZoneOffset = $user->tzOffset * (60 * 60);
  }
}

sub preferredLanguages {
    my @langStrings = split(/\s*,\s*/, $q->http('Accept-Language'));
    my @languages;
    my @toSort;
    foreach my $lang (@langStrings) {
        if ($lang =~ /^\s*([^\;]+)\s*\;\s*q=(.+)\s*$/) {
            push @toSort, { lang => $1, q => $2 };
        }
        else {
            push @languages, $lang;
        }
    }
    my @sorted = sort { $b->{q} <=> $a->{q} } @toSort;
    foreach my $langHash (@sorted) {
        push @languages, $langHash->{lang};
    }
    return @languages;
}

sub DoBrowseRequest {
  my ($id, $action, $text);

  if ($id = (!$q->param) ? $config->HomePage : GetParam('keywords', '')) {
    $id = FreeToNormal($id) if ($config->FreeLinks);
    BrowsePage($id) if ValidIdOrDie($id);
    return 1;
  }
                            
  $action = lc(GetParam('action', ''));
  $id = GetParam('id', $config->HomePage);
  if ($action eq 'browse') {
    $id = FreeToNormal($id) if ($config->FreeLinks);
    BrowsePage($id)  if ValidIdOrDie($id);
    return 1;
  } elsif ($action eq 'rc') {
    BrowsePage($config->RCName);
    return 1;
  } elsif ($action eq 'random') {
    DoRandom();
    return 1;
  } elsif ($action eq 'history') {
    DoHistory($id)   if ValidIdOrDie($id);
    return 1;
  }
  return 0;  # Request not handled
}

sub BrowsePage {
  my ($id) = shift;
  my $body;
  my ($allDiff, $showDiff);
  my ($revision, $diffRevision);

  my ($text);

  if (!$acl->canRead($user, $id)) {
      $wikiTemplate->vars(&globalTemplateVars);
      print &GetHttpHeader . $wikiTemplate->process('errors/viewNotAllowed');
      return;
  }
  my ($userId, $username);
  if ($user) {
      $userId = $user->id;
      $username= $user->username;
  }

  my $pageName = $pages->getName($id);
  $revision = GetParam('revision', '');
  $revision = '' if ($revision =~ /\D/);

  my $page = $pages->getPage($id, $revision);
  $allDiff  = GetParam('alldiff', 0);

  if ($allDiff != 0) {
    $allDiff = GetParam('defaultdiff', 1);
  }

  if (($id eq $config->RCName) && GetParam('norcdiff', 1)) {
    $allDiff = 0;  # Only show if specifically requested
  }

  $id =~ m!^[^/]*!;
  $PurpleWiki::Misc::MainPage = $& ? $&.'/' : '';

  $showDiff = GetParam('diff', $allDiff);

  if ($showDiff) {
    $diffRevision = GetParam('diffrevision', '');
    my $diffText = $pages->diff($id, $diffRevision, $revision);
    $wikiTemplate->vars(&globalTemplateVars,
                        pageName => $pageName,
                        revision => $diffRevision || $revision,
                        diffs => getDiffs($diffText),
                        lastEdited => TimeToText($page->getTime),
                        pageUrl => $config->BaseURL . "?$id",
                        backlinksUrl => $config->BaseURL . "?search=$id",
                        revisionsUrl => $config->BaseURL
                                        . "?action=history&amp;id=$id");
    print GetHttpHeader() . $wikiTemplate->process('viewDiff');
    return;
  }
    
  my $url = $config->BaseURL . '?' . $id;
  $body = WikiHTML($id, $page->getTree(), $url);

  $session->newVisitedPage($id);
  if ($id eq $config->RCName) {
      DoRc($id, $pageName, $revision, $body);
      return;
  }

  my @vPages = $session->visitedPages;
  my $keywords = $id;
  $keywords =~ s/_/\+/g if ($config->FreeLinks);

  my $editRevisionString = ($revision) ? "&amp;revision=$revision" : '';

  $wikiTemplate->vars(&globalTemplateVars,
                      pageName => $pageName,
                      expandedPageName => &expandPageName($pageName),
                      id => $id,
                      visitedPages => \@vPages,
                      revision => $revision,
                      body => $body,
                      lastEdited => TimeToText($page->getTime),
                      pageUrl => $config->BaseURL . "?$id",
                      backlinksUrl => $config->BaseURL . "?search=$keywords",
                      editUrl => $acl->canEdit($user, $id)
                          ?   $config->BaseURL . "?action=edit&amp;id=$id" .
                              $editRevisionString
                          : undef,
                      revisionsUrl =>
                          $config->BaseURL . "?action=history&amp;id=$id",
                      diffUrl => $config->BaseURL
                          . "?action=browse&amp;diff=1&amp;id=$id");
  print GetHttpHeader() . $wikiTemplate->process('viewPage');
}

sub DoRc {
    my ($id, $pageName, $revision, $body) = @_;
    my $starttime = 0;
    my $daysago;
    my @rcDays;
    foreach my $days (@{$config->RcDays}) {
        push @rcDays, { num => $days,
                        url => $config->BaseURL .
                            "?action=rc&amp;days=$days" };
    }
    if (GetParam("from", 0)) {
        $starttime = GetParam("from", 0);
    }
    else {
        $daysago = GetParam("days", GetParam("rcdays", $config->RcDefault));
        if ($daysago) {
            $starttime = time - ((24*60*60)*$daysago);
        }
    }
    my $rcRef = $pages -> recentChanges($starttime);
    my @recentChanges;
    my $prevDate;
    foreach my $page (@{$rcRef}) {
        my $date = CalcDay($page->{timeStamp});
        if ($date ne $prevDate) {
            push @recentChanges, { date => $date, pages => [] };
            $prevDate = $date;
        }
        my $pageId = $page->{pageId};
        my $userName;
        if ($page->{userId}) {
            my $pageUser = $userDb->loadUser($page->{userId});
            $userName = $pageUser->username if ($pageUser);
        }
        push @{$recentChanges[$#recentChanges]->{pages}},
            { id => $pageId,
              pageName => $pages->getName($pageId),
              time => CalcTime($page->{timeStamp}),
              numChanges => $page->{numChanges},
              summary => QuoteHtml($page->{changeSummary}),
              userName => $userName,
              userId => $page->{userId},
              host => $page->{host},
              diffUrl => $config->BaseURL .
                  '?action=browse&amp;diff=1&amp;id=' . $page->{pageId},
              changeUrl => $config->BaseURL .
                  '?action=history&amp;id=' . $page->{pageId} };
    }
    my @vPages = $session->visitedPages;
    my $currentTime = localtime;
    $wikiTemplate->vars(&globalTemplateVars,
                        id => $id,
                        pageName => $pageName,
                        expandedPageName => &expandPageName($pageName),
                        visitedPages => \@vPages,
                        revision => $revision,
                        body => $body,
                        daysAgo => $daysago,
                        rcDays => \@rcDays,
                        changesFrom => TimeToText($starttime),
                        recentChanges => \@recentChanges,
                        currentTime => $currentTime,
                        pageUrl => $config->BaseURL . "?$id",
                        backlinksUrl => $config->BaseURL . "?search=$id",
                        editUrl => $acl->canEdit($user, $id) ?
                            $config->BaseURL . "?action=edit&amp;id=$id" : undef,
                        revisionsUrl => $config->BaseURL . "?action=history&amp;id=$id",
                        diffUrl => $config->BaseURL . "?action=browse&amp;diff=1&amp;id=$id");
    print GetHttpHeader() . $wikiTemplate->process('viewRecentChanges');
}

sub DoRandom {
  my ($id, @pageList);

  @pageList = $pages->allPages();  # Optimize?
  $id = $pageList[int(rand($#pageList + 1))];
  ReBrowsePage($id);
}

sub DoHistory {
    my ($id) = @_;
    my $text;

    my $base = $config->BaseURL;
    my @vPages = $session->visitedPages;
    my @pageHistory = $pages->getRevisions($id);
    my $count = 1;
    for my $pageinfo (@pageHistory) {
        my $rev = $pageinfo->{revision};
        if ($pageinfo->{userId}) {
            my $pageUser = $userDb->loadUser($pageinfo->{userId});
            $pageinfo->{userName} = $pageUser->username if ($pageUser);
        }
        if ($count < scalar @pageHistory) {
            if ($count == 1) {
                $pageinfo->{diffUrl} = 
                    "$base?action=browse&amp;diff=1&amp;id=$id";
            }
            else {
                $pageinfo->{diffUrl} = 
                    "$base?action=browse&amp;diff=1&amp;id=$id&amp;revision=$rev";
            }
        }
        if ($count == 1) {
            $pageinfo->{pageUrl} = "$base?$id";
            $pageinfo->{editUrl} = 
              "$base?action=edit&amp;id=$id";
        }
        else {
            $pageinfo->{pageUrl} = 
              "$base?action=browse&amp;id=$id&amp;revision=$rev";
            $pageinfo->{editUrl} = 
              "$base?action=edit&amp;id=$id&amp;revision=$rev";
        }
        $count++;
    }
    $wikiTemplate->vars(&globalTemplateVars,
                        pageName => $id,
                        visitedPages => \@vPages,
                        pageHistory => \@pageHistory);
    print GetHttpHeader() . $wikiTemplate->process('viewPageHistory');
}

# ==== page-oriented functions ====
sub GetHttpHeader {
    my $cookieName = ($config->CookieName) ? $config->CookieName :
        $config->SiteName;
    my $cookie = $q->cookie(-name => $cookieName,
                            -value => $session->id,
                            -path => $config->CookieDir,
                            -expires => '+7d');
    if ($config->HttpCharset ne '') {
        return $q->header(-cookie=>$cookie,
                          -type=>"text/html; charset=" . $config->HttpCharset);
    }
    return $q->header(-cookie=>$cookie);
}

sub ReBrowsePage {
  my $id = shift;

  print $q->redirect(-uri => $q->url(-full=>1) . "?$id");
}

# ==== Common wiki markup ====
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
sub ValidateId {
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

    $wikiTemplate->vars(&globalTemplateVars,
                        pageName => $id);
    $error = ValidateId($id);
    if ($error ne "") {
        print GetHttpHeader() . $wikiTemplate->process("errors/$error");
        return 0;
    }
    return 1;
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

  return CalcDay($t) . " " . CalcTime($t);
}

sub GetParam {
  my ($name, $default) = @_;
  my $result;

  $result = $q->param($name);
  if (!defined($result)) {
    if ($user && length($user->getField($name))) {
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
  if ($rhost eq "") {
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
  my ($id, $action, $search);

  $action = GetParam("action", "");
  $id = GetParam("id", "");
  my $iname = &GetParam("xri_iname", "");
  if ($action ne "") {
    $action = lc($action);
    if ($action eq "edit") {
      DoEdit($id, 0, undef, 0)  if ValidIdOrDie($id);
    } elsif ($action eq "unlock") {
      DoUnlock();
    } elsif ($action eq "index") {
      DoIndex();
    } elsif ($action eq "allpages") {
      DoAllPages();
    } elsif ($action eq "editprefs") {
      DoEditPrefs();
    } elsif ($config->UseINames && $action eq "getiname") {
      if (!$user) {
          &DoGetIname();
      }
      else { # return an error
      }
    } elsif ($action eq "login") {
      if ($config->LoginRedirect) {
          print 'Location: ' . $config->LoginRedirect . "\n\n";
      }
      else {
          DoEnterLogin(&GetParam("fromPage", ""));
      }
    } elsif ($action eq "newlogin") {
      $user = undef;
      DoEditPrefs();  # Also creates new ID
    } elsif ($action eq "logout") {
      &DoLogout;
    } elsif ($action eq 'rss') {
      require PurpleWiki::Syndication::Rss;
      my $rss = PurpleWiki::Syndication::Rss->new(userDb => $userDb);
      print $q->header(-type => 'text/xml') .
          $rss->getRSS;
    } else {
      # Later improve error reporting
      $wikiTemplate->vars(&globalTemplateVars,
                          action => $action);
      print GetHttpHeader() . $wikiTemplate->process('errors/actionInvalid');
    }
    return;
  }
  elsif ($config->UseINames && $iname) {
    my $xsid = &GetParam('xri_xsid', '');
    my $fromPage = &GetParam('fromPage', '');
    &DoIname($iname, $xsid, $fromPage);
    return;
  }

  $iname = &GetParam("iname", "");
  if ($config->UseINames && $iname) {
      my $localId = &GetParam("local_id", "");
      my $rrsid = &GetParam("rrsid", "");
      &DoAssociateIname($iname, $localId, $rrsid);
      return;
  }
  
  if (&GetParam("edit_prefs", 0)) {
    &DoUpdatePrefs();
    return;
  }
  if (GetParam("enter_login", 0)) {
    DoLogin();
    return;
  }
  $search = GetParam("search", "");
  if (($search ne "") || (GetParam("dosearch", "") ne "")) {
    DoSearch($search);
    return;
  }
  # Handle posted pages
  if (GetParam("oldrev", "") ne "") {
    $id = GetParam("title", "");
    DoPost()  if ValidIdOrDie($id);
    return;
  }
  # Later improve error message
  $wikiTemplate->vars(&globalTemplateVars);
  print GetHttpHeader() . $wikiTemplate->process('errors/urlInvalid');
}

sub DoEdit {
  my ($id, $isConflict, $newTree, $preview) = @_;
  my ($header, $editRows, $editCols, $revision, $oldText);
  my ($summary, $lastSavedTime);
  my $newText;
  unless (defined($newTree)) {
    my $revision = GetParam('revision','');
    $revision = '' if ($revision =~ /\D/);
    $newTree = $pages->getPage($id, $revision)->getTree();
  }
  if ($newTree) {
    $newText = $newTree->view('wikitext');
    $newText .= "\n"  unless (substr($newText, -1, "\n"));
  }

  my $page;
  my $text;

  my $pageName = $id;
  if ($config->FreeLinks) {
      $pageName =~ s/_/ /g;
  }

  if (!$acl->canEdit($user, $id)) {
      $wikiTemplate->vars(&globalTemplateVars);
      print GetHttpHeader() . $wikiTemplate->process('errors/editBlocked');
      return;
  }
  elsif (!$config->EditAllowed || -f $config->DataDir . "/noedit") {
      $wikiTemplate->vars(&globalTemplateVars);
      print GetHttpHeader() . $wikiTemplate->process('errors/editSiteReadOnly');
      return;
  }

  my ($username, $userId);
  if ($user) {
      $userId = $user->id;
      $username = $user->username;
  }
  $revision = GetParam('revision', '');
  if ($revision =~ /\D/) {
    # error bad revision
    $revision = '';
  }

  my $oldrev = $pages->getPage($id)->getRevision();  # get current revision

  $page = $pages->getPage($id, $revision);
  $lastSavedTime = localtime($page->getTime()) || 0;

  my @vPages = $session->visitedPages;

  my $currentTime = localtime;
  if ($isConflict) {
      $wikiTemplate->vars(&globalTemplateVars,
                          visitedPages => \@vPages,
                          id => $id,
                          pageName => $pageName,
                          revision => $revision,
                          isConflict => $isConflict,
                          lastSavedTime => $lastSavedTime,
                          currentTime => $currentTime,
                          oldrev => $oldrev,
                          oldText => &QuoteHtml($page->getTree->view('wikitext')),
                          newText => &QuoteHtml($newText),
                          revisionsUrl => $config->BaseURL
                                          . "?action=history&amp;id=$id");
      print GetHttpHeader() . $wikiTemplate->process('editConflict');
  }
  elsif ($preview) {
      my $url = $q->url(-full => 1) . '?' . $id;
      my $body = WikiHTML($id, $newTree, $url);

      $wikiTemplate->vars(&globalTemplateVars,
                          visitedPages => \@vPages,
                          id => $id,
                          pageName => $pageName,
                          revision => $revision,
                          isConflict => $isConflict,
                          oldrev => $oldrev,
                          oldText => &QuoteHtml($newText),
                          body => $body,
                          revisionsUrl => $config->BaseURL
                                          . "?action=history&amp;id=$id");
      print GetHttpHeader() . $wikiTemplate->process('previewPage');
  }
  else {
      $wikiTemplate->vars(&globalTemplateVars,
                          visitedPages => \@vPages,
                          id => $id,
                          pageName => $pageName,
                          revision => $revision,
                          oldText => &QuoteHtml($newText),
                          oldrev => $oldrev,
                          revisionsUrl => $config->BaseURL . "?action=history&amp;id=$id");
      print GetHttpHeader() . $wikiTemplate->process('editPage');
  }

  $summary = GetParam("summary", "*");
}

sub WikiHTML {
    my ($id, $wiki, $url) = @_;
    return "<p>New page, edit to create</p>" unless $wiki;
    $wiki->view('wikihtml', url => $url, pageName => $id,
                languages => [&preferredLanguages]);
}

sub DoEditPrefs {
  my $captchaCode;
  if (!$user && $useCap) {  # set up Authen::Captcha
      my $captcha = Authen::Captcha->new(data_folder => $config->CaptchaDataDir,
                                         output_folder => $config->CaptchaOutputDir);
      $captchaCode = $captcha->generate_code(4);
  }
  $wikiTemplate->vars(&globalTemplateVars,
                      captcha => $captchaCode,
                      captchaDir => $config->CaptchaWebDir,
                      rcDefault => $config->RcDefault,
                      serverTime => &TimeToText(time - $TimeZoneOffset),
                      tzOffset => &GetParam('tzoffset', 0));
  print GetHttpHeader() . $wikiTemplate->process('preferencesEdit');
}

sub GetFormText {
  my ($name, $default, $size, $max) = @_;
  my $text = GetParam($name, $default);

  return $q->textfield(-name=>"p_$name", -default=>$text,
                       -override=>1, -size=>$size, -maxlength=>$max);
}

sub GetFormCheck {
  my ($name, $default, $label) = @_;
  my $checked = (GetParam($name, $default) > 0);

  return $q->checkbox(-name=>"p_$name", -override=>1, -checked=>$checked,
                      -label=>$label);
}

sub DoUpdatePrefs {
  # if IP is on the banlist, don't allow updating preferences
  if (!$acl->canEdit($user, undef)) {
      $wikiTemplate->vars(&globalTemplateVars);
      print GetHttpHeader() . $wikiTemplate->process('errors/editBlocked');
      return;
  }
  my $captchaCode = &GetParam("captcha", "");
  if ($captchaCode) {  # human confirmation
    my $humanCode = &GetParam("human_code", "");
    if ($useCap) {
      my $captcha = Authen::Captcha->new(data_folder => $config->CaptchaDataDir,
                                         output_folder => $config->CaptchaOutputDir);
      my $result = $captcha->check_code($humanCode, $captchaCode);
      if ($result == -1) { # code expired
          $wikiTemplate->vars(&globalTemplateVars);
          print &GetHttpHeader . $wikiTemplate->process('errors/captchaInvalid');
          return;
      }
      elsif ($result < 0) { # invalid code
          $wikiTemplate->vars(&globalTemplateVars);
          print &GetHttpHeader . $wikiTemplate->process('errors/captchaInvalid');
          return;
      }
      elsif ($result == 0) { # file error
          $wikiTemplate->vars(&globalTemplateVars);
          print &GetHttpHeader . $wikiTemplate->process('errors/captchaInvalid');
          return;
      }
    }
  }
  my $username = &GetParam("p_username",  "");
  if ($username) {
      if ( (length($username) > 50) || # Too long
           ($userDb->idFromUsername($username)) ) {   # already used
          $wikiTemplate->vars(&globalTemplateVars,
                              userName => $username);
          print &GetHttpHeader . $wikiTemplate->process('errors/usernameInvalid');
          return;
      }
      else {
          &DoNewLogin if (!$user);  # should always be true
          $user->username($username);
      }
  }
  elsif (!$user) { # no username entered
      $wikiTemplate->vars(&globalTemplateVars,
                          userName => $username);
      print &GetHttpHeader . $wikiTemplate->process('errors/usernameInvalid');
      return;
  }
  else {
      $username = $user->username;
  }

  my $password = &GetParam("p_password",  "");

  my $passwordRemoved = 0;
  my $passwordChanged = 0;
  if ($password eq "") {
      $passwordRemoved = 1;
      $user->setPassword(undef);
  }
  elsif ($password ne "*") {
      $passwordChanged = 1;
      $user->setPassword($password);
  }

  UpdatePrefNumber("rcdays", 0, 0, 999999);
  UpdatePrefCheckbox("rcnewtop");
  UpdatePrefCheckbox("rcall");
  UpdatePrefCheckbox("rcchangehist");
  UpdatePrefCheckbox("editwide");

  UpdatePrefCheckbox("norcdiff");
  UpdatePrefCheckbox("diffrclink");
  UpdatePrefCheckbox("alldiff");
  UpdatePrefNumber("defaultdiff", 1, 1, 3);

  UpdatePrefNumber("rcshowedit", 1, 0, 2);
  UpdatePrefNumber("tzoffset", 0, -999, 999);
  UpdatePrefNumber("editrows", 1, 1, 999);
  UpdatePrefNumber("editcols", 1, 1, 999);

  $TimeZoneOffset = GetParam("tzoffset", 0) * (60 * 60);

  $userDb->saveUser($user);
  $wikiTemplate->vars(&globalTemplateVars,
                      passwordRemoved => $passwordRemoved,
                      passwordChanged => $passwordChanged,
                      serverTime => &TimeToText(time-$TimeZoneOffset),
                      localTime => &TimeToText(time));
  print &GetHttpHeader . $wikiTemplate->process('preferencesUpdated');
}

sub UpdatePrefCheckbox {
  my ($param) = @_;
  my $temp = GetParam("p_$param", "*");

  $user->setField($param, 1)  if ($temp eq "on");
  $user->setField($param, 0)  if ($temp eq "*");
  # It is possible to skip updating by using another value, like "2"
}

sub UpdatePrefNumber {
  my ($param, $integer, $min, $max) = @_;
  my $temp = GetParam("p_$param", "*");

  return  if ($temp eq "*");
  $temp =~ s/[^-\d\.]//g;
  $temp =~ s/\..*//  if ($integer);
  return  if ($temp eq "");
  return  if (($temp < $min) || ($temp > $max));
  $user->setField($param, $temp);
  # Later consider returning status?
}

sub DoIndex {
    my @list = ();
    for my $id ($pages->allPages($config)) {
        push(@list, { id => $id, pageName => $pages->getName($id) });
    }
    my @vPages = $session->visitedPages;

    $wikiTemplate->vars(&globalTemplateVars,
                        visitedPages => \@vPages,
                        pages => \@list);
    print GetHttpHeader() . $wikiTemplate->process('pageIndex');
}

sub DoAllPages {
    print "Content-Type: text/plain\n\n";
    for my $id ($pages->allPages($config)) {
        print $config->BaseURL . "?$id " . $pages->getName($id) . "\n";
    }
}

# Create a new user file/cookie pair
sub DoNewLogin {
    # Later consider warning if cookie already exists
    # (maybe use "replace=1" parameter)
    $user = $userDb->createUser;
    $user->setField('rev', 1);
    $user->createTime(time);
    $user->createIp($ENV{REMOTE_ADDR});
    $userDb->saveUser($user);

    $session->param('userId', $user->id);
}

sub CreateNewUser {  # same as DoNewLogin, but no login
    # Later consider warning if cookie already exists
    # (maybe use "replace=1" parameter)
    $user = $userDb->createUser;
    $user->setField('rev', 1);
    $user->createTime(time);
    $user->createIp($ENV{REMOTE_ADDR});
    $userDb->saveUser($user);

    # go back to being a guest
    my $localId = $user->id;
    $user = undef;
    return $localId;
}

sub DoEnterLogin {
    my $fromPage = shift;

    $wikiTemplate->vars(&globalTemplateVars,
                        fromPage => $fromPage);
    print GetHttpHeader() . $wikiTemplate->process('login');
}

sub DoLogin {
  my $success = 0;
  my $fromPage = &GetParam("fromPage", "");
  my $username = &GetParam("p_username", "");
  my $password = &GetParam("p_password",  "");
  $password = '' if ($password eq '*');

  my $userId = $userDb->idFromUsername($username);
  $user = $userDb->loadUser($userId);
  if ($user && defined($user->getField('password')) &&
      ($user->getPassword eq $password)) {
      $session->param('userId', $userId);
      $success = 1;
  }
  else {
      $user = undef;
  }
  if ($success && $fromPage) {
      print 'Location: ' . $config->BaseURL . "?$fromPage\n\n";
  }
  else {
      $wikiTemplate->vars(&globalTemplateVars,
                          enteredName => $username,
                          loginSuccess => $success);
      print GetHttpHeader() . $wikiTemplate->process('loginResults');
  }
}

sub DoLogout {
    if ($user && $config->UseINames && !&GetParam('xri_cmd', undef)) {
        my $spit = XDI::SSO->new;
        my $registry = XDI::Registry->new(
                name => $config->ServiceProviderName,
                key => $config->ServiceProviderKey
            );
        my $iname = $user->username;
        my ($idBroker, $inumber) = $spit->resolveBroker($iname);
#        $spit->logout($idBroker, $iname, $xsid) if ($idBroker);
        print "Location: " . $registry->logout($idBroker, $user->id,
                                               $config->ReturnUrl .
                                               "action=logout") . "\n\n";
        return;
    }
    $session->delete;
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
    $wikiTemplate->vars(&globalTemplateVars,
                        userName => undef,
                        prevUserName => $user->username);
    $user = undef;
    print $header . $wikiTemplate->process('logout');
}

sub DoGetIname {
    my $localId = &CreateNewUser if (!$user);
    my $spname = $config->ServiceProviderName;
    my $spkey = $config->ServiceProviderKey;
    my $rtnUrl = $config->ReturnUrl;
    my $rsid = &Digest::MD5::md5_hex("$localId$spkey");
    print "Location: http://dev.idcommons.net/register.html?registry=$spname&local_id=$localId&rsid=$rsid&rtn=$rtnUrl\n\n";
}

sub DoAssociateIname {
    my ($iname, $localId, $rrsid) = @_;

    if ( $rrsid = &Digest::MD5::md5_hex($localId . $config->ServiceProviderKey . 'x') &&
         (!$user) ) {
        # associate i-name with ID
        $user = $userDb->loadUser($localId);
        $user->username($iname);
        $userDb->saveUser($user);
        # now login
        my $spit = XDI::SSO->new;
        my ($idBroker, $inumber) = $spit->resolveBroker($iname);
        if ($idBroker) {
            my $redirectUrl = $spit->getAuthUrl($idBroker, $iname, $config->ReturnUrl);
            print "Location: $redirectUrl\n\n";
        }
        else {
            $wikiTemplate->vars(&globalTemplateVars);
            print &GetHttpHeader . $wikiTemplate->process('errors/inameInvalid');
        }
    }
    else {
        if ($user) {
            print STDERR "NOT GUEST USER\n";
        }
        $wikiTemplate->vars(&globalTemplateVars);
        print &GetHttpHeader . $wikiTemplate->process('errors/badInameRegistration');
    }
}

sub DoIname {
    my ($iname, $xsid, $fromPage) = @_;

    my $spit = XDI::SSO->new;
    my ($idBroker, $inumber) = $spit->resolveBroker($iname);
    if ($idBroker) {
        if ($xsid) {
            if ($spit->validateSession($idBroker, $iname, $xsid)) {
                $session->param('xsid', $xsid);
                my $userId = $userDb->idFromUsername($iname);
                if ($userId) {
                    $user = $userDb->loadUser($userId);
                    $session->param('userId', $userId);
                }
                else { # create new account
                    &DoNewLogin;
                    $user->username($iname);
                    $userDb->saveUser($user);
                }
                # successful login message
                if ($fromPage) {
                    print 'Location: ' . $config->BaseURL . "?$fromPage\n\n";
                }
                else {
                    $wikiTemplate->vars(&globalTemplateVars,
                                        loginSuccess => 1);
                    print &GetHttpHeader . $wikiTemplate->process('loginResults');
                }
            }
            else { # invalid xsid
                $wikiTemplate->vars(&globalTemplateVars);
                print &GetHttpHeader . $wikiTemplate->process('errors/xsidInvalid');
            }
        }
        else {
            my $returnUrl = $config->ReturnUrl;
            $returnUrl .= "fromPage=$fromPage&" if ($fromPage);
            my $redirectUrl = $spit->getAuthUrl($idBroker, $iname, $returnUrl);
            print "Location: $redirectUrl\n\n";
        }
    }
    else { # i-name didn't resolve
        $wikiTemplate->vars(&globalTemplateVars);
        print &GetHttpHeader . $wikiTemplate->process('errors/inameInvalid');
    }
}

sub DoSearch {
    my ($string) = @_;

    if ($string eq '') {
        DoIndex();
        return;
    }
    # do the new pluggable search
    my $search = new PurpleWiki::Search::Engine;
    $search->search($string);
print STDERR "Search res:",scalar($search->results),"\n";

    $wikiTemplate->vars(&globalTemplateVars,
                        keywords => $string,
                        modules => $search->modules,
                        results => $search->results);
    print GetHttpHeader() . $wikiTemplate->process('searchResults');
}

sub DoPost {
  my ($editDiff);
  my $userId = $user ? $user->id : undef;
  my $string = GetParam("text", undef);
  my $id = GetParam("title", "");
  my $summary = GetParam("summary", "");
  my $authorAddr = $ENV{REMOTE_ADDR};

  my $error_template = '';
  $error_template = 'errors/editNotAllowed' if (!$acl->canEdit($user, $id));
  $error_template = 'errors/pageCannotBeDefined'
      if (($id eq 'SampleUndefinedPage') || ($id eq 'Sample_Undefined_Page'));
  if ($config->SpamRegexp) {
      my $foundSpam = 0;
      if (open(SPAMRE, $config->SpamRegexp)) {
          while (!$foundSpam && (my $re = <SPAMRE>)) {
              chomp $re;
              $foundSpam = 1 if ($string =~ /$re/);
          }
          close(SPAMRE);
      }
      $error_template = 'errors/editNotAllowed' if $foundSpam;
  }

  if ($error_template) {
      $wikiTemplate->vars(&globalTemplateVars,
                          pageName => $id);
      print GetHttpHeader() . $wikiTemplate->process($error_template);
      return;
  }

  # adjust the contents of $string with the wiki drivers to save purple
  # numbers

  # clean \r out of string
  $string =~ s/\r//g;

  my $wiki = $wikiParser->parse($string,
                                'add_node_ids'=>1,
                                'freelink' => $config->FreeLinks);

  $summary =~ s/[\r\n]//g;
  # Add a newline to the end of the string (if it doesn't have one)

  my $preview = (GetParam("Preview", "") ne "");
  if ($preview) {
    my $page = $pages->getPage($id);

    my $oldrev = GetParam("oldrev", "");
    my $currev = $page->getRevision();
    my $newAuthor;
    # Later extract comparison?
    if ($user || ($page->getUserID() > 399))  {
      $newAuthor = ($user->id ne $page->getUserID());       # known user(s)
    } else {
      $newAuthor = ($page->getHost ne $authorAddr);  # hostname fallback
    }
    $newAuthor = 1  if ($oldrev == 0);  # New page
    $newAuthor = 0  if (!$newAuthor);   # Standard flag form, not empty
    # Detect editing conflicts and resubmit edit
    if (($currev > 0) && $newAuthor && ($oldrev != $currev)) {
#print STDERR "OR: $oldrev CR: $currev\n";
      if (GetParam("oldconflict", 0) > 0) {  # Conflict again...
        DoEdit($id, 2, $wiki, 1);
      } else {
        DoEdit($id, 1, $wiki, 1);
      }
      return;
    }

    DoEdit($id, 0, $wiki, 1);
    return;
  }

  if ($pages->putPage(pageId => $id,
                      tree => $wiki,
                      url=> $config->BaseURL . "?$id",
                      oldrev => GetParam("oldrev", ""),
                      changeSummary => $summary,
                      host => GetRemoteHost(1),
                      userId => $userId)) {

    if (GetParam("oldconflict", 0) > 0) {  # Conflict again...
      DoEdit($id, 2, $wiki, 0);
    } else {
      DoEdit($id, 1, $wiki, 0);
    }
    return;
  }
  &ReBrowsePage($id);
}

sub DoUnlock {
    my $forcedUnlock = 0;

    if ($pages->forceReleaseLock('main', $config)) {
        $forcedUnlock = 1;
    }
    $wikiTemplate->vars(&globalTemplateVars,
                        forcedUnlock => $forcedUnlock);
    print GetHttpHeader() . $wikiTemplate->process('removeEditLock');
}

# ==== Difference markup and HTML ====
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
                $added = QuoteHtml($added);
                $added =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'added', text => $added };
                $added = '';
            }
            elsif ($removed) {
                $removed = QuoteHtml($removed);
                $removed =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'removed', text => $removed };
                $removed = '';
            }
            push @diffs, { type => 'status', text => "$statusType$statusMessage" };
        }
        elsif ($line =~ /^</) { # removed
            if ($added) {
                $added = QuoteHtml($added);
                $added =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'added', text => $added };
                $added = '';
            }
            $line =~ s/^< //;
            $removed .= "$line\n";
        }
        elsif ($line =~ /^>/) { # added
            if ($removed) {
                $removed = QuoteHtml($removed);
                $removed =~ s/\n/<br \/>\n/sg;
                push @diffs, { type => 'removed', text => $removed };
                $removed = '';
            }
            $line =~ s/^> //;
            $added .= "$line\n";
        }
    }
    if ($added) {
        $added = QuoteHtml($added);
        $added =~ s/\n/<br \/>\n/sg;
        push @diffs, { type => 'added', text => $added };
        $added = '';
    }
    elsif ($removed) {
        $removed = QuoteHtml($removed);
        $removed =~ s/\n/<br \/>\n/sg;
        push @diffs, { type => 'removed', text => $removed };
        $removed = '';
    }
    return \@diffs;
}

sub logSession {
    open FH, ">>$CONFIG_DIR/session_log";
    print FH time . "\t" . $session->id . "\t" . $q->request_method . "\t";
    print FH $q->query_string if ($q->request_method ne 'POST');
    print FH "\t" . $q->remote_host . "\t" . $session->param('userId') . "\t" .
        $q->referer . "\n";
    close FH;
}

sub expandPageName {
    my $pageName = shift;

    if ($pageName !~ / /) {
        $pageName =~ s/([a-z0-9])([A-Z])/$1 $2/g;
        $pageName =~ s/([a-z])([0-9])/$1 $2/g;
    }
    return $pageName;
}

sub globalTemplateVars {
    return (siteName => $config->SiteName,
            baseUrl => $config->BaseURL,
            stylesheet => $config->StyleSheet,
            logoUrl => $config->LogoURL,
            homePage => $config->HomePage,
            userName => $user ? $user->username : undef,
            userId => $user ? $user->id : undef,
            preferencesUrl => $config->BaseURL . '?action=editprefs',
            sessionId => $session ? $session->id : undef,
            stylesheet => $config->StyleSheet,
            logoUrl => $config->LogoURL);
}

my $is_require = (caller($_))[7];
&DoWikiRequest()  if (!$is_require && $config->RunCGI && ($_ ne 'nocgi'));   # Do everything.
1; # In case we are loaded from elsewhere
# == End of UseModWiki script. ===========================================
