# PurpleWiki::Apache2Handler.pm
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

package PurpleWiki::Apache2Handler;

use strict;
use IO::File;
use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Template::TT;
use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::URI;
use Apache::Const -compile => qw(OK);

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

my $CONFIG = '/home/cdent/wikidb';

sub handler {
    my $r = shift;

    $r->content_type('text/html');

    my $file = $r->filename();
    my $url = $r->construct_url();

    my $content = readFile($file);
    my $purpleConfig = new PurpleWiki::Config($CONFIG);
    my $wikiParser = new PurpleWiki::Parser::WikiText();
    my $wiki = $wikiParser->parse($content, 
        wikiword => 1,
        url => $url,
    );
    my $wikiTemplate = new PurpleWiki::Template::TT(
        templateDir => "$CONFIG/templates");
    $wikiTemplate->vars( body => $wiki->view('wikihtml', 
                                             wikiword => 1,
                                             url => $url),
                         title => $wiki->title,
                         date => $wiki->date );
    print $wikiTemplate->process('handler');
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

A simple display handler for web content files that are formatted as
PurpleWiki wikitext. The handler reads in the *.wiki file, parses it
to a PurpleWiki::Tree and presents it using the template defined in
wikidb/templates/handler.tt.

=head1 METHODS

=head2 handler()

The default method for a mod_perl handler.

=head1 BUGS

When an error condition occurs, such as a file not found, an HTTP
200 OK is still returned.

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=cut
