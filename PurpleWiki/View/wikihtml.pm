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
    $self->{outputString} .= $self->{transcluder}->get($nodeRef->content);
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
    $self->{outputString} .= '<a class="extlink" href="';
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
