# PurpleWiki::Sequence.pm
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id: Sequence.pm,v 1.1.2.2 2003/05/21 05:19:00 cdent Exp $
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

package PurpleWiki::Sequence;

# Tool for generating PurpleWiki::Sequence numbers for use
# in Nids

# $Id: Sequence.pm,v 1.1.2.2 2003/05/21 05:19:00 cdent Exp $

use strict;
use IO::File;
use DB_File;

my $ORIGIN = '000000';
my $LOCK_WAIT = 1;
my $LOCK_TRIES = 5;

sub new {
    my $proto = shift;
    my $datafile = shift;
    my $origin = shift || $ORIGIN;
    my $class = ref($proto) || $proto;
    my $self = {};

    $self->{datafile} = $datafile;
    $self->{origin} = $origin;
    bless ($self, $class);
    return $self;
}

# Returns the next ID in the sequence
sub getNext {
    my $self = shift;
    my $url = shift;
    $self->_lockFile();
    my $value = $self->_retrieveNextValue();
    $self->_unlockFile();
    # update the NID to URL index
    if ($url) {
        $self->_updateIndex($value, $url);
    }
    return $value;
}

# I suspect this is expensive
sub _updateIndex {
    my $self = shift;
    my $value = shift;
    my $url = shift;
    my %index;

    tie %index, 'DB_File', $self->{datafile} . '.index', 
        O_RDWR|O_CREAT, 0644, $DB_HASH ||
        die "unable to tie " . $self->{datafile} . '.index' . $!;

    $index{$value} = $url;
    untie %index;
}



sub _retrieveNextValue {
    my $self = shift;

    my $newValue = $self->_incrementValue($self->_getCurrentValue());
    $self->_setValue($newValue);
    return $newValue;
}

sub _setValue {
    my $self = shift;
    my $value = shift;

    my $fh = new IO::File;
    if ($fh->open($self->{datafile}, 'w')) {
        print $fh $value;
        $fh->close();
    } else {
        die "unable to write value to " . $self->{datafile} . ": $!";
    }
}

sub _incrementValue {
    my $self = shift;
    my $oldValue = shift;


    my @oldValues = split('', $oldValue);
    my @newValues;
    my $carryBit = 1;
    my $loopCount = 0;

    # FIXME: can do this in a map?
    foreach my $char (reverse(@oldValues)) {
        $loopCount++;
        if ($carryBit) {
            my $newChar;
            ($newChar, $carryBit) = $self->_incChar($char);
            # FIXME: this is bogus, be graceful
            if ($carryBit && $loopCount >= length($self->{origin})) {
                die "Overflow!";
            }
            push(@newValues, $newChar);
        } else {
            push(@newValues, $char);
        }
    }

    return join('', (reverse(@newValues)));
}

# FIXME: ASCII/Unicode dependent
sub _incChar {
    my $self = shift;
    my $char = shift;

    if ($char eq 'Z') {
        return '0', 1;
    }

    if ($char eq '9') {
        return 'A', 0;
    }

    if ($char =~ /[A-Z0-9]/) {
        return chr(ord($char) + 1), 0;
    }
}



sub _getCurrentValue {
    my $self = shift;
    my $file = $self->{datafile};
    my $value;

    if (-f $file) {
        my $fh = new IO::File;
        $fh->open($file) || die "Unable to open $file: $!";
        $value = $fh->getline();
        $fh->close();
    } else {
        $value = $self->{origin};
    }

    return $value;
}

# FIXME: this should not die
sub _lockFile {
    my $self = shift;
    # use simple directory locks for ease
    my $dir = $self->{datafile} . '.lck';
    my $tries = 0;

    # FIXME: copied from UseMod, relies on errno
    while (mkdir($dir, 0555) == 0) {
        if ($! != 17) {
            die "Unable to create locking directory $dir";
        }
        $tries++;
        if ($tries > $LOCK_TRIES) {
            die "Timeout creating locking directory $dir";
        }
        sleep($LOCK_WAIT);
    }
}
        
sub _unlockFile {
    my $self = shift;
    my $dir = $self->{datafile} . '.lck';
    rmdir($dir) or die "Unale to remove locking directory $dir: $!";
}


