# PurpleWiki::ACL.pm
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2005.  All rights reserved.
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

package PurpleWiki::ACL;

use 5.005;
use strict;
use PurpleWiki::Config;
use PurpleWiki::Misc;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

### constructor

sub new {
    my $this = shift;
    my (%options) = @_;
    my $self;

    my $config = PurpleWiki::Config->instance;
    $self->{config} = $config;

    bless($self, $this);
    return $self;
}

### methods

# if $DataDir/restricted.read, then only the user IDs listed can read

sub canRead {
    my $self = shift;
    my ($user, $pageId) = @_;

    my ($status, $data) = PurpleWiki::Misc::ReadFile($self->{config}->DataDir . '/restricted.read');
    if (!$status) { # no file exists, so all is good
        return 1;
    }
    elsif ($user) {
        foreach my $allowedUserId (split(/\n/, $data)) {
            return 1 if ($user->id == $allowedUserId);
        }
        return 0;
    }
    else {
        return 0;
    }
}

# if $DataDir/restricted.edit, then only the user IDs listed can edit

sub canEdit {
    my $self = shift;
    my ($user, $pageId) = @_;

    return 0 if ($self->{config}->LoginToEdit && !defined $user 
                 && defined $pageId);
    # check ban list
    my ($status, $data) = PurpleWiki::Misc::ReadFile($self->{config}->DataDir . "/banlist");
    if ($status) {
        my $ip = $ENV{'REMOTE_ADDR'};
        my $host = $ENV{REMOTE_HOST};
        if ($host eq "") {
            # Catch errors (including bad input) without aborting the script
            eval 'use Socket; my $iaddr = inet_aton($ip});' .
                '$host = gethostbyaddr($iaddr, AF_INET)';
        }
        foreach (split(/\n/, $data)) {
            next if ((/^\s*$/) || (/^\#/));  # Skip empty, spaces, or comments
            return 0 if ($ip   =~ /$_/i);
            return 0 if ($host =~ /$_/i);
        }
    }
    # check for restricted file
    ($status, $data) = PurpleWiki::Misc::ReadFile($self->{config}->DataDir . '/restricted.write');
    if (!$status) { # no file exists, so all is good
        return 1;
    }
    elsif ($user) {
        foreach my $allowedUserId (split(/\n/, $data)) {
            return 1 if ($user->id == $allowedUserId);
        }
        return 0;
    }
    else {
        return 0;
    }
}

sub canAdmin {
    my $self = shift;
    my ($user, $pageId) = @_;

    return 0;
}

1;
__END__

=head1 NAME

PurpleWiki::ACL - Access control list.

=head1 SYNOPSIS

  use PurpleWiki::ACL;

  my $acl = PurpleWiki::ACL->new;

  if ($acl->canEdit($user, $pageId)) {
      # let the user edit the page
  }
  else {
      # return error message
  }

=head1 DESCRIPTION

Access control list for PurpleWiki.  Currently, always returns true
for canRead and false for canAdmin.  If LoginToEdit is true in the
config file, then will require the user to be logged in for canEdit to
return true.

This can easily be subclassed for more sophisticated ACL schemes.

=head1 METHODS

=head2 new()

Constructor.

=head2 canRead($user, $pageId)

Always returns true.

=head2 canEdit($user, $pageId)

If LoginToEdit is set, only returns true if user object is defined
(i.e. user is logged in).

Also checks to see if IP address/hostname is on the banlist.

=head2 canAdmin($user, $pageId)

Always returns false.

=head1 AUTHOR

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
