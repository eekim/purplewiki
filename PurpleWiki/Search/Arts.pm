# PurpleWiki::Search::Arts.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Arts.pm,v 1.3 2004/01/07 01:20:14 cdent Exp $
#
# A Search Module for Arts (http://arts.sourceforge.net/) files
# that have been formatted as PurpleWiki wikitext.
#
# FIXME: Arts configuration has serious namespace issues, so there's
# some silliness in _initArts to get the proper information.
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

package PurpleWiki::Search::Arts;

use strict;
use base 'PurpleWiki::Search::Interface';
use PurpleWiki::Search::Result;
use IO::File;

my $FILE_MATCH = '\d+\.\d+\.wiki';

# Where the searching is done.
sub search {
    my $self = shift;
    my $query = shift;
    my @results;

    $self->_initRepository();

    # Loop through each of the available repositories, looking
    # at the files within for matches on the query.
    #
    # FIXME: this loop is much too long, it should be broken
    # down into sub routines.
    foreach my $repository (sort(keys(%{$self->{repositories}}))) {

        my $directory = $self->{repositories}{$repository};

        opendir(DIR, $directory) ||
            die "unable to open dir $directory: $!\n";
        my @files = grep(/^$self->{fileMatch}$/, (readdir(DIR)));
        closedir(DIR);

        foreach my $file (sort {$b <=> $a} @files) {
            my $bodytext;
            my $title;

            my $fileref = new IO::File;
            $fileref->open("$directory/$file") ||
                die "unable to open file $file: $!\n";

            # read in the file
            while (<$fileref>) {
                $bodytext .= $_;
                # get the title
                /\{title\s+([^}]*)\}/i && ($title = $1);
            }

            $fileref->close();

            # look for the query
            if ($bodytext =~ /$query/is) {
                # find the nid
                $bodytext =~ /($query[^{]*){nid\s+(\w+)}/i;
                my $summary = $1;
                my $nid = $2;
                $nid = "#nid$nid" if $nid;

                # FIXME: inconsistency on need of / at end of dir name
                my $url = $self->{repositoryConfig}{$repository}{urlprefix} .
                    '/' .  $file . $nid;

                # pack the results
                my $result = new PurpleWiki::Search::Result();
                $result->setTitle("$repository: $title");
                $result->setURL($url);
                $result->setSummary($summary);
                $result->setModifiedTime((stat("$directory/$file"))[9]);
                push(@results, $result);
            }
        }
    }

    return @results;
}

sub _initRepository {
    my $self = shift;

    $self->{fileMatch} = $FILE_MATCH;

    # FIXME: need these to deal with arts.pl broken namespace
    my ($UPDATERDIR, $UPDATEREXT);

    # open the arts config file and evaluate it as perl
    my %config;
    my $configFile = $self->{config}->ArtsDirectory() . 'arts.pl';

    my $configRef = new IO::File;
    $configRef->open($configFile) or die "unable to open $configFile: $!";
    my $configText = join('', $configRef->getlines());
    $configRef->close();

    eval $configText;

    # collect information on the repository locations
    my %repositories;

    foreach my $repository (keys(%config)) {
        if ($config{$repository}{purpleConfig} eq
            $self->{config}->DataDir()) {
            $repositories{$repository} = $config{$repository}{repository};
        }
    }

    # FIXME: its redundant to have both of these but I wanted easy
    #        access
    $self->{repositoryConfig} = \%config;
    $self->{repositories} = \%repositories;

    return $self;
}

1;

__END__

=head1 NAME

PurpleWiki::Search::Arts - Search Arts Repositories

=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 METHODS



=head1 AUTHOR

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::Search::Interface>.
L<PurpleWiki::Search::Engine>.
L<PurpleWiki::Search::Result>.

=cut

