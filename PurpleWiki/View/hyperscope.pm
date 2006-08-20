# PurpleWiki::View::hyperscope.pm
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2006.  All rights reserved.
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

package PurpleWiki::View::hyperscope;
use 5.005;
use strict;
use warnings;
use PurpleWiki::View::Driver;
use PurpleWiki::View::wikihtml;

############### Package Globals ###############

our $VERSION;
$VERSION = sprintf("%d", q$Id: xhtml.pm 366 2004-05-19 19:22:17Z eekim $ =~ /\s(\d+)\s/);

our @ISA = qw(PurpleWiki::View::Driver); 


############### Overloaded Methods ###############

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    $self->{locale} = PurpleWiki::Locale->new(@{$self->{languages}});
    ### Object State
    $self->{outputString} = "";
    $self->{pageName} = "";
    $self->{url} = $self->{url} || "";
    $self->{transcluder} = new PurpleWiki::Transclusion(
        url => $self->{url});

    # standard flag for determining whether or not a hard rule should
    # be printed
    $self->{isPrevSection} = 0;

    # special case flag for handling hard rules (or not) at the
    # beginning of a document
    $self->{isStart} = 1;
    $self->{emptyFirstSection} = 0;

    # used for determining whether there should be hard rules with
    # nested sections
    $self->{sectionDepth} = 0;
    $self->{depthLastClosedSection} = 0;

    bless($self, $class);
    return $self;
}

sub view {
    my ($self, $wikiTree) = @_;

    $self->SUPER::view($wikiTree);
    $self->{outputString} = $self->_opmlHeader($wikiTree) .
                            $self->{outputString} . $self->_opmlFooter();

    return $self->{outputString};
}


############### Private Methods ###############

sub _opmlHeader {
    my ($self, $wikiTree) = @_;
    my $outputString;

    $outputString = qq(<?xml version="1.0" encoding="UTF-8"?>\n) .
       qq(<?xml-stylesheet type="text/xsl" href="/hyperscope/src/client/lib/hs/xslt/hyperscope.xsl"?>\n) .
       qq(<opml xmlns:hs="http://www.hyperscope.org/hyperscope/opml/public/2006/05/09" hs:version="1.0" version="2.0">) .
       qq(<head>\n);
    $outputString .= '<title>' . $wikiTree->title . "</title>\n"
        if ($wikiTree->title);
    $outputString .= '<title>' . $wikiTree->title . "</title>\n"
        if ($wikiTree->title);

    $outputString .= "</head>\n<body>\n";
    if ($wikiTree->title) {
        $outputString .= '<outline text="';
        $outputString .= $wikiTree->title;
        $outputString .= '">' . "\n";
    }

    return $outputString;
}

sub _opmlFooter {
    return "</outline>\n</body>\n</opml>\n";
}
1;
__END__

=head1 NAME

PurpleWiki::View::hyperscope - View Driver used for HyperScope output.

=head1 DESCRIPTION

Converts a PurpleWiki::Tree into HyperScope format (OPML + optional
special attributes).

=head1 METHODS

=head2 new(url => $url, pageName => $pageName, css_file => $CSS)

Returns a new PurpleWiki::View::xhtml object.

url is the URL prepended to NIDs, defaults to the empty string. 

pageName is the pageName used by sketch nodes for the SVG stuff, it defaults
to the empty string.

css_file is the name of the CSS file to use, defaults to the empty string.

=head2 view($wikiTree)

Returns the output as a string of valid XHTML.

=head1 AUTHORS

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::View::Driver>, L<PurpleWiki::View::wikihtml>

=cut
