# PurpleWiki::Database::Text
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Text.pm,v 1.1.2.1 2003/01/27 10:11:24 cdent Exp $
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

package PurpleWiki::Database::Text;

# PurpleWiki Text Data Access

# $Id: Text.pm,v 1.1.2.1 2003/01/27 10:11:24 cdent Exp $

use strict;
use PurpleWiki::Config;
use PurpleWiki::Database;

# Creates a new page reference, may be a
# a new one or an existing one.
sub new {
    my $proto = shift;
    my $data = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless ($self, $class);
    $self->_init($data);
    return $self;
}

# Retrieves the text string from this Text
sub getText {
    my $self = shift;
    return $self->{text};
}

sub getMinor {
    my $self = shift;
    return $self->{minor};
}

sub getNewAuthor {
    my $self = shift;
    return $self->{newauthor};
}

sub getSummary {
    my $self = shift;
    return $self->{summary};
}

# FIXME: dupe of getMinor
# which is better?
sub isMinor {
    my $self = shift;
    return $self->{minor};
}

# Initializes the Section datastructure by pulling fields from
# the page
sub _init {
    my $self = shift;
    my $data = shift;

    if (defined($data)) {
        my %tempHash = split(/$FS3/, $data, -1);

        foreach my $key (keys(%tempHash)) {
            $self->{$key} = $tempHash{$key};
        }
    } else {
        if ($NewText ne '') {
            $self->{text} = $NewText;
        } else {
            $self->{text} = 'Describe the new page here.' . "\n";
        }
        $self->{text} .= "\n"  if (substr($self->getText(), -1, 1) ne "\n");
        $self->{minor} = 0;      # Default as major edit
        $self->{newauthor} = 1;  # Default as new author
        $self->{summary} = '';
    }
}

sub serialize {
    my $self = shift;

    my $data = map {$_ . $FS3 . $self->{$_} . $FS3}
        ('text', 'minor', 'newauthor', 'summary');
    $data =~ s/$FS3$//;

    return $data;

}

1;
