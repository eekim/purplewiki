# PurpleWiki::View::text.pm
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

package PurpleWiki::View::text;
use 5.005;
use strict;
use warnings;
use Text::Wrap;
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
    $self->{indentLevel} = 0;
    $self->{outputString} = "";
    $self->{listType} = "";
    $self->{initialIndent} = "";
    $self->{subsequentIndent} = "";
    $self->{listNumber} = 1;
    $self->{prevDefType} = "";
    $self->{links} = [];
    $self->{linksIndex} = 1;
    $self->{showLinks} = 1;

    bless($self, $class);
    return $self;
}

sub view {
    my ($self, $wikiTree) = @_;
    
    if (!defined($self->{columns}) || $self->{columns} !~ /^\d+$/ || $self->{columns} < 10) {
        $self->{columns} = 72;
    }
    if (defined $self->{show_links} && $self->{show_links} == 0) {
        $self->{showLinks} = 0;
    }

    $Text::Wrap::columns = $self->{columns};
    $Text::Wrap::huge = 'overflow';

    $self->SUPER::view($wikiTree);

    $self->{outputString} = $self->_header($wikiTree) .
                            $self->{outputString} .  $self->_footer;

    return $self->{outputString};
}

sub Pre {
    my ($self, $nodeRef) = @_;
    if ($nodeRef->type =~ /^(ul|ol|dl|indent|section)$/) {
        $self->{indentLevel}++;
    }
    $self->SUPER::Pre($nodeRef);
}

sub Post {
    my ($self, $nodeRef) = @_;
    if ($nodeRef->type =~ /^(ul|ol|dl|indent|section)$/) {
        $self->{indentLevel}--;
    }
    $self->SUPER::Post($nodeRef);
}

sub sectionPre { shift->_setIndent(@_) }
sub indentPre { shift->_setIndent(@_) }
sub ulPre { shift->_setIndent(@_) }
sub olPre { shift->_setIndent(@_) }
sub dlPre { shift->_setIndent(@_) }

sub ulMain { shift->_recurseList(@_) }
sub olMain { shift->_recurseList(@_) }

sub hPre { shift->_newLineSetIndent(@_) }
sub pPre { shift->_newLineSetIndent(@_) }
sub liPre { shift->_newLineSetIndent(@_) }
sub dtPre { shift->_newLineSetIndent(@_) }
sub prePre { shift->_newLineSetIndent(@_) }

sub hMain { shift->_structuralContent(@_) }
sub pMain { shift->_structuralContent(@_) }
sub liMain { shift->_structuralContent(@_) }
sub dtMain { shift->_structuralContent(@_) }
sub ddMain { shift->_structuralContent(@_) }
sub preMain { shift->_structuralContent(@_) }

sub hPost { shift->{outputString} .= "\n" }
sub pPost { shift->{outputString} .= "\n" }
sub liPost { shift->{outputString} .= "\n" }
sub prePost { shift->{outputString} .= "\n" }

sub dtPost { 
    my $self = shift;
    $self->{prevDefType} = 'dt';
    $self->{outputString} .= "\n";
}

sub ddPre {
    my $self = shift;
    $self->_setIndent(@_);
    if ($self->{prevDefType} eq 'dd') {
        $self->{outputString} .= "\n";
    }
}

sub ddPost {
    my $self = shift;
    $self->{prevDefType} = 'dd';
    $self->{outputString} .= "\n";
}

sub bPre { shift->{outputString} .= "*" }
sub bPost { shift->{outputString} .= "*" }

sub iPre { shift->{outputString} .= "_" }
sub iPost { shift->{outputString} .= "_" }

sub textMain { shift->{outputString} .= shift->content }
sub nowikiMain { shift->{outputString} .= shift->content }
sub transclusionMain { shift->{outputString} .= shift->content }
sub linkMain { shift->{outputString} .= shift->content }

sub transclusionPre { shift->{outputString} .= "transclude: " }

sub linkPost {
    my ($self, $nodeRef) = @_;
    if ($self->{showLinks}) {
        push @{$self->{links}}, $nodeRef->href;
        $self->{linksIndex}++;
        $self->{outputString} .= '[' . ($self->{linksIndex} - 1) . ']';
    }
}

sub urlPre { shift->{outputString} .= shift->content }
sub wikiwordPre { shift->{outputString} .= shift->content }
sub freelinkPre { shift->{outputString} .= shift->content }
sub imagePre { shift->{outputString} .= shift->content }


############### Private Methods ###############

sub _recurseList {
    my ($self, $nodeRef) = @_;
    $self->{listType} = $nodeRef->type;
    $self->{listNumber} = 1 if $nodeRef->type eq 'ol';
    $self->recurse($nodeRef);
}

sub _newLineSetIndent {
    my $self = shift;
    $self->_setIndent(@_);
    $self->{outputString} .= "\n";
}

sub _structuralContent {
    my ($self, $nodeRef) = @_;

    if ($nodeRef->content) {
        my $tmp = $self->{outputString};
        $self->{outputString} = "";
        $self->traverse($nodeRef->content);
        my $nodeString = $self->{outputString};
        $self->{outputString} = $tmp;
        if ($nodeRef->type eq 'li') {
            if ($self->{listType} eq 'ul') {
                $nodeString = "* $nodeString";
            }
            elsif ($self->{listType} eq 'ol') {
                $nodeString = $self->{listNumber}.". $nodeString";
                $self->{listNumber}++;
            }
        }
        if ($nodeRef->type eq 'pre') {
            $self->{outputString} .= &Text::Wrap::wrap($self->{initialIndent},
                                     $self->{subsequentIndent},
                                     $nodeString);
        }
        else {
            $self->{outputString} .= &Text::Wrap::fill($self->{initialIndent},
                                     $self->{subsequentIndent},
                                     $nodeString);
        }
    }
}

sub _setIndent {
    my ($self, $nodeRef) = @_;

    my $indent;
    my $initialOffset = 1;
    my $subsequentOffset = 1;
    my $subsequentMore = 0;
    my $listMore = 0;

    if ($nodeRef->type eq 'li') {
        $initialOffset = 2;
        $subsequentOffset = 2;
        $listMore = 2;

        if ($self->{listType} eq 'ul') {
            $subsequentMore = 2;
        } elsif ($self->{listType} eq 'ol') {
            $subsequentMore = 3;
        }
    } elsif ($nodeRef->type eq 'dt') {
        $initialOffset = 2;
        $subsequentOffset = 2;
    }

    $indent = 4*$self->{indentLevel} - 4*$initialOffset + $listMore;
    $self->{initialIndent} = ' ' x $indent;

    $indent = 4*$self->{indentLevel} - 4*$subsequentOffset + $subsequentMore 
              + $listMore;
    $self->{subsequentIndent} = ' ' x $indent;
}

sub _header {
    my ($self, $wikiTree) = @_;
    my $header = "";

    $header .= $self->_center($wikiTree->title, $self->{columns});
    $header .= $self->_center($wikiTree->subtitle, $self->{columns});
    $header .= $self->_center($wikiTree->id, $self->{columns});
    $header .= $self->_center($wikiTree->date, $self->{columns});
    $header .= $self->_center($wikiTree->version, $self->{columns});

    return $header."\n";
}

sub _footer {
    my $self = shift;
    my $footer = "";

    if ($self->{showLinks}) {  # check for links
        if (scalar @{$self->{links}} > 0) {
            $footer = "\n\n";
            $footer .= "LINK REFERENCES\n\n";
            $self->{linksIndex} = 1;
            foreach my $link (@{$self->{links}}) {
                $footer .= "    [".$self->{linksIndex}."] $link\n";
                $self->{linksIndex}++;
            }
        }
    }

    return $footer;
}

sub _center {
    my ($self, $string, $columns) = @_;
    my $padding;

    return "" if not $string;

    if (length $string > $columns) {
        return $string . "\n";
    }

    $padding = ($columns - length $string) / 2;
    return ' 'x$padding . $string. "\n";
}
1;
__END__

=head1 NAME

PurpleWiki::View::text - View Driver used for Text Output.

=head1 DESCRIPTION

Prints out a text view of a PurpleWiki::Tree.

=head1 OBJECT STATE

=head2 outputString 

This contains the current working copy of the text that is ultimately returned
by view().

=head1 METHODS

=head2 new(config => $config, show_links => true/false, columns => $columns)

Returns a new PurpleWiki::View::text object  If config is not passed in then a
fatal error occurs.  show_links and columns are not required and default to
true and 72 respectively.  show_links can also be written as showLinks.

If show_links is true then links are marked with "[n]" style references, where
n is an integer.  At the bottom of the output the references show what 
URLs the links were pointing at.

columns is the number of columns to make the text output fit into.

=head2 view($wikiTree)

Returns the output as a string of text.

=head1 AUTHORS

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::View::Driver>

=cut
