# PurpleWiki::View::wikitext.pm
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

package PurpleWiki::View::wikitext;
use 5.005;
use strict;
use warnings;
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
    $self->{sectionDepth} = 0;
    $self->{indentDepth} = 0;
    $self->{listStack} = [];
    $self->{isPrevSection} = 0;
    $self->{isStart} = 1;
    $self->{lastInlineProcessed} = "";

    bless($self, $class);
    return $self;
}

sub view {
    my ($self, $wikiTree) = @_;
    $self->SUPER::view($wikiTree);
    $self->{outputString} = $self->_header($wikiTree) . $self->{outputString};
    return $self->{outputString};
}

sub sectionPre { 
    my $self = shift;
    $self->{sectionDepth}++;
    $self->_hardRule;
    $self->{isPrevSection} = 1;
}

sub sectionPost {
    my $self = shift;
    $self->{sectionDepth}--;
    $self->{lastInlineProcessed} = '';
    $self->_hardRule;
    $self->{isStart} = 0;
}

sub indentPre { 
    my $self = shift;
    $self->_hardRule;
    $self->{indentDepth}++; 
}

sub indentPost { 
    my $self = shift;
    $self->{indentDepth}--;
    $self->{lastInlineProcessed} = '';
    $self->{outputString} .= "\n" if $self->{indentDepth} == 0; 
}

sub ulPre {
    my ($self, $nodeRef) = @_;
    $self->_hardRule;
    push @{$self->{listStack}}, $nodeRef->type;
}

sub olPre {
    my ($self, $nodeRef) = @_;
    $self->_hardRule;
    push @{$self->{listStack}}, $nodeRef->type;
}

sub dlPre {
    my ($self, $nodeRef) = @_;
    $self->_hardRule;
    push @{$self->{listStack}}, $nodeRef->type;
}

sub ulPost { shift->_endList(@_) }
sub olPost { shift->_endList(@_) }
sub dlPost { shift->_endList(@_) }

sub hPre { 
    my $self = shift;
    $self->{isPrevSection} = 0;
    $self->{isStart} = 0;
    $self->{outputString} .= '=' x $self->{sectionDepth}. ' '; 
}

sub hPost { 
    my ($self, $nodeRef) = @_;
    $self->{lastInlineProcessed} = '';
    $self->{outputString} .= $self->_nid($nodeRef->id) . " ";
    $self->{outputString} .= '=' x $self->{sectionDepth} . "\n\n";
}

sub pPre { 
    my $self = shift;
    $self->_hardRule;
    $self->{outputString} .= ':' x $self->{indentDepth};
}

sub pPost { 
    my ($self, $nodeRef) = @_;
    $self->{lastInlineProcessed} = '';
    $self->{outputString} .= $self->_nid($nodeRef->id) . "\n";
    $self->{outputString} .= "\n" if $self->{indentDepth} == 0;
}

sub liPre { 
    my $self = shift;
    my $bullet = ($self->{listStack}->[-1] eq 'ul') ? '*' : '#';
    $self->{outputString} .= $bullet x scalar(@{$self->{listStack}}) . ' ';
}

sub dtPre { 
    my $self = shift;
    $self->{outputString} .= ';' x scalar(@{$self->{listStack}});
}

sub ddPre { 
    shift->{outputString} .= ':' 
}

sub liPost { shift->_showNID(@_) }
sub dtPost { shift->_showNID(@_) }
sub ddPost { shift->_showNID(@_) }

sub prePre { &_hardRule(shift) }

sub prePost { shift->_showNID(@_) }

sub sketchMain { 
    shift->{outputString} .= "{sketch}\n\n";
}

sub bPre { 
    shift->{outputString} .= "'''";
}

sub bPost { 
    my $self = shift;
    $self->{lastInlineProcessed} = 'b'; 
    $self->{outputString} .= "'''"; 
}

sub iPre { 
    shift->{outputString} .= "''";
}

sub iPost { 
    my $self = shift;
    $self->{lastInlineProcessed} = 'i'; 
    $self->{outputString} .= "''"; 
}

sub ttPre { 
    shift->{outputString} .= "<tt>";
}

sub ttPost { 
    my $self = shift;
    $self->{lastInlineProcessed} = 'tt'; 
    $self->{outputString} .=  "</tt>"; 
}

sub textPre { 
    my ($self, $nodeRef) = @_;
    if ($self->{lastInlineProcessed} eq 'wikiword') {
        if ($nodeRef->content =~ /^\w/) {
            $self->{outputString} .= '""';
        }
    }
}

sub textMain { shift->{outputString} .= shift->content }
sub nowikiMain { shift->{outputString} .= shift->content }
sub transclusionMain { shift->{outputString} .= shift->content }
sub linkMain { shift->{outputString} .= shift->content }
sub urlMain { shift->{outputString} .= shift->content }
sub wikiwordMain { shift->{outputString} .= shift->content }
sub freelinkMain { shift->{outputString} .= shift->content }
sub imageMain { shift->{outputString} .= shift->content }

sub textPost { shift->{lastInlineProcessed} = 'text' }

sub nowikiPre { shift->{outputString} .= '<nowiki>' }

sub nowikiPost { 
    my $self = shift;
    $self->{lastInlineProcessed} = 'nowiki'; 
    $self->{outputString} .= '</nowiki>'; 
}

sub transclusionPre { 
    shift->{outputString} .= '[t ';
}

sub transclusionPost { 
    my $self = shift;
    $self->{lastInlineProcessed} = 'transclusion'; 
    $self->{outputString} .= ']'; 
}

sub linkPre { 
    my ($self, $nodeRef) = @_; 
    $self->{outputString} .= '[' . $nodeRef->href . ' '; 
}

sub linkPost { 
    my $self = shift;
    $self->{lastInlineProcessed} = 'link'; 
    $self->{outputString} .= ']'; 
}

sub urlPost { 
    shift->{lastInlineProcessed} = 'url';
}

sub wikiwordPost { 
    shift->{lastInlineProcessed} = 'wikiword'; 
}

sub freelinkPre { 
    shift->{outputString} .= '[['; 
}

sub freelinkPost { 
    my $self = shift;
    $self->{lastInlineProcessed} = 'freelink'; 
    $self->{outputString} .= ']]'; 
}

sub imagePost { 
    shift->{lastInlineProcessed} = 'image'; 
}


############### Private Methods ###############

sub _hardRule {
    my $self = shift;

    if ($self->{isPrevSection}) {
        if (!$self->{isStart}) {
            $self->{outputString} .= "----\n\n";
        }
        else {
            $self->{isStart} = 0;
        }
        $self->{isPrevSection} = 0;
    }
}

sub _endList {
    my $self = shift;
    pop @{$self->{listStack}};
    $self->{lastInlineProcessed} = '';
    $self->{outputString} .= "\n" if scalar @{$self->{listStack}} == 0;
}

sub _showNID {
    my ($self, $nodeRef) = @_;
    my $nidString = $self->_nid($nodeRef->id);

    $self->{lastInlineProcessed} = '';

    if ($nodeRef->type eq 'dt') {
        $self->{outputString} .= $nidString;
    } elsif ($nodeRef->type eq 'pre') {
        $self->{outputString} .= $nidString . "\n\n";
    } else {
        $self->{outputString} .= $nidString . "\n";
    }
}

sub _nid {
    my ($self, $nid) = @_;
    return " {nid $nid}" if ($nid);
}

sub _header {
    my ($self, $wikiTree) = @_;
    my $header = '';

    # FIXME: this can be a loop
    if ($wikiTree->title) {
        $header .= '{title ' . $wikiTree->title . "}\n";
    }

    if ($wikiTree->subtitle) {
        $header .= '{subtitle ' . $wikiTree->subtitle . "}\n";
    }

    if ($wikiTree->authors) {
        foreach my $author (@{$wikiTree->authors}) {
            $header .= '{author ' . $author->[0];
            if (scalar @{$author} > 1) {
                $header .= ' ' . $author->[1];
            }
            $header .= "}\n";
        }
    }

    if ($wikiTree->id) {
        $header .= '{docid ' . $wikiTree->id . "}\n";
    }

    if ($wikiTree->version) {
        $header .= '{version ' . $wikiTree->version . "}\n";
    }

    if ($wikiTree->date) {
        $header .= '{date ' . $wikiTree->date . "}\n";
    }

    return $header;
}
1;
__END__

=head1 NAME

PurpleWiki::View::wikitext - View Driver used for WikiText output.

=head1 DESCRIPTION

Converts a PurpleWiki::Tree into WikiText. 

=head1 OBJECT STATE

=head2 outputString 

This contains the current working copy of the text that is ultimately returned
by view().

=head1 METHODS

=head2 new(config => $config)

Returns a new PurpleWiki::View::wikihtml object  If config is not passed in
then a fatal error occurs.  

=head2 view($wikiTree)

Returns the output as a string of WikiText.

=head1 AUTHORS

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::View::Driver>

=cut
