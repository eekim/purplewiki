# PurpleWiki::Search::Result.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Result.pm,v 1.1 2003/12/31 08:02:51 cdent Exp $
#

package PurpleWiki::Search::Result;

use strict;

sub new {
    my $class = shift;
    my $self = {};

    my %params = @_;

    bless ($self, $class);

    return $self;
}

sub setTitle {
    my $self = shift;

    $self->{title} = shift;
    return $self;
}

sub setURL {
    my $self = shift;

    $self->{URL} = shift;
    return $self;
}

sub setSummary {
    my $self = shift;

    $self->{summary} = shift;
    return $self;
}

sub getTitle {
    my $self = shift;
    return $self->{title};
}

sub getURL {
    my $self = shift;
    return $self->{URL};
}

sub getSummary {
    my $self = shift;
    return $self->{summary};
}

1;
