# PurpleWiki::Syndication::Rss.pm
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

package PurpleWiki::Syndication::Rss;

# PurpleWiki Rss generation
#
# FIXME: Replace getRecentChanges with the Idiom code when it is done,
# from whence much of this is stolen.

use strict;
use XML::RSS;
use PurpleWiki::Parser::WikiText;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

sub new {
    my $proto = shift;
    my $self = { @_ };
    my $class = ref($proto) || $proto;
    $self->{config} = PurpleWiki::Config->instance() unless $self->{config};
    die "No config object found" if not defined $self->{config};
    bless($self, $class);
    return $self;
}

sub getRSS {
    my $self = shift;
    my $count = shift || 15;
    my $string;

    my $rcRef = $self ->{pages}-> recentChanges();
    my @recentChanges = @{$rcRef};

    my $rss = new XML::RSS;
    $rss->channel (
        title => $self->{config}->SiteName,
        # FIXME: this isn't good enough as it might not be set
        # to a full URL. FullURL is optional though, so?
        link  => $self->{config}->ScriptName,
    );

    # FIXME: depending on the wrong variable here, probably better 
    # to loop on the array
    while ($count-- > 0) {
        my $recentChange = shift(@recentChanges) || last;

        my $page = $self->{pages}->getPage($recentChange->{id})
        my $bodyText = $page->getWikiHTML();

        $rss->add_item(
            title => $recentChange->{pageName},
            link  => $self->{config}->ScriptName . '?' .$recentChange->{id},
            dc => {
                creator => $recentChange->{userName},
            },
            description => "<![CDATA[$bodyText]]>\n",
        );
    }

    return $rss->as_string;
}

1;
__END__

=head1 NAME

PurpleWiki::Syndication::Rss - RSS feed of RecentChanges

=head1 SYNOPSIS

  use PurpleWiki::Syndication::Rss;

  my $rss = PurpleWiki::Syndication::Rss->new;
  my $rssString = $rss->getRSS;

=head1 DESCRIPTION

Generates an RSS feed of RecentChanges.

=head1 METHODS

=head2 new

Constructor.

=head2 getRSS()

Returns RSS string of RecentChanges.

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Database>.

=cut
