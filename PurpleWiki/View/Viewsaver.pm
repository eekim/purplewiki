package Viewsaver;

# A quick package to allow tying output to a filehandle
# to a scalar variable. Not necessary in newer versions 
# of Perl.

# $Id: Viewsaver.pm,v 1.1 2002/10/22 07:20:55 cdent Exp $

use strict;

my $string;

sub TIEHANDLE {
        my $class = shift;
        my $i = {};
        bless $i, $class;
}

sub PRINT {
        my $r = shift;
        $string .= join($,,@_);
}

sub getstring {
        my $r = shift;
        return $string;
}

1;
