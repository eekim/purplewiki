#!/usr/bin/perl
#
# wikiwhiteboard.pl -- perl port of Danny Ayers's WikiWhiteboard
#
# $Id: wikiwhiteboard.pl,v 1.2 2003/08/29 18:45:13 eekim Exp $
#
# Copyright (c) Blue Oxen Associates 2003.  All rights reserved.
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

use CGI;
use IO::File;

my $configDir = '/home/eekim/www/local/wikidb';
my $uriBase = 'http://purplewiki.blueoxen.net/cgi-bin/wiki.pl?';

my $q = new CGI;

if ($q->keywords) {
    my @pages = $q->keywords;
    my $pageName = $pages[0];
    my $filename = "$configDir/wikiwhiteboard/$pageName.svg";

    if (!-e $filename) {
        $filename = "$configDir/sketch.svg";
    }
    my $fileContent;
    my $fh = new IO::File $filename;
    if ($fh) {
        undef $/;
        $fileContent = <$fh>;
        $fh->close;
    }
    print $q->header(-type=>'image/svg+xml') . $fileContent;
}
elsif (!$q->param) {
    print $q->header . $q->start_html('Error: No file specified') .
        $q->h1('Error: No file specified') . $q->end_html;
}
else {
    $pageName = $q->param('pageName');
    my $svgData = $q->param('svg');
    my $submit = $q->param('submit');

    my $filename = "$configDir/wikiwhiteboard/$pageName.svg";

    if ($submit eq 'Clear') {
        unlink $filename;
    }
    else {
        my $fh = new IO::File ">$filename";
        if ($fh) {
            print $fh $svgData;
            $fh->close;
        }
    }

    print $q->redirect("$uriBase$pageName");
}
