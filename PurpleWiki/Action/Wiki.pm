#!/usr/bin/perl
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# ??? - PurpleWiki
#
# $Id:  $
#
# Copyright (c) Blue Oxen Associates 2004.  All rights reserved.
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

package PurpleWiki::Action::Wiki;

# Action/Wiki.pm
############################ Wiki actions ######################
my %actions = (
  browse  => \&PurpleWiki::browsePage,
  rc      => \&PurpleWiki::doRecentChanges,
  random  => \&PurpleWiki::doRandom,
  history => \&PurpleWiki::doHistory,
  edit    => \&PurpleWiki::doEdit,
  preview => \&PurpleWiki::doPreview,
  index   => \&PurpleWiki::doIndex,
  dopost  => \&PurpleWiki::doPost,
  diff    => \&PurpleWiki::doDiff,
);

sub register {
  my $reqHandler = shift;

  for my $action (keys %actions) {
    $reqHandler->register($action, $actions{$action});
  }
}

package PurpleWiki;

sub setupPage {
  my $request = shift;
#for my $k (keys %$request) { print STDERR "Rq:$k > $request->{$k}:\n"; }
  my $id = $request->id();
  my $revision = $request->revision();
  my $user = $request->user();
  my $context = $request->context();
  my $config = $context->{config};
  my $archive = $context->{archive};
  my $acl = $context->{acl};
  my $template = $context->{template};
  my $body;

  my ($text);

  # probably should go in wiki.pl?
  if (!$acl->canRead($user, $id)) {
      $template->vars(&globalTemplateVars($request));
      $request->getHttpHeader();
      print $template->process('errors/viewNotAllowed');
      return;
  }
  my ($userId, $username);
  if ($user) {
      $userId = $user->id;
      $username= $user->username;
  }

  my $pageName = $archive->getName($id);
  my $page = $archive->getPage($id, $revision);

  my $url = $config->BaseURL . '?' . $id;
  $body = WikiHTML($id, $page->getTree(), $url,
                   $archive, [&preferredLanguages($request)]);

  &updateVisitedPagesCache($request);
  return ($request, $id, $pageName, $revision, $body, $page->getTime());
}

#browse => &browsePage
sub browsePage {
  my ($request, $id, $pageName, $revision, $body, $pageTime) = &setupPage ;
  my $context = $request->context();
  my $config = $context->{config};
  my $acl = $context->{acl};
  my $template = $context->{template};

  my @vPages = &visitedPages;
  my $keywords = $id;
  $keywords =~ s/_/\+/g if ($config->FreeLinks);

  my $editRevisionString = ($revision) ? "&amp;revision=$revision" : '';

  $template->vars(&globalTemplateVars($request),
                  pageName => $pageName,
                  expandedPageName => &expandPageName($pageName),
                  id => $id,
                  visitedPages => \@vPages,
                  revision => $revision,
                  body => $body,
                  lastEdited => TimeToText($pageTime),
                  pageUrl => $config->BaseURL . "?$id",
                  backlinksUrl => $config->BaseURL . "?search=$keywords",
                  editUrl => $acl->canEdit($user, $id)
                          ?   $config->BaseURL . "?action=edit&amp;id=$id"
                              . $editRevisionString
                          : undef,
                  revisionsUrl => $config->BaseURL."?action=history&amp;id=$id",
                  diffUrl => $config->BaseURL."?action=browse&amp;diff=1&amp;id=$id");
  $request->getHttpHeader();
  print $template->process('viewPage');
}

#  if (getParam("oldrev", "") ne "") {
#    $id = getParam("title", "");
# &DoEdit
#dopost => &doPost,
sub doPost {
  my $request = shift;
  my $q = $request->CGI();
  my $context = $request->context();
  my $archive = $context->{archive};
  my $config = $context->{config};
  my $wikiParser = $context->{wikiparser};
  my $template = $context->{template};
  my $acl = $context->{acl};

  my ($editDiff);
  my $user = $request->user();
  my $userId = $user ? $user->id : undef;
  my $string = $request->text();
  my $id = $request->id();
  my $summary = $request->summary();
  my $authorAddr = $ENV{REMOTE_ADDR};

  # adjust the contents of $string with the wiki drivers to save purple
  # numbers

  # clean \r out of string
  $string =~ s/\r//g;

  my $wiki = $wikiParser->parse($string,
                                'add_node_ids'=>1,
                                'freelink' => $config->FreeLinks);

  my $error_template = '';
  $error_template = 'errors/editNotAllowed'
      if (!$acl->canEdit($user, $id));
  $error_template = 'errors/pageCannotBeDefined'
      if (($id eq 'SampleUndefinedPage') || ($id eq 'Sample_Undefined_Page'));
  if ($error_template) {
    $template->vars(&globalTemplateVars($request), pageName => $id);
    $request->getHttpHeader();
    print $template->process($error_template);
    return;
  }

  $summary =~ s/[\r\n]//g;
  # Add a newline to the end of the string (if it doesn't have one)

  if ($request->action() eq 'preview') {
    my $page = $archive->getPage($id);

    my $oldrev = $q->param("oldrev");
    my $currev = $page->getRevision();
    my $newAuthor;
    # Later extract comparison?
    if ($user || ($page->getUserID() > 399))  {
      $newAuthor = ($user->id ne $page->getUserID());       # known user(s)
    } else {
      $newAuthor = ($page->getIP() ne $authorAddr);  # hostname fallback
    }
    $newAuthor = 1  if ($oldrev == 0);  # New page
    $newAuthor = 0  if (!$newAuthor);   # Standard flag form, not empty
    # Detect editing conflicts and resubmit edit
    if (($currev > 0) && $newAuthor && ($oldrev != $currev)) {
#print STDERR "OR: $oldrev CR: $currev\n";
      if ($request->oldconflict() > 0) {  # Conflict again...
        DoEdit($request, $id, 2, $wiki, 1);
      } else {
        DoEdit($request, $id, 1, $wiki, 1);
      }
      return;
    }

    DoEdit($request, $id, 0, $wiki, 1);
    return;
  }

  if ($archive->putPage(pageId => $id,
                      tree => $wiki,
                      url=> $config->BaseURL . "?$id",
                      oldrev => $request->oldrev(),
                      changeSummary => $summary,
                      host => GetRemoteHost(1),
                      userId => $userId)) {

    if (($q->param("oldconflict")||0) > 0) {  # Conflict again...
      DoEdit($request, $id, 2, $wiki, 0);
    } else {
      DoEdit($request, $id, 1, $wiki, 0);
    }
    return;
  }
  $request->reBrowsePage($id);
}

sub doDiff {
  my ($request, $id, $pageName, $revision, $body, $pageTime) = &setupPage ;
  my $context = $request->context();
  my $config = $context->{config};
  my $template = $context->{template};
  my $archive = $context->{archive};

  $diffRevision = $request->diffrevision();
#print STDERR "Diff($id, $diffRevision, $revision)\n";
  my $diffText = $archive->diff($id, $diffRevision, $revision);
  my $time = $archive->getPage($id, $revision)->getTime;
  $template->vars(&globalTemplateVars($request),
                  pageName => $pageName,
                  revision => $diffRevision || $revision,
                  diffs => getDiffs($diffText),
                  lastEdited => TimeToText($time),
                  pageUrl => $config->BaseURL . "?$id",
                  backlinksUrl => $config->BaseURL . "?search=$id",
                  revisionsUrl => $config->BaseURL
                                  . "?action=history&amp;id=$id");
  $request->getHttpHeader();
  print $template->process('viewDiff');
  return;
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

#rc => &doRecentChanges,
sub doRecentChanges {
  my ($request, $id, $pageName, $revision, $body) = &setupPage ;
#print STDERR "doRecentChanges($id, $pageName, $revision)\n";
  my $user = $request->user();
  my $context = $request->context();
  my $config = $context->{config};
  my $archive = $context->{archive};
  my $template = $context->{template};
  my $acl = $context->{acl};
  my $q = $request->CGI();
  my $starttime = 0;
  my $daysago;
  my @rcDays;
  foreach my $days (@{$config->RcDays}) {
      push @rcDays, { num => $days,
                      url => $config->BaseURL .
                          "?action=rc&amp;days=$days" };
  }
  if ($q->param("from", 0)) {
      $starttime = $q->param("from", 0);
  }
  else {
      $daysago = $q->param("days");
      $daysago = GetParam($user, 'rcdays', $config->RcDefault)
          unless (defined($daysago));
      if ($daysago) {
          $starttime = time - ((24*60*60)*$daysago);
      }
  }
  my $rcRef = $archive -> recentChanges($starttime);
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
            pageName => $archive->getName($pageId),
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
  my @vPages = &visitedPages;
  $template->vars(&globalTemplateVars($request),
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
                  pageUrl => $config->BaseURL . "?$id",
                  backlinksUrl => $config->BaseURL . "?search=$id",
                  editUrl => $acl->canEdit($user, $id) ?
                          $config->BaseURL . "?action=edit&amp;id=$id" : undef,
                  revisionsUrl => $config->BaseURL."?action=history&amp;id=$id",
                  diffUrl => $config->BaseURL
                             . "?action=browse&amp;diff=1&amp;id=$id");
  $request->getHttpHeader();
  print $template->process('viewRecentChanges');
}

sub doRandom {
  my $request = shift;
  my $context = $request->context();
  my $archive = $context->{archive};
  my ($id, @pageList);

  @pageList = $archive->allPages();  # Optimize?
  $id = $pageList[int(rand($#pageList + 1))];
  $request->reBrowsePage($id);
}

#  } elsif ($action eq 'history') {
#history => &doHistory
sub doHistory {
    my $request = shift;
    my $id = $request->id();
    my $context = $request->context();
    my $archive = $context->{archive};
    my $userDb = $context->{userdb};
    my $template = $context->{template};
    my $config = $context->{config};
    my $text;

    my $base = $config->BaseURL;
    my @vPages = &visitedPages;
    my @pageHistory = $archive->getRevisions($id);
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
    $template->vars(&globalTemplateVars($request),
                    pageName => $id,
                    visitedPages => \@vPages,
                    pageHistory => \@pageHistory);
    $request->getHttpHeader();
    print $template->process('viewPageHistory');
}

sub doEdit {
  my ($request, $id) = &setupPage ;
  &DoEdit($request, $id, 0, undef, 0);
}

sub doPreview {
  my ($request, $id, $pageName, $revision, $body, $pageTime) = &setupPage ;
  my $url = $q->url(-full => 1) . '?' . $id;
  my $body = WikiHTML($id, $newTree, $url,
                      $archive, [&preferredLanguages($request)]);

  $template->vars(&globalTemplateVars($request),
                  visitedPages => \@vPages,
                  id => $id,
                  pageName => $pageName,
                  revision => $revision,
                  isConflict => $isConflict,
                  pageTime => $pageTime,
                  oldrev => $oldrev,
                  oldText => &QuoteHtml($newText),
                  body => $body,
                  revisionsUrl => $config->BaseURL
                                  . "?action=history&amp;id=$id");
  $request->getHttpHeader();
  print $template->process('previewPage');
}

sub DoEdit {
  my ($request, $id, $isConflict, $newTree, $preview) = @_;
#print STDERR "DoEdit($request, $id, $idConflict, $newTree, $preview)\n";
  my $context = $request->context();
  my $acl = $context->{acl};
  my $config = $context->{config};
  my $archive = $context->{archive};
  my $template = $context->{template};
  my ($header, $editRows, $editCols, $revision, $oldText, $pageTime);
  my $newText;
  unless (defined($newTree)) {
    my $revision = $request->revision();
    $newTree = $archive->getPage($id, $revision)->getTree();
#print STDERR "NewTree:$newTree\n";
  }
  if ($newTree) {
    $newText = $newTree->view('wikitext');
    $newText .= "\n"  unless (substr($newText, -1, "\n"));
#print STDERR "NewText:$newText\n";
  }

  my $page;
  my $text;

  my $pageName = $id;
  if ($config->FreeLinks) {
      $pageName =~ s/_/ /g;
  }

  if (!$acl->canEdit($user, $id)) {
      $template->vars(&globalTemplateVars($request));
      $request->getHttpHeader();
      print $template->process('errors/editBlocked');
      return;
  }
  elsif (!$config->EditAllowed || -f $config->DataDir . "/noedit") {
      $template->vars(&globalTemplateVars($request));
      $request->getHttpHeader();
      print $template->process('errors/editSiteReadOnly');
      return;
  }

  my $user = $request->user();
  my ($username, $userId);
  if ($user) {
      $userId = $user->id;
      $username = $user->username;
  }
  $revision = $request->revision();
#print STDERR ">>$id: U:$user Rv:$revision";
  $page = $archive->getPage($id, $revision);
  my $oldrev = $page->getRevision;

  $pageTime = $page->getTime() || 0;
#print STDERR " Tm:$pageTime Orv:$oldrev";
  my @vPages = &visitedPages;

  if ($isConflict) {
      $template->vars(&globalTemplateVars($request),
                      visitedPages => \@vPages,
                      id => $id,
                      pageName => $pageName,
                      revision => $revision,
                      isConflict => $isConflict,
                      pageTime => $pageTime,
                      oldrev => $oldrev,
                      oldText => &QuoteHtml($page->getTree()
                                   ->view('wikihtml', archive => $archive)),
                      newText => &QuoteHtml($newText),
                      revisionsUrl => $config->BaseURL
                                      . "?action=history&amp;id=$id");
      $request->getHttpHeader();
      print $template->process('editConflict');
  }
  else {
      $template->vars(&globalTemplateVars($request),
                      visitedPages => \@vPages,
                      id => $id,
                      pageName => $pageName,
                      revision => $revision,
                      pageTime => $pageTime,
                      oldText => &QuoteHtml($newText),
                      oldrev => $oldrev,
                      revisionsUrl => $config->BaseURL . "?action=history&amp;id=$id");
      $request->getHttpHeader();
      print $template->process('editPage');
  }
}

# ($action eq "index")
# Called for search with a null string
sub doIndex {
    my $request = shift;
    my $context = $request->context();
    my $archive = $context->{archive};
    my $template = $context->{template};
    my @list = ();
    for my $id ($archive->allPages($config)) {
        push(@list, { id => $id, pageName => $archive->getName($id) });
    }
    my @vPages = &visitedPages;

    $template->vars(&globalTemplateVars($request),
                    visitedPages => \@vPages,
                    pages => \@list);
    $request->getHttpHeader();
    print $template->process('pageIndex');
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

sub WikiHTML {
    my ($id, $wiki, $url, $archive, $languages) = @_;
    return "<p>New page, edit to create</p>" unless $wiki;
    $wiki->view('wikihtml', url => $url, pageName => $id, archive => $archive,
                languages => $languages);
}

# ==== Misc. functions ====
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
  #if (($TimeZoneOffset == 0) && ($config->ScriptTZ ne "")) {
  #  $mytz = " " . $config->ScriptTZ;
  #}
  $ampm = " am";
  if ($hour > 11) {
    $ampm = " pm";
    $hour = $hour - 12;
  }
  $hour = 12   if ($hour == 0);
  $min = "0" . $min   if ($min<10);
  return $hour . ":" . $min . $ampm . $mytz;
}

sub TimeToText {
  my ($t) = @_;

  return CalcDay($t) . " " . CalcTime($t);
}

sub GetParam {
  my ($user, $name, $result) = @_;

  $result = $user->getField($name)
      if ($user && length($user->getField($name)));
  return $result;
}

1;
