# PurpleWiki::Rss.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2003.  All rights reserved.
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

package PurpleWiki::Rss;

# PurpleWiki Rss generation
#
# FIXME: Replace getRecentChanges with the Idiom code when it is done,
# from whence much of this is stolen.

# $Id$

use strict;
use XML::RSS;
use PurpleWiki::Database::Page;
use PurpleWiki::Parser::WikiText;

use vars qw($VERSION);
$VERSION = '0.9.1';

sub new {
    my $proto = shift;
    my $self = { @_ };
    my $class = ref($proto) || $proto;
    die "No config object found" if not exists $self->{config};
    bless($self, $class);
    return $self;
}

sub getRSS {
    my $self = shift;
    my $count = shift || 15;
    my $string;

    my @recentChanges = reverse($self->_getRecentChanges());

    my $rss = new XML::RSS;
    $rss->channel (
        title => $self->{config}->SiteName,
        # FIXME: this isn't good enough as it might not be set
        # to a full URL. FullURL is optional though, so?
        link  => $self->{config}->ScriptName,
    );

    while ($count-- > 0) {
        my $recentChange = shift(@recentChanges) || last;
        my $bodyText = $self->_getWikiHTML($recentChange->{name});

        $rss->add_item(
            title => $recentChange->{name},
            link  => $self->{config}->ScriptName . '?' .$recentChange->{name},
            dc => {
                creator => $recentChange->{author},
            },
            description => "<![CDATA[$bodyText]]>\n",
        );
    }

    return $rss->as_string;
}

sub _getWikiHTML {
    my $self = shift;
    my $id = shift;

    my $url = $self->{config}->ScriptName . '?' . $id;
    my $page = new PurpleWiki::Database::Page(id => $id,
        config => $self->{config});
    $page->openPage();
    my $parser = PurpleWiki::Parser::WikiText->new();
    my $wiki = $parser->parse($page->getText()->getText(),
        add_node_ids => 0,
        config => $self->{config},
        url => $url,
    );
    return $wiki->view('wikihtml', config => $self->{config},
        url => $url);
}




sub _getRecentChanges {
    my ($self, $timeStamp) = @_;
    my @RCInfo = ();

    # Default to showing all changes.
    $timeStamp = 0 if not defined $timeStamp;

    # Convert timeStamp to seconds since the epoch if it's not already in
    # that form.
    if (not $timeStamp =~ /^\d+$/) {
        use Date::Manip;
        $timeStamp = abs(UnixDate($timeStamp, "%o")) || 0;
    }

    open(IN, $self->{config}->RcFile)
        || die $self->{config}->RCName." log error: $!\n";
    for my $logEntry (<IN>) {
        chomp $logEntry;
        my $fsexp = $self->{config}->FS3;
        my @entries = split /$fsexp/, $logEntry;
        if (@entries == 7 && $entries[0] >= $timeStamp) {  # Check timestamp
            my %info;
            $info{name} = $entries[1];
            $info{summary} = $entries[2];
            $info{minorEdit} = $entries[3];
            $info{host} = $entries[4];
            $info{author} = "";

            # $entries[5] is garbage and so we ignore it...

            # Get extra info
            my $fsexp = $self->{config}->FS2;
            @entries = split /$fsexp/, $entries[6];
            if (@entries == 2) {
                $info{userID} = $entries[0];
                $info{author} = $info{username} = $entries[1];
            }

            push @RCInfo, \%info;
        }
    }
    close(IN);

    return @RCInfo;
}
