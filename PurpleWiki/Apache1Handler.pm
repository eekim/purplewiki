# PurpleWiki::Apache1Handler.pm
# vi:ai:sw=4:ts=4:et:sm
#
# $Id: Apache1Handler.pm,v 1.1 2004/01/24 02:30:22 cdent Exp $
#

package PurpleWiki::Apache1Handler;

use lib '/home/cjdent/src/PurpleWiki/';
use strict;
use IO::File;
use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;
use Apache;
use Apache::Constants;
use Apache::URI;

my $CONFIG = '/home/kb-dev/wikidata';
my $CSS = '/css/purple.css';

sub handler {
    my $r = shift;

    print $r->send_http_header("text/html"); 

    my $file = $r->filename();
    my $url = Apache::URI->parse($r)->unparse();

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

    return OK;

}

sub readFile {
    my $file = shift;

    my $fh = new IO::File();
    $fh->open($file) || die "unable to open $file: $!";
    return join('', $fh->getlines);
}



1;
