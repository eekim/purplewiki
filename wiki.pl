#!/usr/bin/perl
# vi:et:tw=0:sm:ai:ts=2:sw=2
#
# wiki.pl - PurpleWiki
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2004.  All rights reserved.
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

package PurpleWiki;

use lib '/home/gerry/purple/blueoxen/branches/action-plugins';

use strict;
my $useCap = 0;
eval "use Authen::Captcha";
$useCap = 1 if (!$@);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use PurpleWiki::Config;
use PurpleWiki::Session;

my $CONFIG_DIR = $ENV{PW_CONFIG_DIR} || '/var/www/wikidb';

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

my $InterSiteInit = 0;
my %InterSite;
my $visitedPagesCache;
my $visitedPagesCacheSize = 7;

my $q;                  # CGI query reference

# we only need one of each these per run
my $config = new PurpleWiki::Config($CONFIG_DIR);
my %context = ();
$context{config} = $config;

my @modules = qw( wikiparser archive userdb template request acl spit search );
my $modules = $config->Driver;
my @loaderror = ();

for my $module (@modules) {
    loadModule($module, $modules->{$module});
}

for my $module (keys %$modules) {
    loadModule($module, $modules->{$module}) unless ($context{$module});
}

my $actions = $config->Action;
my $requestHandler = $context{request};
my $pages = $context->{archive};

for my $action (keys %$actions) {
    my $class = $actions->{$action};
    next unless $class;
    eval "require $class";
    if ($@) {
print STDERR "Error $@ loading $class for $action\n";
        push(@loaderror, "Error $@ loading $class for $action\n");
        next;
    }
#print STDERR "Loaded Action $action ${class}::register(\$requestHandler)\n";
    eval "${class}::register(\$requestHandler)";
#print STDERR "register($@)\n" if ($@);
}

#my $wikiParser = $context{wikiparser};
#my $wikiTemplate = $context{template};
my $userDb = $context{userdb};
#my $acl = $context{acl};

# check for i-names support ???
if ($config->UseINames) {
    require XDI::SPIT;
}

# Set our umask if one was put in the config file. - matthew
umask(oct($config->Umask)) if defined $config->Umask;

sub loadModule {
    my $module = shift;
    my $class = shift;
    return unless $class;
#print STDERR "Loading Module $module $class\n";
    eval "require $class";
    if ($@) {
        push(@loaderror, "Error $@ loading $class for $module\n");
        next;
    }
    unless ($context{$module} = ($module eq 'archive')
                                ? $class->new($config, create => 1)
                                : $class->new($config)) {
        push(@loaderror, "Error loading $class for $module");
        $context{$module} = 1;
    }
}

# CGI requests
sub InitCGIRequest {
    my $req = shift;
    my $q;
    if ($req) {
        $q = $req;
    } else {
        $CGI::POST_MAX = $config->MaxPost;
        $CGI::DISABLE_UPLOADS = 1;  # no uploads
        $q = new CGI;
        #dumpParams($q);
    }

    if (@loaderror) {
print STDERR "Loading errors:\n",@loaderror,"\n";
        $context{template}->vars(error => \@loaderror);
        print "Context-Type: text/html\n\n";
        print $context{template}->process('errors/internalError');
        return 0;
    }
    my $tzoffset = 0;
    undef $q->{'.cookies'};  # Clear cache if it exists (for SpeedyCGI)

    my $sid = ($config->CookieName) ? $q->cookie($config->CookieName)
                                    : $q->cookie($config->SiteName);
    my $session = PurpleWiki::Session->new($sid);
    my $userId = $session->param('userId');
    my $user;
    $user = $userDb->loadUser($userId) if ($userId);
    $session->clear(['userId']) if (!$user);

    if ($user && $user->tzOffset != 0) {
        $tzoffset = $user->tzOffset * (60 * 60);
    }

#print STDERR "Parse request $user $session $q\n";
    my $request = $context{request}->parseRequest(\%context, $user, cgi => $q,
                    user => $user, session => $session, tzoffset => $tzoffset);
    $visitedPagesCache = $session->param('visitedPagesCache') || {};
    $request;
}

sub DoCGIRequest {
    my $request = InitCGIRequest(@_);
print STDERR "Warning: missing request\n" unless $request;
    return unless $request;
    my $context = $request->context();
    my $template = $context->{template};
    my $error = $request->error();
    if ($error) {
        $request->getHttpHeader;
        $template->vars(&globalTemplateVars($request),
                        pageName => $request->id());
        print $template->process("errors/$error");
        return;
    }

#print STDERR "R:",ref($request)," :$request->{action}:\n";
    my $actionMethod = $request->action();
    if (ref($actionMethod)) {
        &$actionMethod($request);
    } else {
        $template->vars(&globalTemplateVars($request),
                          error => "Action $actionMethod not specified\n");
        $request->getHttpHeader;
        print $template->process('errors/internalError');
        return 0;
    }
    &logSession($request);
}

# handle requests from command line invocation.
sub InitCommandRequst {
    die join("\n",@loaderror)."\nError initializing modules\n" if (@loaderror);

    my $request = $context{request}->parseRequest(\%context, undef, argv => \@ARGV);
    $request;
}

sub DoCommandRequest {
    my $request = InitCommandRequest();
    my $actionMethod = $requestHandler->action();
    if (ref($actionMethod)) {
        &$actionMethod($request);
        &logSession($request);
    } else {
        die "Action $actionMethod not specified\n";
    }
}

<<<<<<< .working
# debugging only
sub dumpParams {
  my $q = shift;
  my $F;
  open($F, ">>/tmp/form_log");
  print $F $q->url(-path_info=>1),"\n";
  $q->save($F);
  close $F;
=======
sub DoEdit {
  my ($id, $isConflict, $newTree, $preview) = @_;
  my ($header, $editRows, $editCols, $revision, $oldText);
  my ($summary, $pageTime);
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
  $pageTime = $page->getTime() || 0;

  my @vPages = &visitedPages;

  if ($isConflict) {
      $wikiTemplate->vars(&globalTemplateVars,
                          visitedPages => \@vPages,
                          id => $id,
                          pageName => $pageName,
                          revision => $revision,
                          isConflict => $isConflict,
                          pageTime => $pageTime,
                          oldrev => $oldrev,
                          oldText => &QuoteHtml($page->getTree()->view('wikihtml')),
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
                          pageTime => $pageTime,
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
                          pageTime => $pageTime,
                          oldText => &QuoteHtml($newText),
                          oldrev => $oldrev,
                          revisionsUrl => $config->BaseURL . "?action=history&amp;id=$id");
      print GetHttpHeader() . $wikiTemplate->process('editPage');
  }

  $summary = GetParam("summary", "*");
>>>>>>> .merge-right.r596
}

##### Common support #####

<<<<<<< .working
sub preferredLanguages {
    my $request = shift;
    my $q = $request->CGI();
    my @langStrings = split(/\s*,\s*/, $q->http('Accept-Language'));
    my @languages;
    my @toSort;
    foreach my $lang (@langStrings) {
        if ($lang =~ /^\s*([^\;]+)\s*\;\s*q=(.+)\s*$/) {
            push @toSort, { lang => $1, q => $2 };
=======
sub DoEditPrefs {
  my $captchaCode;
  if (!$user && $useCap) {  # set up Authen::Captcha
      my $captcha = Authen::Captcha->new(data_folder => $config->CaptchaDataDir,
                                         output_folder => $config->CaptchaOutputDir);
      $captchaCode = $captcha->generate_code(7);
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
      $user->setField('password', undef);
  }
  elsif ($password ne "*") {
      $passwordChanged = 1;
      $user->setField('password', $password);
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
    my @vPages = &visitedPages;

    $wikiTemplate->vars(&globalTemplateVars,
                        visitedPages => \@vPages,
                        pages => \@list);
    print GetHttpHeader() . $wikiTemplate->process('pageIndex');
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
      ($user->getField('password') eq $password)) {
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
    if ($config->UseINames && (my $xsid = $session->param('xsid')) ) {
        my $spit = XDI::SPIT->new;
        my $iname = $user->username;
        my ($idBroker, $inumber) = $spit->resolveBroker($iname);
        $spit->logout($idBroker, $iname, $xsid) if ($idBroker);
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
        my $spit = XDI::SPIT->new;
        my ($idBroker, $inumber) = $spit->resolveBroker($iname);
        if ($idBroker) {
            my $redirectUrl = $spit->getAuthUrl($idBroker, $iname, $config->ReturnUrl);
            print "Location: $redirectUrl\n\n";
>>>>>>> .merge-right.r596
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

sub logSession {
  my $request = shift;
  my $q = $request->CGI();
  open FH, ">>$CONFIG_DIR/session_log" || return;
  if ($q) {
    print FH time, "\t", $request->session->id, "\t", $q->request_method, "\t";
    print FH $q->query_string if ($q->request_method ne 'POST');
    print FH "\t", $q->remote_host, "\t", $request->session->param('userId'),
             "\t",  $q->referer . "\n";
  } else {
    print FH time,"\t\tCOMMAND\t";
    print FH join(", ", $request->ARGS()),"\n";
  }
  close FH;
}

sub updateVisitedPagesCache {
    my $request = shift;
    my $id = $request->id();

    my @pages = keys %{$visitedPagesCache};
    if (!defined $visitedPagesCache->{$id} &&
        (scalar @pages - 1 >= $visitedPagesCacheSize)) {
        my @oldestPages = sort {
            $visitedPagesCache->{$a} <=> $visitedPagesCache->{$b}
        } @pages;
        my $remove = scalar @pages - $visitedPagesCacheSize + 1;
        for (my $i = 0; $i < $remove; $i++) {
            delete $visitedPagesCache->{$oldestPages[$i]};
        }
    }
    $visitedPagesCache->{$id} = time;
    $request->session->param('visitedPagesCache', $visitedPagesCache);
}

sub visitedPages {
    my @pages = sort { $visitedPagesCache->{$b} <=> $visitedPagesCache->{$a} }
        keys %{$visitedPagesCache};
    my $i = 0;
    foreach my $id (@pages) {
        my $pageName = $id;
        $pageName =~ s/_/ /g if ($config->FreeLinks);
        $pages[$i] = {
            'id' => $id,
            'pageName' => $pageName,
        };
        $i++;
    };
    return @pages;
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
    my $request = shift;
    my $user = $request->user();
    my $session = $request->session();
    my $config = $request->context()->{config};

    return (siteName => $config->SiteName,
            baseUrl => $config->BaseURL,
            homePage => $config->HomePage,
            userName => $user ? $user->username : undef,
            userId => $user ? $user->id : undef,
            preferencesUrl => $config->BaseURL . '?action=editprefs',
            sessionId => $session ? $session->id : undef);
}

my $is_require = (caller($_))[7];
&DoCGIRequest()  if (!$is_require && $config->RunCGI && $ENV{SCRIPT_NAME});
&DoCommandRequest() if (!$is_require && @ARGV);

1;
