# PurpleWiki::Apache2NidHandler.pm
# vi:ai:sw=4:ts=4:et:sm
#
# $Id$
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

package PurpleWiki::Apache2NidHandler;

use strict;
use PurpleWiki::Config;
use PurpleWiki::Sequence;
use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::URI;
use Apache::Const -compile => qw(OK);

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

my $CONFIG = '/home/cdent/testpurple';

sub handler {
    my $r = shift;
    my $pathInfo;
    my $queryString = ''; 
    my $count;
    my $url;
    my $nid;

    my $purpleConfig = new PurpleWiki::Config($CONFIG);

    $r->content_type('text/plain');

    $queryString = $r->args();
    $pathInfo = $r->path_info();
    $pathInfo =~ s/^\///;
    ($count, $url) = split('/', $pathInfo, 2);

    # put the double slash back in the url after the protocol
    # FIXME: do encoding of the passed url?
    $url =~ s/^(\w+:\/)(?!\/)/$1\//;

    $queryString = '?' . $queryString if length($queryString);

    if (!defined($url)) {
        $nid = $count;
        _getURL($purpleConfig, $nid);
    } else {
        $count = 1 if (!length($count));
        _getNIDs($purpleConfig, $count, "$url$queryString");
    }

    # FIXME: sometimes okay is not the desired return code
    return Apache::OK;

}

sub _getURL {
    my $purpleConfig = shift;
    my $nid = shift;

    # never pass remote sequence here, or you just get a big mess
    my $sequence = new PurpleWiki::Sequence($purpleConfig->DataDir());

    print $sequence->getURL($nid);
}

sub _getNIDs {
    my $purpleConfig = shift;
    my $count = shift;
    my $url = shift;

    my $sequence = new PurpleWiki::Sequence($purpleConfig->DataDir());

    while ($count-- > 0) {
        print $sequence->getNext($url), "\n";
    }
}



1;


__END__

=head1 NAME

PurpleWiki::Apache2NidHandler - Remote NID handling for mod_perl 2

=head1 SYNOPSIS

  in httpd.conf:


=head1 DESCRIPTION


=head1 METHODS

=head2 handler()

The default method for a mod_perl handler.

=head1 BUGS

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=cut
