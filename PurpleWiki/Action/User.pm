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

package PurpleWiki::Action::User;

#Action/User.pm
my %actions = (
iname          => \&PurpleWiki::doIname,
associateiname => \&PurpleWiki::doAssociateIname,
getiname       => \&PurpleWiki::doGetIname,

editprefs      => \&PurpleWiki::doEditPrefs,
updateprefs    => \&PurpleWiki::doUpdatePrefs,

dologin        => \&PurpleWiki::doLogin,
logout         => \&PurpleWiki::doLogout,
login          => \&PurpleWiki::doEnterLogin,
newlogin       => \&PurpleWiki::doNewLogin,
);

sub register {
  my $reqHandler = shift;

  for my $action (keys %actions) {
    $reqHandler->register($action, $actions{$action});
  }
}

package PurpleWiki;

# Action/User.pm 
## User preferences module
# $action eq "editprefs"
# $action eq "newlogin"  -> $user = undef;
# $user $useCap $wikiTemplate
# &globalTemplateVars
#editprefs => &doEditPrefs,
sub doEditPrefs {
  my $request = shift;
  my $user = $request->user();
  my $context = $request->context();
  my $wikiTemplate = $context->{template};
  my $config = $context->{config};
  my $captchaCode;
  if (!$user && $useCap) {  # set up Authen::Captcha
      my $captcha = Authen::Captcha->new(data_folder => $config->CaptchaDataDir,
                                         output_folder => $config->CaptchaOutputDir);
      $captchaCode = $captcha->generate_code(7);
  }
  $wikiTemplate->vars(&globalTemplateVars($request),
                      captcha => $captchaCode,
                      captchaDir => $config->CaptchaWebDir,
                      rcDefault => $config->RcDefault,
                      serverTime => &TimeToText(time - $TimeZoneOffset),
                      tzOffset => &GetParam('tzoffset', 0));
  $request->getHttpHeader();
  print $wikiTemplate->process('preferencesEdit');
}

# &getParam("edit_prefs", 0) (Submit of editprefs form)
# $user $useCap $wikiTemplate
# Params: captcha, human_code, p_username
# &DoNewLogin
#updateprefs => &doUpdatePrefs,
sub doUpdatePrefs {
  my $request = shift;
  my $q = $request->CGI();
  my $user = $request->user();
  my $wikiTemplate = $request->context()->{template};
  my $captchaCode = &$q->param("captcha", "");
  if ($captchaCode) {  # human confirmation
    my $humanCode = $q->param("human_code", "");
    if ($useCap) {
      my $captcha = Authen::Captcha->new(data_folder => $config->CaptchaDataDir,
                                         output_folder => $config->CaptchaOutputDir);
      my $result = $captcha->check_code($humanCode, $captchaCode);
      if ($result == -1) { # code expired
          $wikiTemplate->vars(&globalTemplateVars($request));
          $request->getHttpHeader();
          print $wikiTemplate->process('errors/captchaInvalid');
          return;
      }
      elsif ($result < 0) { # invalid code
          $wikiTemplate->vars(&globalTemplateVars($request));
          $request->getHttpHeader();
          print $wikiTemplate->process('errors/captchaInvalid');
          return;
      }
      elsif ($result == 0) { # file error
          $wikiTemplate->vars(&globalTemplateVars($request));
          $request->getHttpHeader();
          print $wikiTemplate->process('errors/captchaInvalid');
          return;
      }
    }
  }
  my $username = $q->param("p_username",  "");
  if ($username) {
      if ( (length($username) > 50) || # Too long
           ($userDb->idFromUsername($username)) ) {   # already used
          $wikiTemplate->vars(&globalTemplateVars($request),
                              userName => $username);
          $request->getHttpHeader();
          print $wikiTemplate->process('errors/usernameInvalid');
          return;
      }
      else {
          &DoNewLogin($user) if (!$user);  # should always be true
          $user->username($username);
      }
  }
  elsif (!$user) { # no username entered
      $wikiTemplate->vars(&globalTemplateVars($request),
                          userName => $username);
      $request->getHttpHeader();
      print $wikiTemplate->process('errors/usernameInvalid');
      return;
  }
  else {
      $username = $user->username;
  }

  my $password = $q->param("p_password");

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

  UpdatePrefNumber($request, "rcdays", 0, 0, 999999);
  UpdatePrefCheckbox($request, "rcnewtop");
  UpdatePrefCheckbox($request, "rcall");
  UpdatePrefCheckbox($request, "rcchangehist");
  UpdatePrefCheckbox($request, "editwide");

  if ($config->UseDiff) {
    UpdatePrefCheckbox($request, "norcdiff");
    UpdatePrefCheckbox($request, "diffrclink");
    UpdatePrefCheckbox($request, "alldiff");
    UpdatePrefNumber($request, "defaultdiff", 1, 1, 3);
  }

  UpdatePrefNumber($request, "rcshowedit", 1, 0, 2);
  UpdatePrefNumber($request, "tzoffset", 0, -999, 999);
  UpdatePrefNumber($request, "editrows", 1, 1, 999);
  UpdatePrefNumber($request, "editcols", 1, 1, 999);

  $TimeZoneOffset = GetParam("tzoffset", 0) * (60 * 60);

  $userDb->saveUser($user);
  $wikiTemplate->vars(&globalTemplateVars($request),
                      passwordRemoved => $passwordRemoved,
                      passwordChanged => $passwordChanged,
                      serverTime => &TimeToText(time-$TimeZoneOffset),
                      localTime => &TimeToText(time));
  $request->getHttpHeader();
  print $wikiTemplate->process('preferencesUpdated');
}

sub UpdatePrefCheckbox {
  my ($request, $param) = @_;
  my $user = $request->user();
  my $temp = $q->param("p_$param") || '*';

  $user->setField($param, 1)  if ($temp eq "on");
  $user->setField($param, 0)  if ($temp eq "*");
  # It is possible to skip updating by using another value, like "2"
}

sub UpdatePrefNumber {
  my ($request, $param, $integer, $min, $max) = @_;
  my $user = $request->user();
  my $temp = $q->param("p_$param") || '*';

  return  if ($temp eq "*");
  $temp =~ s/[^-\d\.]//g;
  $temp =~ s/\..*//  if ($integer);
  return  if ($temp eq "");
  return  if (($temp < $min) || ($temp > $max));
  $user->setField($param, $temp);
  # Later consider returning status?
}

# Create a new user file/cookie pair
# $user $userDb $session
#newlogin => doNewLogin
sub doNewLogin {
    my $request = shift;
    $request->user(undef);
    &doEditPrefs($request);  # Also creates new ID
}

sub DoNewLogin {
    my $request = shift;
    my $user = $request->user();
    my $session = $request->session();
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
    my $request = shift;
    # Later consider warning if cookie already exists
    # (maybe use "replace=1" parameter)
    my $user = $userDb->createUser;
    $request->user($user);
    $user->setField('rev', 1);
    $user->createTime(time);
    $user->createIp($ENV{REMOTE_ADDR});
    $userDb->saveUser($user);

    # go back to being a guest
    my $localId = $user->id;
    $user = undef;
    return $localId;
}

sub doEnterLogin {
    my $request = shift;
    my $context = $request->context();
    my $config = $context->{config};

    if ($config->LoginRedirect) {
      print 'Location: ' . $config->LoginRedirect . "\n\n";
      return;
    }
    my $q = $request->CGI();
    my $wikiTemplate = $context->{template};
    my $fromPage = $q->param("fromPage") || '';
    $wikiTemplate->vars(&globalTemplateVars($request),
                        fromPage => $fromPage);
    $request->getHttpHeader();
    print $wikiTemplate->process('login');
}

#  if (getParam("enter_login", 0)) {
#dologin => &doLogin,
sub doLogin {
  my $request = shift;
  my $q = $request->CGI(); 
  my $context = $request->context();
  my $userDb = $context->{user};
  my $config = $context->{config};
  my $wikiTemplate = $context->{template};
  my $success = 0;
  my $fromPage = &$q->param("fromPage", "");
  my $username = $q->param("p_username", "");
  my $password = $q->param("p_password",  "");
  $password = '' if ($password eq '*');

  my $userId = $userDb->idFromUsername($username);
  my $user = $userDb->loadUser($userId);
  if ($user && defined($user->getField('password')) &&
      ($user->getField('password') eq $password)) {
      $session->param('userId', $userId);
      $request->user($user);
      $success = 1;
  }
  else {
      $user = undef;
  }
  if ($success && $fromPage) {
      print 'Location: ' . $config->BaseURL . "?$fromPage\n\n";
  }
  else {
      $wikiTemplate->vars(&globalTemplateVars($request),
                          enteredName => $username,
                          loginSuccess => $success);
      $request->getHttpHeader();
      print $wikiTemplate->process('loginResults');
  }
}

#logout => &doLogout,
sub doLogout {
    my $request = shift;
    my $session = $request->session();
    my $context = $request->context();
    my $config = $context->{config};
    my $wikiTemplate = $context->{template};
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
    $wikiTemplate->vars(&globalTemplateVars($request),
                        userName => undef,
                        prevUserName => $user->username);
    $user = undef;
    print $header . $wikiTemplate->process('logout');
}

#getiname => !$user ? &doGetIname : error
sub doGetIname {
    my $request = shift;
    my $user = $request->user();
    my $config = $request->config();
    my $localId = &CreateNewUser($request) if (!$user);
    my $spname = $config->ServiceProviderName;
    my $spkey = $config->ServiceProviderKey;
    my $rtnUrl = $config->ReturnUrl;
    my $rsid = &Digest::MD5::md5_hex("$localId$spkey");
    print "Location: http://dev.idcommons.net/register.html?registry=$spname&local_id=$localId&rsid=$rsid&rtn=$rtnUrl\n\n";
}

#  $iname = &getParam("iname", "");
#  $localId = &getParam("local_id", "");
#  $rrsid = &getParam("rrsid", "");
#associateiname => &doAssociateIname,
sub doAssociateIname {
    my $request = shift;
    my ($iname, $localId, $rrsid)
        = ($request->{iname}, $request->{localid}, $request->{rrsid});

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
        }
        else {
            $wikiTemplate->vars(&globalTemplateVars($request));
            $request->getHttpHeader();
            print $wikiTemplate->process('errors/inameInvalid');
        }
    }
    else {
        if ($user) {
            print STDERR "NOT GUEST USER\n";
        }
        $wikiTemplate->vars(&globalTemplateVars($request));
        $request->getHttpHeader();
        print $wikiTemplate->process('errors/badInameRegistration');
    }
}

# user? Inames
# $iname = &getParam("xri_iname", "");
# $xsid = &getParam('xri_xsid', '');
# &DoNewLogin
#iname => &doIname,
sub doIname {
    my $request = shift;
    my $user = $request->user();
    my ($iname, $xsid) = ($request->{iname}, $request->{xsid});

    my $spit = XDI::SPIT->new;
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
                    &DoNewLogin($user);
                    $user->username($iname);
                    $userDb->saveUser($user);
                }
                # successful login message
                $wikiTemplate->vars(&globalTemplateVars($request),
                                    loginSuccess => 1);
                $request->getHttpHeader();
                print $wikiTemplate->process('loginResults');
            }
            else { # invalid xsid
                $wikiTemplate->vars(&globalTemplateVars($request));
                $request->getHttpHeader();
                print $wikiTemplate->process('errors/xsidInvalid');
            }
        }
        else {
            my $redirectUrl = $spit->getAuthUrl($idBroker, $iname, $config->ReturnUrl);
            print "Location: $redirectUrl\n\n";
        }
    }
    else { # i-name didn't resolve
        $wikiTemplate->vars(&globalTemplateVars($request));
        $request->getHttpHeader();
        print $wikiTemplate->process('errors/inameInvalid');
    }
}

1;
