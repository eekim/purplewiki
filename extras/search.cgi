#!/usr/bin/perl
use strict;
use XMLRPC::Transport::HTTP;
use PurpleWiki::Config;
use PurpleWiki::Search::Engine;

my $CONFIG_DIR = '/var/www/wikidb';

my $config = new PurpleWiki::Config($CONFIG_DIR);
my $server = XMLRPC::Transport::HTTP::CGI->dispatch_to('search')->handle;

sub search {
    my $self = shift;
    my $keywords = shift;
    my @resultList;

    my $search = PurpleWiki::Search::Engine->new;
    $search->search($keywords);

    my $results = ${$search->results}{'Wiki'};
    foreach my $result (@{$results}) {
        push @resultList, {
            url => $result->url,
            title => $result->title,
            summary => $result->summary,
            mtime => $result->lastModified };
    }
    return @resultList;
}
