# PurpleWiki::Database::User
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: User.pm,v 1.1.2.2 2003/01/30 08:31:48 cdent Exp $
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

package PurpleWiki::Database::User;

# PurpleWiki User Data Access

# $Id: User.pm,v 1.1.2.2 2003/01/30 08:31:48 cdent Exp $

use strict;
use PurpleWiki::Config;

my @DataFields = (
    'username', 'id', 'randkey', 'rev', 'createtime', 'createip',
    'email', 'password', 'notify', 'adminpw', 'linkrandom',
    'toplinkbar', 'rcdays', 'rcnewtop', 'rcall', 'rcchangehist',
    'editwide', 'norcdiff', 'diffrclink', 'alldiff', 'defaultdiff',
    'rcshowedit', 'tzoffset', 'editrows', 'editcols',
);

# Creates a new user reference, may be a
# a new one or an existing one.
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = @_;
    my $self = { %args };
    bless ($self, $class);
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;

    if ($self->userExists()) {
        my $filename = $self->getUserFile();
        my $data = PurpleWiki::Database::ReadFileOrDie($filename);
        $self->_parseData($data);
    } else {
        $self->_openNewUser();
    }
}

sub _parseData {
    my $self = shift;
    my $data = shift;

    my %tempHash = split (/$FS1/, $data, -1);

    foreach my $key (keys(%tempHash)) {
        $self->{$key} = $tempHash{$key};
    }
}

sub _openNewUser {
    my $self = shift;
    $self->setField('id', $self->_getNewUserID());
}

sub _getNewUserID {
    my $self = shift;
    my ($id);

    $id = 1001;
    while (-f $self->getUserFile($id+1000)) {
        $id += 1000;
    }
    while (-f $self->getUserFile($id+100)) {
        $id += 100;
    }
    while (-f $self->getUserFile($id+10)) {
        $id += 10;
    }
    &PurpleWiki::Database::RequestLock() or die('Could not get user-ID lock');
    while (-f $self->getUserFile($id)) {
        $id++;
    }
    $self->createUserDir();
    &PurpleWiki::Database::WriteStringToFile($self->getUserFile($id), "lock");  # reserve the ID
    &PurpleWiki::Database::ReleaseLock();
    return $id;
}






sub getID {
    my $self = shift;
    return $self->{id};
}

sub getUsername {
    my $self = shift;
    return $self->{username};
}

sub getUserFile {
    my $self = shift;
    my $id = shift || $self->getID();

    return "" if ($id < 1);

    return $UserDir . "/" . ($id % 10) . "/$id.db";
}

sub userFileExists {
    my $self = shift;

    return (-f $self->getUserFile());
}

sub userExists {
    my $self = shift;
    return $self->userFileExists();
}

# FIXME: this is so convenient yet so dirty
# there are so many different ways to do this.
sub getField {
    my $self = shift;
    my $field = shift;

    return $self->{$field};
}

# FIXME: this is so convenient yet so dirty
sub setField {
    my $self = shift;
    my $field = shift;
    my $value = shift;

    $self->{$field} = $value;
}

sub save {
    my $self = shift;

    my $data = $self->serialize();
    
    $self->createUserDir();

    PurpleWiki::Database::WriteStringToFile($self->getUserFile(), $data);
}

# Creates the directory where user information
# is stored.
sub createUserDir {
    my $self = shift;
    my ($n, $subdir);

    if (!(-d "$UserDir/0")) {
        PurpleWiki::Database::CreateDir($UserDir);

        foreach $n (0..9) {
            $subdir = "$UserDir/$n";
            PurpleWiki::Database::CreateDir($subdir);
        }
    }
}

sub serialize {
    my $self = shift;

    my $data = join($FS1, map {$_ . $FS1 . $self->{$_}} @DataFields);

    return $data;
}

1;
