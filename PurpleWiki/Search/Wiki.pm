# PurpleWiki::Search::Wiki.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Wiki.pm,v 1.2 2004/01/06 19:17:34 cdent Exp $
#

package PurpleWiki::Search::Wiki;

use strict;
use base 'PurpleWiki::Search::Interface';
use PurpleWiki::Search::Result;
use PurpleWiki::Database;
use PurpleWiki::Page;

# Where the searching is done.
sub search {
    my $self = shift;
    my $query = shift;
    my @found;
    my @results;

    my $name;

    foreach $name (PurpleWiki::Database::AllPagesList($self->{config})) {
        if ($name =~ /$query/i) {
            push(@found, $name);
        } elsif ($self->{config}->FreeLinks() && ($name =~ m/_/)) {
            my $freeName = $name;
            $freeName =~ s/_/ /g;
            if ($freeName =~ /$query/i) {
                push(@found, $name);
                next; # FIXME: this effort at skipping the text read uglifies 
            }
        } else {
            my $page = new PurpleWiki::Database::Page(id => $name,
                now => time,
                config => $self->{config});
            $page->openPage();
            my $text = $page->getText();
            if ($text->getText() =~ /$query/i) {
                push(@found, $name);
            }
        }
    }

    foreach my $name (sort(@found)) {
        my $result = new PurpleWiki::Search::Result();
        $result->setTitle($name);
        $result->setURL(PurpleWiki::Page::getWikiWordLink($name,
                            $self->{config}));
        $result->setSummary();
        push(@results, $result);
    } 

    return @results;
}

1;
