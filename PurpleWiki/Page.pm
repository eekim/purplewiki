# PurpleWiki::Page.pm
#
# $Id: Page.pm,v 1.6 2002/11/24 07:21:42 eekim Exp $
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

package PurpleWiki::Page;

# mappings between PurpleWiki code and code withing useMod

# $Id: Page.pm,v 1.6 2002/11/24 07:21:42 eekim Exp $

sub exists {
    my $id = shift;

    if (defined &UseModWiki::pageExists) {
        (defined &UseModWiki::pageExists($id)) ? return 1 : return 0;
    }
    else {
        return 0;
    }
}

sub siteExists {
    my $site = shift;

    if (defined &UseModWiki::GetSiteUrl) {
        (defined &UseModWiki::GetSiteUrl($site)) ? return 1 : return 0;
    }
    else {
        return 0;
    }
}

sub getWikiWordLink {
    my $id = shift;

    my $results;
    if (defined &UseModWiki::GetPageOrEditLink) {
        $results = &UseModWiki::GetPageOrEditLink($id, '');
    }
    return _makeURL($results);
}

sub getInterWikiLink {
    my $id = shift;
    
    my $results;
    if (defined &UseModWiki::InterPageLink) {
        $results = (&UseModWiki::InterPageLink($id, ''))[0];
    }
    return _makeURL($results);
}

sub getFreeLink {
    my $id = shift;

    my $results;
    if (defined &UseModWiki::GetPageOrEditLink) {
        $results = (&UseModWiki::GetPageOrEditLink($id, ''))[0];
    }
    return _makeURL($results);
}

                  

sub _makeURL {
    my $string = shift;
    return ($string =~ /\"([^\"]+)\"/)[0];
}

1;
