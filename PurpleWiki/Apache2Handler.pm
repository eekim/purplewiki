# PurpleWiki::Apache2Handler.pm
# vi:ai:sw=4:ts=4:et:sm
#
# $Id: Apache2Handler.pm,v 1.3 2004/02/12 18:58:35 cdent Exp $
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

package PurpleWiki::Apache2Handler;

use strict;
use lib '/home/cdent/src/PurpleWiki';
use IO::File;
use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;
use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::URI;
use Apache::Const -compile => qw(OK);
use vars qw($VERSION);
$VERSION = '0.9.1';

my $CONFIG = '/home/cdent/testpurple';
my $CSS = '/~cdent/purple.css';

sub handler {
    my $r = shift;

    $r->content_type('text/html');

    my $file = $r->filename();
    my $url = $r->construct_url();

    my $content = readFile($file);
    my $purpleConfig = new PurpleWiki::Config($CONFIG);
    my $wikiParser = new PurpleWiki::Parser::WikiText();
    my $wiki = $wikiParser->parse($content, 
        config => $purpleConfig,
        wikiword => 1,
        css_file => $CSS,
        url => $url,
    );

    print $wiki->view('xhtml', 
        config => $purpleConfig,
        wikiword => 1,
        css_file => $CSS,
        url => $url,
    );

    # FIXME: sometimes okay is not the desired return code
    return Apache::OK;

}

sub readFile {
    my $file = shift;
    my $fileContent = '';

    my $fh = new IO::File();
    $fh->open($file) || die "unable to open $file: $!";
    return join('', $fh->getlines);
}



1;


__END__

=head1 NAME

PurpleWiki::Apache2Handler - Wiki text display handler for mod_perl 2

=head1 SYNOPSIS

  in httpd.conf:

  PerlRequire /path/to/PurpleWiki/Apache2Handler.pm
  <FilesMatch *\.wiki>
      SetHandler perl-script
      PerlResponseHandler  PurpleWiki::Apache2Handler
  </FilesMatch>

=head1 DESCRIPTION

A simple display handler for web content files that are formatted
as PurpleWiki wikitext. The handler reads in the *.wiki file, parses
it to a PurpleWiki::Tree and presents it as PurpleWiki::View::xhtml.

=head1 METHODS

=head2 handler()

The default method for a mod_perl handler.

=head1 BUGS

When an error condition occurs, such as a file not found, an HTTP
200 OK is still returned.

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=cut
