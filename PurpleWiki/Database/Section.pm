# PurpleWiki::Database::Section
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Section.pm,v 1.1.2.1 2003/01/27 10:11:24 cdent Exp $
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

package PurpleWiki::Database::Section;

# PurpleWiki Section Data Access

# $Id: Section.pm,v 1.1.2.1 2003/01/27 10:11:24 cdent Exp $

use strict;
use PurpleWiki::Config;
use PurpleWiki::Database;
use PurpleWiki::Database::Text;

# defaults for Text Based data structure
my $DATA_VERSION = 1;            # the data format version

# Creates a new page reference, may be a
# a new one or an existing one.
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless ($self, $class);
    $self->_init(@_);
    return $self;
}

# Creates a new Text from this Section
sub getText {
    my $self = shift;

    if (ref($self->{data})) {
        return $self->{data};
    } else {
        return new PurpleWiki::Database::Text($self->{data});
    }
}

sub getRevision {
    my $self = shift;
    return $self->{revision};
}

sub getHost {
    my $self = shift;
    return $self->{host};
}

sub getIP {
    my $self = shift;
    return $self->{ip};
}

sub getID {
    my $self = shift;
    return $self->{id};
}

sub getUsername {
    my $self = shift;
    return $self->{username};
}

sub getTS {
    my $self = shift;
    return $self->{ts};
}

sub setKeepTS {
    my $self = shift;
    my $time = shift;
    $self->{keepts} = $time;
}


# Initializes the Section datastructure by pulling fields from
# the page. Or creates a new one
sub _init {
    my $self = shift;
    my %args = @_;

    # If we have data to push in
    if (defined($args{data})) {
        my %tempHash = split(/$FS2/, $args{data}, -1);

        foreach my $key (keys(%tempHash)) {
            $self->{$key} = $tempHash{$key};
        } 
        $self->{data} = $self->getText();
    } else {
        $self->{name} = 'text_default';
        $self->{version} = 1;
        $self->{revision} = 0;
        $self->{tscreate} = $self->{now};
        $self->{ts} = $self->{now};
        $self->{ip} = $ENV{REMOTE_ADDR};
        $self->{host} = '';
        $self->{id} = $self->{userID};
        #$self->{username} = $self->{username} # redundant
        $self->{data} = new PurpleWiki::Database::Text();
    }
}

sub serialize {
    my $self = shift;

    my $textData = $self->{data}->serialize();

    my $data = map {$_ . $FS2 . $self->{$_} . $FS2} 
        ('name', 'version', 'id', 'username', 'ip', 'host',
         'ts', 'tscreate', 'keepts', 'revision', 'revision');
    $data .= $textData;

    return $data;
}

1;