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

package PurpleWiki::Action::Unlock;

#Action/User.pm
my %actions = ( unlock => \&PurpleWiki::doUnlock );

sub register {
  my $reqHandler = shift;

  for my $action (keys %actions) {
    $reqHandler->register($action, $actions{$action});
  }
}

package PurpleWiki;

#Action/Unlock.pm
# } elsif ($action eq "unlock") {
#unlock => &doUnlock,
sub doUnlock {
    my $request = shift;
unless ($request) {
use Carp;
&Carp::confess();
}
    my $context = $request->context();
    my $archive = $context->{archive};
    my $wikiTemplate = $context->{template};
    my $forcedUnlock = 0;

    if ($archive->forceReleaseLock('main', $config)) {
        $forcedUnlock = 1;
    }
    $wikiTemplate->vars(globalTemplateVars($request),
                        forcedUnlock => $forcedUnlock);
    $request->getHttpHeader();
    print $wikiTemplate->process('removeEditLock');
}

1;
