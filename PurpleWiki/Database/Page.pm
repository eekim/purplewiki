# PurpleWiki::Database::Page
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Page.pm,v 1.1.2.1 2003/01/27 10:11:24 cdent Exp $
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

package PurpleWiki::Database::Page;

# PurpleWiki Page Data Access

# $Id: Page.pm,v 1.1.2.1 2003/01/27 10:11:24 cdent Exp $

use strict;
use PurpleWiki::Config;
use PurpleWiki::Database;
use PurpleWiki::Database::Section;
use PurpleWiki::Database::Text;

# defaults for Text Based data structure
my $DATA_VERSION = 3;            # the data format version

# Creates a new page reference, may be a
# a new one or an existing one.
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {@_};
    bless ($self, $class);
    return $self;
}

# A stub to facillitate other callers
sub pageExists {
    my $self = shift;
    return $self->pageFileExists();
}

# Returns true if the page file associated with this
# page exists.
sub pageFileExists {
    my $self = shift;

    my $filename = $self->getPageFile();

    return (-f $filename);
}

sub setPageCache {
    my $self = shift;
    my $cache = shift;
    my $revision = shift;

    $self->{cache} = $revision;
}

# Opens the page file associated with this id of this
# Page.
sub openPage {
    my $self = shift;
    my $filename;
    my $data;

    $filename = $self->getPageFile();

    if ($self->pageFileExists()) {
        # FIXME: there should be a utility class of some kind
        $data = PurpleWiki::Database::ReadFileOrDie($filename);
        $self->_parseData($data);
    } else {
        $self->_openNewPage();
    }

    if ($self->getVersion() != $DATA_VERSION) {
        $self->_updatePageVersion();
    }
}

# Retrieves the default text data by getting the
# section and then the text in that section.
# Or creates a new one.
sub getText {
    my $self = shift;

    if (!defined($self->{text_default})) {
            return $self->createNewText();
    } else {
        my $section = $self->getSection();
        return $section->getText();
    }
}

# Retrieves the section data.
sub getSection {
    my $self = shift;

    if (ref($self->{text_default})) {
        return $self->{text_default};
    } else {
        return
            new PurpleWiki::Database::Section('data' => $self->{text_default},
                                              'now' => $self->getNow(),
                                              'userID' => $self->{userID},
                                              'username' => $self->{username});
    }
}

# Creates an empty new Text and Section 
sub createNewText {
    my $self = shift;
    my $section = $self->getSection();
    return $section->getText();
}

# Retrives the version of this page.
sub getVersion {
    my $self = shift;
    return $self->{version};
}

# Retrieves the id of this page.
sub getID {
    my $self = shift;
    return $self->{id};
}

# Retrieves the name of this page.
# FIXME: this is probably always the same as the id but being 
# prepared
sub getName {
    my $self = shift;
    return $self->{id};
}

# Retrieves the now of when this page was asked for.
sub getNow {
    my $self = shift;
    return $self->{now};
}

# Determins the filename of the keep page with this id.
sub getKeepFile {
    my $self = shift;

    return $KeepDir . '/' . $self->getPageDirectory() . '/' .
        $self->getID() . '.kp';
}

# Determines the filename of the page with this id.
sub getPageFile {
    my $self = shift;

    return $PageDir . '/' . $self->getPageDirectory() . '/' .
        $self->getID() . '.db';
}

# Determines the directory of this page.
sub getPageDirectory {
    my $self = shift;

    my $directory = 'other';

    if ($self->getID() =~ /^([a-zA-Z])/) {
        $directory = uc($1);
    }

    return $directory;
}

# Causes an error because the data in the 
# Page file is out of date.
sub _updatePageVersion {
    my $self = shift;

    # FIXME: ugly
    PurpleWiki::Database::ReportError('Bad page version (or corrupt page)');
}

# Parses the data read in from a page file.
sub _parseData {
    my $self = shift;
    my $data = shift;

    my %tempHash = split(/$FS1/, $data, -1);

    foreach my $key (keys(%tempHash)) {
        $self->{$key} = $tempHash{$key};
    }

    $self->{text_default} = $self->getSection();
}

sub _openNewPage {
    my $self = shift;

    $self->{version} = 3;
    $self->{revision} = 0;
    $self->{tscreate} = $self->getNow();
    $self->{ts} = $self->getNow();
}

sub serialize {
    my $self = shift;

    my $sectionData = $self->{'text_default'}->serialize();

    my $data = map {$_ . $FS1 . $self->{$_} . $FS1} 
        ('version', 'revision', 'cache_oldmajor', 'cache_oldauthor',
         'cache_diff_default_major', 'cache_diff_default_minor',
         'ts_create', 'ts');

    $data .= $sectionData;

    return $data;
}

1;
