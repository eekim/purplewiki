# PurpleWiki::Database::KeptRevision
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: KeptRevision.pm,v 1.1.2.3 2003/01/30 02:54:00 cdent Exp $
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

package PurpleWiki::Database::KeptRevision;

# PurpleWiki Page Data Access

# $Id: KeptRevision.pm,v 1.1.2.3 2003/01/30 02:54:00 cdent Exp $

use strict;
use PurpleWiki::Config;
use PurpleWiki::Database;
use PurpleWiki::Database::Section;

# Creates a new kept revision reference
# Really just a collection of Sections
sub new {
    my $proto = shift;
    my $id = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless ($self, $class);

    $self->{id} = $id;
    $self->{sections} = [];
    $self->_makeKeptList();

    return $self;
}

sub getSections {
    my $self = shift;

    return @{$self->{sections}};
}


# Determines if this collection of kepts has the given revision
sub hasRevision {
    my $self = shift;
    my $revision = shift;

    return (ref($self->{sections}->[$revision]));
}

# Retrieves the Section related to a particular revision
sub getRevision {
    my $self = shift;
    my $revision = shift;
    return $self->{sections}->[$revision];
}

sub addSection {
    my $self = shift;
    my $section = shift;
    my $now = shift;
    $section->setKeepTS($now);
    push(@{$self->{sections}}, $section);
}

sub trimKepts {
    my $self = shift;
    my $now = shift;

    my $expirets = $now - ($KeepDays * 24 * 60 * 60);

    # setting to undef actually going to do it?
    foreach my $section (@{$self->{sections}}) {
        if ($section->getKeepTS() < $expirets) {
            undef $section;
        }
    }
}





sub keptFileExists {
    my $self = shift;

    my $filename = $self->getKeepFile();

    return (-f $filename);
}

# Determins the filename of the keep page with this id.
sub getKeepFile {
    my $self = shift;

    return $KeepDir . '/' . $self->getPageDirectory() . '/' .
        $self->getID() . '.kp';
}

sub _makeKeptList {
    my $self = shift;
    my $data;

    if ($self->keptFileExists()) {
        my $filename = $self->getKeepFile();
        # FIXME: nasty call out
        $data = PurpleWiki::Database::ReadFileOrDie($filename);
        $self->_parseData($data);
    }
}

sub _parseData {
    my $self = shift;
    my $data = shift;
    my $count = 0;

    foreach my $section (split(/$FS1/, $data, -1)) {
        push(@{$self->{sections}}, 
            new PurpleWiki::Database::Section('data' => $section));
    }
}

sub getID {
    my $self = shift;
    return $self->{id};
}




# Determines the directory of this page.
# FIXME: duplicated from Page.pm
sub getPageDirectory {
    my $self = shift;

    my $directory = 'other';

    if ($self->getID() =~ /^([a-zA-Z])/) {
        $directory = uc($1);
    }

    return $directory;
}

# we go ahead and rewrite the whole thing
sub save {
    my $self = shift;
    my $data = $self->serialize();

    $self->_createKeepDir();
    PurpleWiki::Database::WriteStringToFile($self->getKeepFile(), $data);
}

sub _createKeepDir {
    my $self = shift;
    my $id = $self->getID();
    my $dir = $KeepDir;
    my $subdir;

    PurpleWiki::Database::CreateDir($dir);  # Make sure main page exists
    $subdir = $dir . '/' . $self->getKeepDirectory();
    PurpleWiki::Database::CreateDir($subdir);

    if ($id =~ m|([^/]+)/|) {
        $subdir = $subdir . '/' . $1;
        PurpleWiki::Database::CreateDir($subdir);
    }
}

sub getKeepDirectory {
    my $self = shift;

    my $directory = 'other';

    if ($self->getID() =~ /^([a-zA-Z])/) {
        $directory = uc($1);
    }

    return $directory;
}
    
sub serialize {
    my $self = shift;

    my $data;
    my $section;
    foreach $section ($self->getSections()) {
        # FIXME: shouldn't need to do this...
        next if (!defined($section));
        $data .= $section->serialize();
        $data .= $FS1;
    }

    $data =~ s/$FS1$//;

    return $data;
}

1;

