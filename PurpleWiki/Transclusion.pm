# PurpleWiki::Transclusion.pm
# vi:ai:sw=4:ts=4:et:sm
#
# $Id: Transclusion.pm,v 1.9.2.1 2004/02/05 07:20:22 cdent Exp $
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

package PurpleWiki::Transclusion;

use strict;
use DB_File;
use LWP::UserAgent;
use PurpleWiki::Sequence;

use vars qw($VERSION);
$VERSION = '0.9.1';

# The name of the index file. Its directory comes from Config.
my $INDEX_FILE = 'sequence.index';

# Creates a new Transclusion object associated with 
# the sequence.index in the DataDir. The index is 
# used to find the URL from which a particular NID
# originates. See get() for more.
# 
# A single Transclusion object should be able to do
# multiple gets, but this has not been tested.
# FIXME: will a DB file opened for a long read be
# aware of new writes? Presumably not?
sub new {
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    my %params = @_; 

    $self->{config} = $params{config};
    $self->{url} = $params{url};
    $self->{outputType} = $params{outputType};

    return $self;
}

# Takes the provided nid, looks it up in the sequence.index
# and then uses HTTP to retrieve the page on which that NID
# is found. The retrieved page is parsed to gather the
# content associated with the NID. A string containing
# the content or an error message if it could not be obtained
# is returned.

sub get {
    my $self = shift;
    my $nid = shift;
    my $nidLong = "nid$nid";
    my $outputType = $self->{outputType} || '';
    my $content;

    # get the URL that hosts this nid out of the the db
    my $sequence = new PurpleWiki::Sequence($self->{config}->DataDir(),
        $self->{config}->RemoteSequence());
    my $url = $sequence->getURL($nid);

    $content = "no URL for $nid" unless $url;

    if ($url) {
        # if the page being retrieved is a wiki page
        # and source and target are the same, don't
        # try to retrieve. Same url on static content
        # is fine.
        # FIXME: assumes that anything not the wiki
        # is static content
        my $scriptName = $self->{config}->ScriptName;
        if ((($url =~ /$scriptName/) || ($url =~ /\.wiki$/)) &&
            ($url eq $self->{url})) {
            $content = q(Transclusion loop, please remove.);
        } else {
            # request the content of the URL 
            my $ua = new LWP::UserAgent(agent => ref($self));
            my $request = new HTTP::Request('GET', $url);
            my $result = $ua->request($request);
    
            if ($result->is_success()) {
                $content = $result->content();
                ($content =~ s/^.*<a name="$nidLong"[^>]+><\/a>//is &&
                    $content =~
                        s/&nbsp;&nbsp;\s*<a class="nid" title="$nid".*$//is )
                            || ($content = "transclusion index out of sync");
            } else {
                $content = "unable to retrieve content: " . $result->code();
            }
        }
    }

    
    if ($outputType !~ /plaintext/) {
        $content = qq(<span id="$nidLong" class="transclusion">) .
            qq($content&nbsp;<a class="nid" title="$nid" ) .
            qq(href="$url#$nidLong">T</a></span>);
    }
    return $content;
}

# Attaches to the the DB file which contains the NID:URL index
sub _tieHash {
    my $self = shift;
    my $file = shift;

    tie %{$self->{db}}, 'DB_File', $file, O_RDONLY, 0444, $DB_HASH or
        warn "unable to tie $file: $!";
}

1;
__END__

=head1 NAME

PurpleWiki::Transclusion - Transclusion object.

=head1 SYNOPSIS

  use PurpleWiki::Config;
  use PurpleWiki::Transclusion;

  my $config = PurpleWiki::Config->new('/var/www/wikidb');
  my $transclusion = PurpleWiki::Transclusion->new(
     config => $config,
     url => 'http://purplewiki.blueoxen.net/cgi-bin/wiki.pl?HomePage',
     ouput_type => 'plaintext');

  $transclusion->get('2H1');  # retrieves content of NID 2H1

=head1 DESCRIPTION

A first stab at transclusions in PurpleWiki. This is an extremely
rudimentary prototype. It is not meant to be good by any stretch of
the imagination. It is simply to demonstrate the possibilities that
these features allow.

=head1 METHODS

=head2 new(%params)

Creates a new Transclusion object associated with the sequence.index
in the DataDir. The index is used to find the URL from which a
particular NID originates. See get() for more.

There are three parameters:

       config -- PurpleWiki::Config object

          url -- The URL requesting the transclusion

   outputType -- plaintext, xhtml or undef (defaults to xhtml)

=head2 get($nid)

Takes $nid, looks it up in the sequence.index and then uses HTTP to
retrieve the page on which that NID is found. The retrieved page is
parsed to gather the content associated with the NID. A string
containing the content or an error message if it could not be obtained
is returned.

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
