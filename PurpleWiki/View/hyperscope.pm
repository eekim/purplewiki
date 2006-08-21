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
use Carp;
use PurpleWiki::View::Driver;
use PurpleWiki::View::wikihtml;

############### Package Globals ###############

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

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

sub sectionPre { 
    my $self = shift;
    $self->{sectionDepth}++;
    $self->_hardRule(1);
    $self->{isPrevSection} = 1;
}

sub sectionPost { 
    my $self = shift;
    $self->{depthLastClosedSection} = $self->{sectionDepth};
    $self->{sectionDepth}--;
    $self->{emptyFirstSection} = 1
        if ($self->{isStart} && $self->{isPrevSection});
    $self->_hardRule(0);
    $self->{isStart} = 0;

    $self->{outputString} .= "</outline>\n" unless $self->{emptyFirstSection};
}

sub indentPre { 
    my $self = shift;
    $self->_hardRule(0);
    $self->{outputString} .= "<outline>\n";
}

sub indentPost { 
    shift->{outputString} .= "</outline>\n";
}

sub ulPre { 
    my $self = shift;
    $self->_hardRule(0);
    $self->{outputString} .= "<outline>\n";
}

sub ulPost { 
    shift->{outputString} .= "</outline>\n";
}

sub olPre { 
    my $self = shift;
    $self->_hardRule(0);
    $self->{outputString} .= "<outline>\n";
}

sub olPost { 
    shift->{outputString} .= "</outline>\n";
}

sub dlPre { 
    my $self = shift;
    $self->_hardRule(0);
    $self->{outputString} .= "<outline>\n";
}

sub dlPost { 
    shift->{outputString} .= "</outline>\n";
}

sub liPre {
  my ($self, $node) = @_;

  $self->{outputString} .= '<outline hs:nid="' . $node->id . '" text="* ';
}

sub liMain { shift->_liRecurse(@_) }
sub ddMain { shift->_liRecurse(@_) }

sub liPost {
  shift->{outputString} .= "</outline>\n";
}

sub dtPre {
  my ($self, $node) = @_;

  $self->{outputString} .= '<outline hs:nid="' . $node->id . '" text="* ';
}

sub dtPost {
  shift->{outputString} .= "</outline>\n";
}

sub ddPre {
  my ($self, $node) = @_;

  $self->{outputString} .= '<outline hs:nid="' . $node->id . '" text="* ';
}

sub ddPost {
  shift->{outputString} .= "</outline>\n";
}

sub hPre { 
    my ($self, $node) = @_;
    if ($self->{emptyFirstSection}) {
        $self->{isPrevSection} = 1;
        $self->{emptyFirstSection} = 0;
        $self->_hardRule(0);
    }
    else {
        $self->{isPrevSection} = 0;
    }
    $self->{outputString} .= '<outline hs:nid="0' . $node->id . '" text="';
    $self->{outputString} .= '&lt;h' . $self->_headerLevel . '&gt;'; 
}

sub hPost { 
    my ($self, $node) = @_; 
    $self->{outputString} .= '&lt;/h' . $self->_headerLevel . '&gt;"';
    $self->{outputString} .= ">\n";
}

sub pPre {
    my ($self, $node) = @_;

    $self->_hardRule(0);
    $self->_openTagWithNID($node);
}

sub pPost { shift->_closeTagWithNID(@_) }

sub prePre {
    my ($self, $node) = @_;

    $self->_hardRule(0);
    $self->_openTagWithNID($node);
}

sub prePost { shift->_closeTagWithNID(@_) }

sub bPre { shift->{outputString} .= '&lt;' . shift->type . '&gt;' }
sub iPre { shift->{outputString} .= '&lt;' . shift->type . '&gt;' }
sub ttPre { shift->{outputString} .= '&lt;' . shift->type . '&gt;' }

sub bPost { shift->{outputString} .= '&lt;/' . shift->type . '&gt;' }
sub iPost { shift->{outputString} .= '&lt;/' . shift->type . '&gt;' }
sub ttPost { shift->{outputString} .= '&lt;/' . shift->type . '&gt;' }

sub textMain { shift->_quoteHtml(@_) }
sub nowikiMain { shift->_quoteHtml(@_) }
sub linkMain { shift->_quoteHtml(@_) }
sub urlMain { shift->_quoteHtml(@_) }

sub imageMain {
    my ($self, $nodeRef) = @_;
    my $href = $nodeRef->href;
    $self->{outputString} .= '&lt;img alt="' . $href .
        '" src="' .  $href . '" /&gt;';
}

sub freelinkMain { shift->_wikiLink(@_) }
sub wikiwordMain { shift->_wikiLink(@_) }

############### Private Methods ###############

sub _hardRule {
  my ($self, $isSection) = @_;

  if ($self->{isPrevSection}) {
    if ($self->{isStart}) {
      if ($isSection) {
        $self->{outputString} .= "<outline>\n";
      }
      elsif ($self->{sectionDepth} == $self->{depthLastClosedSection} + 1) {
        $self->{outputString} .= "<outline>\n";
      }      
    }
    else {
      if (!$isSection || ($isSection &&
          $self->{sectionDepth} == $self->{depthLastClosedSection} + 1) ) {
        $self->{outputString} .= '<outline text="&lt;hr /&gt;">' . "\n";
      }
    }
    $self->{isPrevSection} = 0;
  }
}

sub _opmlHeader {
    my ($self, $wikiTree) = @_;
    my $outputString;

    $outputString = qq(<?xml version="1.0" encoding="UTF-8"?>\n) .
       qq(<?xml-stylesheet type="text/xsl" href="/hyperscope/src/client/lib/hs/xslt/hyperscope.xsl"?>\n) .
       qq(<opml xmlns:hs="http://www.hyperscope.org/hyperscope/opml/public/2006/05/09" hs:version="1.0" version="2.0">) .
       qq(<head>\n);
    $outputString .= '<title>' . $wikiTree->title . "</title>\n"
        if ($wikiTree->title);

    $outputString .= "</head>\n<body>\n";

    # assume $wikiTree->title; otherwise, OPML will be imbalanced
    $outputString .= '<outline text="';
    $outputString .= $wikiTree->title;
    $outputString .= '">' . "\n";

    return $outputString;
}

sub _opmlFooter {
    return "</outline>\n</body>\n</opml>\n";
}

sub _headerLevel {
    my $self = shift;
    my $headerLevel = $self->{sectionDepth};

    $headerLevel = 6 if ($headerLevel > 6);
    return $headerLevel;
}

sub _liRecurse { # also used for dd
    my ($self, $nodeRef) = @_;

    if (!defined $nodeRef) {
        carp "Warning: tried to recurse on an undefined node\n";
        return;
    }
    if ($nodeRef->isa('PurpleWiki::StructuralNode')) {
        $self->traverse($nodeRef->content) if defined $nodeRef->content;
    }
    # display NID here
    $self->traverse($nodeRef->children) if defined $nodeRef->children;
}

sub _openTagWithNID {
    my ($self, $nodeRef) = @_;
    $self->{outputString} .= '<outline hs:nid="0' . $nodeRef->id . '" text="';
    
    $self->{outputString} .= '&lt;' . $nodeRef->type .'&gt;'
	if ($nodeRef->type ne 'p');
}

sub _closeTagWithNID {
    my ($self, $nodeRef) = @_;
    $self->{outputString} .= '&lt;/' . $nodeRef->type . '&gt;'
	if ($nodeRef->type ne 'p');
    $self->{outputString} .= '" />' . "\n";
}

sub _quoteHtml {
    my ($self, $nodeRef) = @_;
    my $html = $nodeRef->content || '';

    $html =~ s/&/&amp;/g;
    $html =~ s/</&lt;/g;
    $html =~ s/>/&gt;/g;
    $html =~ s/\"/&quot;/g;

    if (1) {   # Make an official option?
        $html =~ s/&amp;([#a-zA-Z0-9]+);/&$1;/g;  # Allow character references
    }

    $self->{outputString} .= $html;
}

sub _wikiLink {
    my ($self, $nodeRef) = @_;
    my $pageName = $nodeRef->content;
    my $linkString = "";
    my $pageNid;
    my $pages = $self->{config}->{pages};

    if ($pageName =~ s/\#([A-Z0-9]+)$//) {
        $pageNid = $1;
    }
    my $pageId = $pageName;
    $pageId = PurpleWiki::Misc::FreeToNormal($pageName)
        if ($nodeRef->type eq 'freelink');

    if ($nodeRef->content =~ /:/) {
        $linkString .= '&lt;a href=&quot;'
                       . PurpleWiki::Misc::getInterWikiLink($pageName);
        $linkString .= "#nid$pageNid" if $pageNid;
        $linkString .= '&quot; class=&quot;interwiki&quot;&gt;' . $nodeRef->content . '&lt;/a&gt;';
    }
    elsif ($pages && $pages->pageExists($pageId)) {
        if ($nodeRef->type eq 'freelink') {
            $linkString .= '&lt;a href=&quot;'
                           . PurpleWiki::Misc::getFreeLink($nodeRef->content)
                           . '&quot; class=&quot;freelink&quot;&gt;';
        } else {
            $linkString .= '&lt;a href=&quot;'
                           . PurpleWiki::Misc::getWikiWordLink($pageName);
            $linkString .= "#nid$pageNid" if $pageNid;
            $linkString .= '&quot; class=&quot;wikiword&quot;&gt;';
        }
        $linkString .= $nodeRef->content . '&lt;/a&gt;';
    }
    else {
        my $createLinkText = $self->{locale}->createLinkText;
        if ($nodeRef->type eq 'freelink') {
            if ($createLinkText) {
                my $linkText .= '[' . $nodeRef->content . ']';
                my $createLink = '&lt;a href=&quot;'
                         . PurpleWiki::Misc::getFreeLink($nodeRef->content)
                               . qq{&quot; class=&quot;freelink&quot;&gt;$createLinkText&lt;/a&gt;};
                if ($self->{config}->CreateLinkBefore) {
                    $linkString .= $createLink . $linkText;
                }
                else {
                    $linkString .= $linkText . $createLink;
                }
            }
            else {
                # the bracket syntax isn't necessary, because the
                # entire text is linked
                $linkString .= '&lt;a href=&quot;'
                         . PurpleWiki::Misc::getFreeLink($nodeRef->content)
                         . qq{&quot; class=&quot;create&quot;&gt;$nodeRef->content&lt;/a&gt;};
            }
        }
        else {
            if ($createLinkText) {
                my $linkText .= $nodeRef->content;
                my $createLink .= '&lt;a href=&quot;'
                          . PurpleWiki::Misc::getWikiWordLink($pageName)
                          . qq{&quot; class=&quot;wikiword&quot;&gt;$createLinkText&lt;/a&gt;};
                if ($self->{config}->CreateLinkBefore) {
                    $linkString .= $createLink . $linkText;
                }
                else {
                    $linkString .= $linkText . $createLink;
                }
            }
            else {
                $linkString .= '&lt;a href=&quot;'
                     . PurpleWiki::Misc::getWikiWordLink($pageName)
                     . '&quot; class=&quot;create&quot;&gt;' . $nodeRef->content . '&lt;/a&gt;';
            }
        }
    }

    $self->{outputString} .= $linkString;
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

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::View::Driver>, L<PurpleWiki::View::wikihtml>

=cut
