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

package PurpleWiki;

use strict;
use lib '/home/gerry/purple/blueoxen/branches/action-plugins';

my $useCap=0;
eval "use Authen::Captcha; $useCap=1;";
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

# debugging only
sub dumpParams {
  my $q = shift;
  my $F;
  open($F, ">>/tmp/form_log");
  print $F $q->url(-path_info=>1),"\n";
  $q->save($F);
  close $F;
}

##### Common support #####

sub preferredLanguages {
    my $request = shift;
    my $q = $request->CGI();
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
