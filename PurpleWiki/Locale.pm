# PurpleWiki::Locale.pm
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

package PurpleWiki::Locale;

use 5.005;
use strict;
use IO::File;
use PurpleWiki::Config;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

### constructor

sub new {
    my $this = shift;
    my @languages = @_;
    my $self;

    $self = {};
    my $config = PurpleWiki::Config->instance();
    $self->{localeFile} = $config->LocaleFile;
    $self->{languages} = [@languages];
    push @{$self->{languages}}, $config->DefaultLanguage;

    bless($self, $this);
    return $self;
}

### methods

sub createLinkText {
    my $self = shift;

    my $messages = &_parseLocaleFile($self->{localeFile});
    my @languages = @{$self->{languages}};
    foreach my $lang (@languages) {
        return $messages->{$lang}->{CreateLinkText}
            if ($messages->{$lang}->{CreateLinkText});
    }
}

### private

sub _parseLocaleFile {
    my $fh = IO::File->new(shift);
    my %messages;
    my %language;
    my $currentLang;

    if (defined $fh) {
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /^\s*lang\s*=\s*(\w+)\s*$/) {
                $currentLang = $1;
            }
            elsif ($line =~ /^\s*(\w+)\s*=\s*\"([^\"]+)"\s*$/) {
                $language{$1} = $2;
            }
            elsif ($line =~ /^-----\s*$/) {
                $messages{$currentLang} = {%language};
                %language = ();
            }
        }
        $fh->close;
        return \%messages;
    }
    else {
        return {};
    }
}

1;
__END__

=head1 NAME

PurpleWiki::Locale - Localization routines

=head1 SYNOPSIS

  use PurpleWiki::Locale;

  my $locale = PurpleWiki::Locale->new('en');
  print $locale->createLinkText . "\n";

=head1 DESCRIPTION



=head1 FILE FORMAT



=head1 METHODS

=head2 new(@lang)

Constructor.  

=head2 createLinkText()



=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
