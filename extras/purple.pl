# vi:ai:sm:et:sw=4:tw=0:ts=4
# 
# Purple Plugin For Movable Type
#
# Provide Purple Numbering and Wiki Formatting for
# Movable Type entries.
#
# Chris Dent
# <cdent@blueoxen.org>
# http://purplewiki.blueoxen.org/
# This software is provided as-is.
# You may use it for commercial or non commercial use.
# If you distribute it, please keep this notice intact.
#
# Copyright (c) 2003 Blue Oxen Associates, LLC
#

package plugins::purple;

use vars qw($VERSION);
$VERSION = 0.2;

use strict;
no warnings 'redefine';

use lib '/home/cdent/src/PurpleWiki.nidGen';
use PurpleWiki::Parser::WikiText;
use MT;
use MT::Entry;
use MT::Comment;
use MT::Template::Context;

##### PRESENTATION #####

# the provides for the presentation of existing PurpleWiki content in 
# the database, out to the blog.
MT->add_text_filter('purpleIN' => {
    label => 'PurpleWiki',
    on_format => sub {
        &parseForPurple(@_);
    },
    docs =>
        'http://www.burningchrome.com:8000/mt-static/docs/mtmanual_purple.html'
});

# parses the PurpleWiki text of the entry into HTML form
# The URL of the entry is required to make the purple
# number be link to the permalink location of the content
sub parseForPurple {
    my $str = shift;
    my $ctx = shift;

    my $url = 'dammit';
    my $entry;

    if ($ctx) {
        $entry = $ctx->stash('entry');
    } 

    if (!defined($entry)) {
        return $str;
    }

    $url = $entry->permalink;
    $str = "\n$str\r\n";
    my $parser = PurpleWiki::Parser::WikiText->new();
    my $wiki = $parser->parse($str);
    my $results = $wiki->view('wikihtml', 'urlBase' => $url);
    return $results;
}

# for debugging
sub log {
    my $message = shift;

    open(LOG, ">>/tmp/mt.log") || die "unable to open log file\n";

    print LOG $message, "\n";

    close LOG;
    return;
}

##### SAVING #####

# FIXME: The entry saving function is a copy with adjustments of an
# existing MT function. If that function changes in an upgrade these
# may cause breakage. The comment function overrides the base Object
# save().

##### Comments #####

# sub for overriding Comment::save()
my $commentSaveSub = sub {
    package MT::Comment;

    my $comment = shift;

    my $text = $comment->text;
    
    # for retrieving the permalink of the associated entry
    my $entry = MT::Entry->load($comment->entry_id);

    # process text
    $text =~ s/\r//g;
    my $parser = PurpleWiki::Parser::WikiText->new();
    my $wiki = $parser->parse($text, 'add_node_ids' => 1,
        'url' => $entry->permalink);
    $text = $wiki->view('wikitext');
    $text =~ s/\r//g;

    # save it
    $comment->text($text);
    $comment->SUPER::save(@_) or return;
};

*MT::Comment::save = $commentSaveSub; 

##### Entries #####

# There's a lot going on in MT::Entry::save() that we want to use
# so instead of a total override, we try to use the existing one
# and then do our own things afterward.

my $originalEntrySave = \&MT::Entry::save;

my $entrySaveSub = sub {
    package MT::Entry;

    my @args = @_;

    &$originalEntrySave(@_);

    # get the entry object for certain
    my $entry = shift(@args);

    # we save the entry and then we edit it to purple and
    # save it again, this is we can have access to the id
    # which is only created after a save.
    # Only do this if the entry is purpleIN text format
    if ($entry->convert_breaks =~ /purpleIN/) {
        my $text = $entry->text;
        $text =~ s/\r//g;
        my $parser = PurpleWiki::Parser::WikiText->new();
        my $wiki = $parser->parse($text, 'add_node_ids'=> 1,
            'url' => $entry->permalink);
        $text = $wiki->view('wikitext');
        $text =~ s/\r//g;
        $entry->text($text);
        $entry->SUPER::save(@_) or return;
    }

    1;
};

*MT::Entry::save = $entrySaveSub;

1;
