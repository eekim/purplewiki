# PurpleWiki::Template::Base.pm
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

package PurpleWiki::Template::Base;

use 5.005;
use strict;

use vars qw($VERSION);
$VERSION = '0.9.3';

### constructor

sub new {
    my $this = shift;
    my %options = @_;
    my $self = {};

    $self->{templateDir} = $options{templateDir}
        if ($options{templateDir});
    bless($self, $this);
    return $self;
}

### methods

sub templateDir {
    my $self = shift;

    $self->{templateDir} = shift if @_;
    return $self->{templateDir};
}

sub vars {
    my $self = shift;
    my %var = @_;

    $self->{vars} = \%var if (%var);
    return $self->{vars};
}

sub process {
    die shift() . " didn't define a template method!";
}

1;
__END__

=head1 NAME

PurpleWiki::Template::Base - Base class for template drivers

=head1 SYNOPSIS

  use PurpleWiki::Template::Base;

=head1 DESCRIPTION



=head1 METHODS

=head2 new(%options)



=head2 view($driver, %params)



=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
