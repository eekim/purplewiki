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

package PurpleWiki::Action::Search;

#Action/Search.pm
my %actions = ( dosearch => \&PurpleWiki::doSearch );

sub register {
  my $reqHandler = shift;

  for my $action (keys %actions) {
    $reqHandler->register($action, $actions{$action});
  }
}

package PurpleWiki;

# Search Action module
#  $search = getParam("search", "");
#  if (($search ne "") || (getParam("dosearch", "") ne "")) {
# &doIndex
#dosearch => &doSearch,
sub doSearch {
    my $request = shift;
    my $string = $request->{search};

    if (!$string) {
        my $indexMethod = $request->context()->{request}->action('index');
        &$indexMethod($request);
        return;
    }
    # do the new pluggable search
    my $search = new PurpleWiki::Search::Engine;
    $search->search($string);
#print STDERR "Search res:",scalar($search->results),"\n";

    $wikiTemplate->vars(&globalTemplateVars($request),
                        keywords => $string,
                        modules => $search->modules,
                        results => $search->results);
    $request->getHttpHeader();
    print $wikiTemplate->process('searchResults');
}

1;
