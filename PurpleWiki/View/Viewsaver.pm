package PurpleWiki::View::Viewsaver;

# A quick package to allow tying output to a filehandle
# to a scalar variable. Not necessary in newer versions 
# of Perl.

# $Id: Viewsaver.pm,v 1.3 2002/10/23 05:07:27 cdent Exp $

use strict;

sub TIEHANDLE {
        my $class = shift;
        my $self = {};
        bless $self, $class;

        $self->{'stringref'} = shift;

        return $self;
}

sub PRINT {
        my $self = shift;
        ${$self->{'stringref'}} .= join('',@_);
}

1;
