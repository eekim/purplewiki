# PurpleWiki::Search::MovableType.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: MovableType.pm,v 1.2 2004/01/01 01:20:35 cdent Exp $
#

package PurpleWiki::Search::MovableType;

use strict;
use base 'PurpleWiki::Search::Interface';

# Where the searching is done.
# Most of this taken from MT::App::Search
sub search {
    my $self = shift;
    my $query = shift;
    my @results;
    my %includedBlogs;

    # initialize movable type library stuff
    $self->_initMT();

    # make our hash of blog ids we care about
    foreach my $id (@{$self->{config}->MovableTypeBlogId()}) {
        $includedBlogs{$id}++;
    }

    my %terms = (status => MT::Entry::RELEASE());

    my %args = ('sort' => 'created_on');
    my $iter = MT::Entry->load_iter(\%terms, \%args);

    while (my $entry = $iter->()) {
        my $blog_id = $entry->blog_id;
        next unless ($includedBlogs{$blog_id});
        if ($self->_search_hit($query, $entry)) {
            my $result = new PurpleWiki::Search::Result();
            $result->setTitle($entry->title);
            $result->setURL($entry->permalink);
            # FIXME: determine how to do a summary with cleanliness
            push(@results, $result);
        }
    }

    return @results;
}

sub _search_hit {
    my $self = shift;
    my $query = shift;
    my $entry = shift;

    my @text_elements;

    @text_elements = ($entry->title, $entry->text, $entry->text_more,
                      $entry->keywords);

    # get the comment text too
    my $comments = $entry->comments;
    foreach my $comment (@$comments) {
        push(@text_elements, $comment->text, $comment->author, $comment->url);
    }

    my $txt = join("\n", map $_ || '', @text_elements);
    return $txt =~ m/$query/i;
}

sub _initMT() {
    my $self = shift;

    unshift @INC, $self->{config}->MovableTypeDirectory() . 'lib';
    unshift @INC, $self->{config}->MovableTypeDirectory() . 'extlib';

    require MT::Object;
    require MT::ConfigMgr;
    require MT::Blog;
    require MT::Entry;

    # FIXME: this is an ugly uninformed way of doing things
    my $cfg = MT::ConfigMgr->instance;
    $cfg->read_config($self->{config}->MovableTypeDirectory() . 'mt.cfg') or
        die $cfg->errstr;

    MT::Object->set_driver($cfg->ObjectDriver);

    return $self;
}

1;
