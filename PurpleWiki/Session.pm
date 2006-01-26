# PurpleWiki::Session.pm
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

package PurpleWiki::Session;

use 5.005;
use strict;
use CGI::Session;
use PurpleWiki::Config;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

### constructor

sub new {
    my $this = shift;
    my $sid = shift;
    my $self = {};

    $self->{config} = PurpleWiki::Config->instance();
    if (!-e $self->{config}->SessionDir) {
        mkdir $self->{config}->SessionDir;
    }
    $self->{session} = CGI::Session->new("driver:File", $sid,
                                         {Directory => $self->{config}->SessionDir});
    $self->{visitedPagesSize} = 7;
    $self->{visitedPages} = $self->{session}->param('visitedPagesCache') || {};

    bless($self, $this);
    return $self;
}

### methods

sub param {
    my $self = shift;
    return $self->{session}->param(@_);
}

sub clear {
    my $self = shift;
    return $self->{session}->clear(@_);
}

sub id {
    my $self = shift;
    return $self->{session}->id(@_);
}

sub delete {
    my $self = shift;
    return $self->{session}->delete(@_);
}

sub visitedPages {
    my $self = shift;

    my @pages = sort { $self->{visitedPages}->{$b} <=>
                           $self->{visitedPages}->{$a} }
        keys %{$self->{visitedPages}};
    my $i = 0;
    foreach my $id (@pages) {
        my $pageName = $id;
        $pageName =~ s/_/ /g if ($self->{config}->FreeLinks);
        $pages[$i] = {
            'id' => $id,
            'pageName' => $pageName,
        };
        $i++;
    };
    return @pages;
}

sub newVisitedPage {
    my $self = shift;
    my $id = shift;

    my @pages = keys %{$self->{visitedPages}};
    if (!defined $self->{visitedPages}->{$id} &&
        (scalar @pages >= $self->{visitedPagesSize})) {
        my @oldestPages = sort {
            $self->{visitedPages}->{$a} <=> $self->{visitedPages}->{$b}
        } @pages;
        my $remove = scalar @pages - $self->{visitedPagesSize} + 1;
        for (my $i = 0; $i < $remove; $i++) {
            delete $self->{visitedPages}->{$oldestPages[$i]};
        }
    }
    $self->{visitedPages}->{$id} = time;
    $self->param('visitedPagesCache', $self->{visitedPages});
}

1;
__END__

=head1 NAME

PurpleWiki::Session - Session management

=head1 SYNOPSIS

  use PurpleWiki::Session;

  my $sid;
  my $session = PurpleWiki::Session->new($sid);

=head1 DESCRIPTION



=head1 METHODS

=head2 new($sid)

Constructor.

=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
