# PurpleWiki::Search::Interface.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Interface.pm,v 1.1 2003/12/31 08:02:51 cdent Exp $
#
# This is an Abstract class to show an interface. For the time
# being it is extremely simple. It hopes for later refactoring
# to lend it credibility.

package PurpleWiki::Search::Interface;

use strict;

sub new {
    my $class = shift;
    my $self = {};

    my %params = @_;

    $self->{config} = $params{config};

    bless ($self, $class);

    return $self;
}

# Where the searching is done.
sub search {
    my $self = shift;
    my $query = shift;
    my @results;

    return @results;
}

1;
