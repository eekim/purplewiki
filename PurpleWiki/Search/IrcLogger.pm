# PurpleWiki::Search::IrcLogger.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: IrcLogger.pm,v 1.1 2003/12/31 23:46:12 cdent Exp $
#
# A Search Module for irclogger (see
# http://collab.blueoxen.net/forums/tools-yak/2003-12/msg00003.html
# )
#
# A sublcass of the Arts module as they use the same file format.
#
# FIXME: Changes the Arts module to WikiText and make both Arts and
# IrcLogger subclasses of that.

package PurpleWiki::Search::IrcLogger;

use strict;
use base 'PurpleWiki::Search::Arts';
use PurpleWiki::Search::Result;
use IO::File;
use AppConfig;
use Data::Dumper;

# AppConfig values from the irclogger config file
my @CONFIG = qw(channel wikiconfig url logfile);

# The regular expression used for matching filenames
my $FILE_MATCH = 'irclog\.\d+\.wiki';

sub _initRepository {
    my $self = shift;

    # open the logger config files and get the relevant info
    # and translate it to arts style
    my %config;

    foreach my $configFile (@{$self->{config}->IrcLogConfig()}) {
        my $configRef = $self->_initConfig($configFile);

        my $channel = $configRef->channel();
        $config{$channel}{purpleConfig} = $configRef->wikiconfig();

        my $url = $configRef->url();
        $url =~ s/\/[^\/]+$//;
        $config{$channel}{urlprefix} = $url;

        my $files = $configRef->logfile();
        $files =~ s/\/[^\/]+$//;
        $config{$channel}{repository} = $files;
    }

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
    $self->{repositoryConfig} = \%config;
    $self->{repositories} = \%repositories;

    return $self;
}

# initialize the irclogger config
# taken from irclogger itself
sub _initConfig {
    my $self = shift;
    my $file = shift;

    $self->{fileMatch} = $FILE_MATCH;

    my $config;

    $config = AppConfig->new({
            CREATE => 1,
            GLOBAL => {
                EXPAND => AppConfig::EXPAND_VAR,
            },
        });

    foreach my $var (@CONFIG) {
        $config->define($var, {
                ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            });
    }

    $config->file($file) || die "unable to parse config file: $file";

    return $config;
}
                   



1;
