# PurpleWiki::Archive::Base.pm
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

package PurpleWiki::Archive::Base;

use 5.005;
use strict;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

### constructor

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless ($self, $class);
    return $self;
}

### methods

sub getPage {
    die shift() . " didn't define a getPage method!";
}

sub putPage {
    die shift() . " didn't define a putPage method!";
}

sub deletePage {
    die shift() . " didn't define a deletePage method!";
}

sub allPages {
    die shift() . " didn't define a allPages method!";
}

sub recentChanges {
    die shift() . " didn't define a recentChanges method!";
}

sub diff {
    die shift() . " didn't define a diff method!";
}

sub pageExists {
    die shift() . " didn't define a pageExists method!";
}

sub getName {
    die shift() . " didn't define a getName method!";
}

sub getRevisions {
    die shift() . " didn't define a getRevisions method!";
}

1;
__END__

=head1 NAME

PurpleWiki::Archive::Base - Base class for Archive backends

=head1 DESCRIPTION

Base class for Archive backends.  All PurpleWiki backends should
subclass this base class and overload all of the following methods.

=head1 METHODS

=head2 new()

Constructor.

=head2 getPage($pageId, $revision)

Returns a PurpleWiki::Page (or subclassed) object.  If $revision is
not specified, returns the most current version.

=head2 putPage('pageId' => $pageId, 'tree' => $tree, 'userId' => $userId, 'host' => $host, 'changeSummary' => $changeSummary, 'oldRev' => $oldRev);

Writes a page.  If $oldRev is specified, checks to make sure that
$oldRev is the previous revision before attempting to write the new
page; otherwise, returns an error.  This prevents race conditions.

=head2 deletePage($pageId)

Deletes page $pageId.

=head2 allPages()

Returns a list of page IDs.

=head2 recentChanges($startTime)

Returns a list of most recently changed pages, dating back to
$startTime (if specified).  Data structure is a list of hash
references:

  {
    'timeStamp' => $timeStamp,
    'name' => $name,
    'numChanges' => $numChanges,
    'summary' => $summary,
    'userId' => $userId,
    'host' => $host
  }

=head2 diff($pageId, $fromRevision, $toRevision)

Returns diff of $fromRevision and $toRevision of page $pageId.  If
$fromRevision is not specified, returns the diff between the most
current version and its previous revision.

=head2 pageExists($pageId)

Returns 1 if page $pageId exists.

=head2 getRevisions($pageId, $maxCount)

Returns a list of hash references with information about $maxCount (if
specified) revisions of page $pageId.  Returned hash reference is:

  {
    'revision' => $revision,
    'dateTime' => $dateTime,
    'host' => $host,
    'userId' => $userId,
    'changeSummary' => $changeSummary
  }

=head2 getName($pageId)

Returns the user-visible page name.

=head1 AUTHORS

Gerry Gleason, E<lt>gerry@geraldgleason.comE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Archive::Base>.

=cut
