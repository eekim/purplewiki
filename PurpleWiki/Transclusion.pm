# PurpleWiki::Transclusion.pm
# vi:ai:sw=4:ts=4:et:sm
#
# $Id: Transclusion.pm,v 1.1.2.1 2003/05/21 08:47:27 cdent Exp $
#
# Copyright (c) Blue Oxen Associates 2002-2003.  All rights reserved.
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

package PurpleWiki::Transclusion;

use strict;
# FIXME: instead of using hardcode variables (below)
# get stuff out of the PurpleWiki::Config
#use PurpleWiki::Config;
use DB_File;
use LWP::UserAgent;

# A first stab at transclusions in PurpleWiki. This is an
# extremely rudimentary prototype. It is not meant to be 
# good by any stretch of the imagination. It is simply to
# demonstrate the possibilities that these features allow.

# $Id: Transclusion.pm,v 1.1.2.1 2003/05/21 08:47:27 cdent Exp $

my $INDEX_FILE='/home/cdent/testpurple/sequence.index';
my $BASE = 'http://www.burningchrome.com:8000';


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless ($self, $class);
    my %params = @_; # FIXME: not yet used

    $self->_tieHash();

    return $self;
}

sub get {
    my $self = shift;
    my $nid = shift;
    my $nidLong = "nid0$nid";

    my $url = $self->{db}->{$nid}; # Uh?

    my $ua = new LWP::UserAgent();
    my $request = new HTTP::Request('GET', $url);
    my $result = $ua->request($request);
    
    my $content;
    if ($result->is_success()) {
        $content = $result->content();
        $content =~ s/^.*<a name="$nidLong"[^>]+><\/a>//is;
        $content =~ s/&nbsp;&nbsp;\s*<a class="nid" title="0$nid".*$//is;
    } else {
        $content = "unable to retrieve content";
    }

    $content = qq(<span id="$nidLong" class="transclusion">) .
               qq($content&nbsp;<a class="nid" title="0$nid" ) .
               qq(href="$url#$nidLong">T</a></span>);


    return $content;
}

sub _tieHash {
    my $self = shift;

    tie %{$self->{db}}, 'DB_File', $INDEX_FILE, O_RDONLY, 0644, $DB_HASH ||
        die "unable to tie $INDEX_FILE: $!";
}



