# PurpleWiki::Search::Arts.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Arts.pm,v 1.1 2003/12/31 22:41:35 cdent Exp $
#
# A Search Module for Arts (http://arts.sourceforge.net/) files
# that have been formatted as PurpleWiki wikitext.
#
# FIXME: Arts configuration has serious namespace issues, so there's
# some silliness in _initArts to get the proper information.

package PurpleWiki::Search::Arts;

use strict;
use base 'PurpleWiki::Search::Interface';
use PurpleWiki::Search::Result;
use IO::File;
use Data::Dumper;

# Where the searching is done.
sub search {
    my $self = shift;
    my $query = shift;
    my @results;

    $self->_initArts();

    # Loop through each of the available repositories, looking
    # at the files within for matches on the query.
    #
    # FIXME: this loop is much too long, it should be broken
    # down into sub routines.
    foreach my $repository (sort(keys(%{$self->{repositories}}))) {

        my $directory = $self->{repositories}{$repository};
        opendir(DIR, $directory) ||
            die "unable to open dir $directory: $!\n";
        my @files = grep(/^\d+\.\d+\.wiki$/, (readdir(DIR)));
        closedir(DIR);

        foreach my $file (@files) {
            my $bodytext;
            my $title;
            my $url;
            my $nid;

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
                $bodytext =~ /$query[^{]*{nid\s+(\w+)}/i;
                $nid = $1;
                $nid = "#nid$nid" if $nid;

                # FIXME: inconsistency on need of / at end of dir name
                $url = $self->{artsConfig}{$repository}{urlprefix} . '/' .
                    $file . $nid;

                # pack the results
                my $result = new PurpleWiki::Search::Result();
                $result->setTitle("$repository: $title");
                $result->setURL($url);
                push(@results, $result);
            }
        }
    }

    return @results;
}

sub _initArts {
    my $self = shift;

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
        if ($config{$repository}{purpleConfig} =
            $self->{config}->DataDir()) {
            $repositories{$repository} = $config{$repository}{repository};
        }
    }

    # FIXME: its redundant to have both of these but I wanted easy
    #        access
    $self->{artsConfig} = \%config;
    $self->{repositories} = \%repositories;

    return $self;
}

1;
