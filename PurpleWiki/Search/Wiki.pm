# PurpleWiki::Search::Wiki.pm
# vi:ai:sm:et:sw=4:ts=4
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

package PurpleWiki::Search::Wiki;

use strict;
use base 'PurpleWiki::Search::Interface';
use PurpleWiki::Search::Result;
use PurpleWiki::Misc;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

# Where the searching is done.
sub search {
    my $self = shift;
    my $query = shift;
    my @results;

    my $nameHash;
    my $pages = $self->{archive};
unless ($pages) {
use Carp;
Carp::confess("FIX: missing archive attribute, can't search the wiki\n");
}
    return unless $pages;

    foreach my $id ($pages->allPages()) {
        my $page = $pages->getPage($id);
	    my $name = $pages->getName($id);
        my $text;
        if ($name =~ /$query/i) {
print STDERR "Search Match name $name \n";
            push(@results, _searchResult($page, $name));
        } elsif (($text = $page->getTree->view('wikitext')) =~ /$query/i) {
print STDERR "Search Match body $name \n";
            push(@results, _searchResult($page, $name, $text));
        }
    }

    @results = sort {$b->modifiedTime() <=> $a->modifiedTime()}
        @results;

    return @results;
}

sub _searchResult {
    my ($page, $name, $text) = @_;
    my $result = PurpleWiki::Search::Result->new();
    if ($page) {
        my $id = $page->getID();
        $result->title($name);
        $result->modifiedTime($page->getTime());
        $result->url(PurpleWiki::Misc::getWikiWordLink($id));
        $text = $page->getTree->view('wikitext') unless $text;
        $text =  (substr($text, 0, 99).'...') if (length($text) > 100);
        $result->summary($text);
    }
    $result;
}

1;

__END__

=head1 NAME

PurpleWiki::Search::Wiki - Search The Wiki Text and Titles

=head1 SYNOPSIS

Searches the text and titles of the local wiki pages.

=head1 DESCRIPTION

This module moves code from the core CGI of the Wiki out into the
pluggable search module system.

It is turned on by default in new (0.9.1 and after) versions of 
PurpleWiki. In upgraded systems a line should be added to the
PuprleWiki configuration file, F<config>:

  SearchModule = Wiki

=head1 METHODS

See L<PurpleWiki::Search::Interface>

=head1 AUTHOR

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Search::Interface>.
L<PurpleWiki::Search::Engine>.
L<PurpleWiki::Search::Result>.

=cut
