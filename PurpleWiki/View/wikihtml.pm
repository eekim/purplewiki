# PurpleWiki::View::wikihtml.pm
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2004.  All rights reserved.
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

package PurpleWiki::View::wikihtml;
use 5.005;
use strict;
use warnings;
use PurpleWiki::Transclusion;
use PurpleWiki::View::Driver;

############### Package Globals ###############

our $VERSION = '0.9.1';

our @ISA = qw(PurpleWiki::View::Driver);


############### Overloaded Methods ###############

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    # Object State
    $self->{outputString} = "";
    $self->{pageName} = "";
    $self->{sectionState} = [];
    $self->{url} = $self->{url} || "";
    $self->{transcluder} = new PurpleWiki::Transclusion(
        config => $self->{config},
        url => $self->{url});

    bless($self, $class);
    return $self;
}

sub view {
    my ($self, $wikiTree) = @_;
    $self->{sectionState} = [];
    $self->SUPER::view($wikiTree);
    return $self->{outputString};
}

sub sectionPre { 
    push @{shift->{sectionState}}, 'section'; 
}

sub sectionPost { 
    pop @{shift->{sectionState}}; 
}

sub indentPre { 
    shift->{outputString} .= "<div class=\"indent\">\n";
}

sub indentPost { 
    shift->{outputString} .= "</div>\n";
}

sub ulPre { shift->{outputString} .= '<' . shift->type . '>' }
sub olPre { shift->{outputString} .= '<' . shift->type . '>' }
sub dlPre { shift->{outputString} .= '<' . shift->type . '>' }
sub bPre { shift->{outputString} .= '<' . shift->type . '>' }
sub iPre { shift->{outputString} .= '<' . shift->type . '>' }
sub ttPre { shift->{outputString} .= '<' . shift->type . '>' }

sub ulPost { shift->{outputString} .= '</' . shift->type . ">\n" }
sub olPost { shift->{outputString} .= '</' . shift->type . ">\n" }
sub dlPost { shift->{outputString} .= '</' . shift->type . ">\n" }

sub hPre { 
    my ($self, $node) = @_;
    $self->{outputString} .= '<h' . $self->_headerLevel(); 
    $self->{outputString} .= '>' . $self->_anchor($node->id); 
}

sub hPost { 
    my ($self, $node) = @_; 
    $self->{outputString} .= $self->_nid($node->id); 
    $self->{outputString} .= '</h' . $self->_headerLevel() . '>';
}

sub pPre { shift->_openTagWithNID(@_) }
sub liPre { shift->_openTagWithNID(@_) }
sub ddPre { shift->_openTagWithNID(@_) }
sub dtPre { shift->_openTagWithNID(@_) }
sub prePre { shift->_openTagWithNID(@_) }

sub pPost { shift->_closeTagWithNID(@_) }
sub liPost { shift->_closeTagWithNID(@_) }
sub ddPost { shift->_closeTagWithNID(@_) }
sub dtPost { shift->_closeTagWithNID(@_) }
sub prePost { shift->_closeTagWithNID(@_) }

sub sketchMain { 
    my $self = shift;

    $self->{outputString} .= q{<form name="SvgForm" action="/cgi-bin/wikiwhiteboard.pl" method="POST" onsubmit="frm=document.forms['SvgForm'];frm.svg.value= window.getSVG(); return true;">} . "\n" .
        '<input type="submit" value="Save" />' . "\n" .
        '<input type="hidden" name="pageName" value="' . $self->{pageName} .
        '" />' . "\n" .
        '<input type="hidden" name="svg" value="" />' . "\n" .
        '<input type="submit" name="submit" value="Clear" />' . "\n" .
        "</form>\n" .
        '<embed src="/cgi-bin/wikiwhiteboard.pl?' . $self->{pageName} .
        '" width="500" height="300" pluginspage="http://www.adobe.com/svg/viewer/install" />' . "\n";
}

sub bPost { shift->{outputString} .= '</' . shift->type . '>' }
sub iPost { shift->{outputString} .= '</' . shift->type . '>' }
sub ttPost { shift->{outputString} .= '</' . shift->type . '>' }

sub textMain { shift->_quoteHtml(@_) }
sub nowikiMain { shift->_quoteHtml(@_) }
sub linkMain { shift->_quoteHtml(@_) }
sub urlMain { shift->_quoteHtml(@_) }

sub imageMain { shift->{outputString} .= '<img src="' . shift->href . '" />' }

sub transclusionMain { 
    my ($self, $nodeRef) = @_;
    my $transcluded = $self->{transcluder}->get($nodeRef->content);
    if (ref($transcluded)) {
        my $node = new PurpleWiki::InlineNode(
            type => 'link',
            class => 'nid',
            href => $self->{transcluder}->getURL($nodeRef->content) .
                '#nid' . $nodeRef->content,
            content => 'T');
        my $textNode = new PurpleWiki::InlineNode(
            type => 'text',
            content => '&nbsp;');
        $transcluded->content([@{$transcluded->content}, $textNode, $node]);
        $self->traverse($transcluded->content);
    } else {
        $self->{outputString} .= $transcluded;
    }
}

sub linkPre { shift->_openLinkTag(@_) }
sub urlPre { shift->_openLinkTag(@_) }

sub linkPost { shift->{outputString} .= '</a>' }
sub urlPost { shift->{outputString} .= '</a>' }

sub freelinkMain { shift->_wikiLink(@_) }
sub wikiwordMain { shift->_wikiLink(@_) }


############### Private Methods ###############

sub _openTagWithNID {
    my ($self, $nodeRef) = @_;
    $self->{outputString} .= '<'.$nodeRef->type.'>';
    $self->{outputString} .= $self->_anchor($nodeRef->id);
}

sub _closeTagWithNID {
    my ($self, $nodeRef) = @_;
    $self->{outputString} .= $self->_nid($nodeRef->id);
    $self->{outputString} .= '</' . $nodeRef->type . '>';
}

sub _openLinkTag { 
    my ($self, $nodeRef) = @_;
    my $class = $nodeRef->class || 'extlink';
    $self->{outputString} .= '<a class="' . $class . '" href="';
    $self->{outputString} .= $_[1]->href . '">';
}

sub _wikiLink {
    my ($self, $nodeRef) = @_;
    my $pageName = $nodeRef->content;
    my $linkString = "";
    my $pageNid;

    if ($pageName =~ s/\#([A-Z0-9]+)$//) {
        $pageNid = $1;
    }

    if ($nodeRef->content =~ /:/) {
        $linkString .= '<a href="' .
            &PurpleWiki::Page::getInterWikiLink($pageName, $self->{config});
        $linkString .= "#nid$pageNid" if $pageNid;
        $linkString .= '">' . $nodeRef->content . '</a>';
    } elsif (&PurpleWiki::Page::exists($pageName, $self->{config})) {
        if ($nodeRef->type eq 'freelink') {
            $linkString .= '<a href="' .  
            &PurpleWiki::Page::getFreeLink($nodeRef->content, 
                $self->{config}) .  '">';
        } else {
            $linkString .= '<a href="' . 
            &PurpleWiki::Page::getWikiWordLink($pageName, $self->{config});
            $linkString .= "#nid$pageNid" if $pageNid;
            $linkString .= '">';
        }
        $linkString .= $nodeRef->content . '</a>';
    } else {
        if ($nodeRef->type eq 'freelink') {
            $linkString .= '[' . $nodeRef->content . ']';
            $linkString .= '<a href="' .
                &PurpleWiki::Page::getFreeLink($nodeRef->content, 
                    $self->{config}) .  '">';
        } else {
            $linkString .= $nodeRef->content;
            $linkString .= '<a href="' .
                &PurpleWiki::Page::getWikiWordLink($pageName, $self->{config}) .
                    '">';
        }
        $linkString .= '?</a>';
    }

    $self->{outputString} .= $linkString;
}

sub _quoteHtml {
    my ($self, $nodeRef) = @_;
    my $html = $nodeRef->content;

    $html =~ s/&/&amp;/g;
    $html =~ s/</&lt;/g;
    $html =~ s/>/&gt;/g;

    if (1) {   # Make an official option?
        $html =~ s/&amp;([#a-zA-Z0-9]+);/&$1;/g;  # Allow character references
    }

    $self->{outputString} .= $html;
}

sub _headerLevel {
    my $self = shift;
    my $headerLevel = scalar @{$self->{sectionState}} + 1;

    $headerLevel = 6 if $headerLevel > 6;
    return $headerLevel;
}

# FIXME: goes to too much effort to avoid a void return
sub _anchor {
    my ($self, $nid) = @_;
    my $string = '';

    if ($nid) {
        $string = '<a name="nid' . $nid . '" id="nid' . $nid . '"></a>';
    }

    return $string;
}

# FIXME: goes to too much effort to avoid a void return
sub _nid {
    my ($self, $nid) = @_;
    my $string = '';

    my $nidFace = '#';

    if ($self->{config}->ShowNid) {
        $nidFace = $nid;
    }

    if ($nid) {
        $string = ' &nbsp;&nbsp; <a class="nid" ' .
            'title="' . "$nid" . '" href="' .
            $self->{url} . '#nid' .
            $nid . '">' . $nidFace . '</a>';
    }

    return $string;
}
1;
__END__

=head1 NAME

PurpleWiki::View::wikihtml - View Driver used for HTML output.

=head1 DESCRIPTION

Converts a PurpleWiki::Tree into HTML.  The HTML should be XHTML compliant,
but it isn't proper XHTML since no header or footer information is attached.
The HTML returned here would be stuffed in the <body> section of an XHTML
document.

=head1 OBJECT STATE

=head2 outputString 

This contains the current working copy of the text that is ultimately returned
by view().

=head1 METHODS

=head2 new(url => $url, pageName => $pageName)

Returns a new PurpleWiki::View::wikihtml object.

url is the URL prepended to NIDs, defaults to the empty string. 

pageName is the pageName used by sketch nodes for the SVG stuff, it defaults
to the empty string.

=head2 view($wikiTree)

Returns the output as a string of sub-compliant XHTML text.  The output can 
be made XHTML compliant if stuffed into the <body> section of a compliant
XHTML document.

=head1 AUTHORS

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::View::Driver>

=cut
