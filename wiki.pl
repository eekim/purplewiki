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
use lib '/home/eekim/devel/PurpleWiki/branches/database-api-1';
use strict;
my $useCap=0;
eval "use Authen::Captcha; $useCap=1;";
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use PurpleWiki::Config;
use PurpleWiki::Session;

my $CONFIG_DIR = $ENV{PW_CONFIG_DIR} || '/home/gerry/purple/testdb';

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

local $| = 1;  # Do not buffer output (localized for mod_perl)

my $InterSiteInit = 0;
my %InterSite;
my $user;               # our reference to the logged in user
my $visitedPagesCache;
my $visitedPagesCacheSize = 7;

my $q;                  # CGI query reference

# we only need one of each these per run
my $config = new PurpleWiki::Config($CONFIG_DIR);
my $context = {};
$context{config} = $config;

my @modules = qw( wikiparser pages userdb template request acl spit search );
my %modules = $config->Module;
my @loaderror = ();

for my $module (@modules) {
    loadModule($modules{$module});
}

for my $module (keys %modules) {
    loadModule($modules{$module}) unless ($context{$module});
}

sub loadModule {
    my $class = shift;
    return unless $class;
    eval "require $class";
    if ($@) {
        push(@$loadErrors, "Error $@ loading $class for $module\n");
        next;
    }
    $class .= 's' if ($module eq 'pages' && substr($class,-1,1) ne 's');
    unless ($context{$module} = $class->new($config)) {
        push(@loaderror, "Error loading $class for $module");
    }
}

#my $wikiParser = $context{wikiparser};
#my $wikiTemplate = $context{template};
my $userDb = $context{userdb};
#my $acl = $context{acl};

# Set our umask if one was put in the config file. - matthew
umask(oct($config->Umask)) if defined $config->Umask;

sub DoCommandRequest {
    my $request = InitCommandRequest();
    my $action = $request->action() || 'browse';
    my $actionClass = $config->Action->{$action};
    $actionClass->$action($request) if ($actionClass);
    &logSession($request);
}

sub InitCommandRequst {
    if (@loaderror) {
        print STDERR join("\n",@loaderror),"\n";
        die "Error initializing modules";
    }
    my $request = $context->{request}->parseRequest($context, argv => \@ARGV);
    $request->{tzoffset} = 0;
}

sub DoCGIRequest {
    my $request = InitCGIRequest();
    my $action = $request->action() || 'browse';
    my $actionClass = $config->Action->{$action};
    if ($actionClass) {
        $actionClass->$action($request);
    }
    &logSession($request);
}

sub InitCGIRequest {
    my $q = new CGI;
    if (@loaderror) {
        $context->{template}->vars(&globalTemplateVars, error => \@loaderror);
        print GetHttpHeader($q), $context->{template}->process('errors/internalError');
        return 0;
    }
    my $request = $context->{request}->parseRequest($context, cgi => $q);
    $request->{tzoffset} = 0;
    undef $q->{'.cookies'};  # Clear cache if it exists (for SpeedyCGI)

    my $sid = ($config->CookieName) ? $q->cookie($config->CookieName)
                                    : $q->cookie($config->SiteName);
    $session = PurpleWiki::Session->new($sid);
    my $userId = $session->param('userId');
    $request->{user} = $userDb->loadUser($userId) if ($userId);
    $session->clear(['userId']) if (!$user);
    $request->session($session);

    if ($user && $user->tzOffset != 0) {
        $request->{tzoffset} = $user->tzOffset * (60 * 60);
    }

    $visitedPagesCache = $session->param('visitedPagesCache') || {};
}

sub dumpParams {
  my $q = shift;
  my $F;
  open($F, ">>/tmp/form_log");
  print $F $q->url(-path_info=>1),"\n";
  $q->save($F);
  close $F;
}

sub parseRequest {
  my ($context) = shift;
  my %args = @_;
  my ($id, $action, $text, $urlPage);

  if ($urlPage = (!$req->param) ? $self->{homepage}
                                : $self->getParam($req, 'keywords', '')) {
    $self->{urlPage} = $urlPage;
    $id = $self->getId();
    $page = $self->{pages}->newPageId($id);
    $self->{page} =
    BrowsePage($page, $id)  if ValidIdOrDie($id);
    return 1;
  }
                            
  $self->{action} = lc(GetParam('action', ''));
  $self->{id} = GetParam('id', $config->HomePage);
  $self->{revision} = $request->revision();
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

sub logSession {
    my $request = shift;
    my $q = $request->CGI();
    open FH, ">>$CONFIG_DIR/session_log";
    print FH time, "\t", $request->session->id, "\t", $q->request_method, "\t";
    print FH $q->query_string if ($q->request_method ne 'POST');
    print FH "\t", $q->remote_host, "\t", $request->session->param('userId'),
             "\t",  $q->referer . "\n";
    close FH;
}

sub updateVisitedPagesCache {
    my $id = shift;

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

my $is_require = (caller($_))[7];
&DoCGIRequest()  if (!$is_require && $config->RunCGI && $ENV{SCRIPT_NAME} && $q = CGI new);
&DoCommandRequest() if (!$is_require && @ARGV);

1;
