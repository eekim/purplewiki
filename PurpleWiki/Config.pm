# PurpleWiki::Config.pm
# vi:ai:sm:et:sw=4:ts=4
#
# $Id: Config.pm,v 1.3 2003/06/20 23:54:01 cdent Exp $
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

package PurpleWiki::Config;

# PurpleWiki Configuration 

# $Id: Config.pm,v 1.3 2003/06/20 23:54:01 cdent Exp $

use strict;
use AppConfig;

# Field separators that delimit page storage
my $FS  = "\xb3";      # The FS character is a superscript "3"
my $FS1 = $FS . "1";   # The FS values are used to separate fields
my $FS2 = $FS . "2";   # in stored hashtables and other data structures.
my $FS3 = $FS . "3";   # The FS character is not allowed in user data.

# Boolean Flags used in config file. We need to be able to
# inject them into the config.
# FIXME: AppConfig apparently requires definition of config file
# variable outside the config file. That's painful.
my @BOOLEAN_CONFIGS = qw( UseSubpage EditAllowed UseDiff FreeLinks
    WikiLinks AdminDelete RunCGI RecentTop UseDiffLog KeepMajor
    KeepAuthor BracketText UseAmPm UseLookup FreeUpper EmailNotify
    EmbedWiki LogoLeft ShowEdits NonEnglish SimpleLinks);
my @SCALAR_CONFIGS = qw( DataDir ScriptName CookieName SiteName
    HomePage RCName LogoUrl
    StyleSheet SiteBase FullUrl ScriptTZ RcDefault KeepDays AdminPass
    EditPass EmailFrom SendMail FooterNote EditNote UserGotoBar
    HttpCharset MaxPost PageDir UserDir KeepDir TempDir LockDir
    InterFile RcFile RcOldFile);
my @LIST_CONFIGS = qw( RcDays);

# Sets up the strings and regular expressions for matching

# Creates a new PurpleWiki::Config object
#
# FIXME: the OO is done here in expectation
# of eventually wanting or needing some kind
# of access control or other intercessionary methods
# between the PurpleWiki and the AppConfig stuff.
sub new {
    my $class = shift;
    my $directory = shift || die "you must provide a config directory";
    my $self = {};
    bless ($self, $class);

    $self->_init($directory);

    return $self;
}

sub _init {
    my $self = shift;
    my $directory = shift;
    my $file = "$directory/config";

    $self->{AppConfig} = AppConfig->new({
        CREATE => 1,
        GLOBAL => {
            EXPAND => AppConfig::EXPAND_VAR,
        },
    });

    # set the types of config variables
    $self->_initConfig($directory);

    # set the DataDir variable, it needs to come first
    # because it is expanded in the file
    $self->{AppConfig}->set('DataDir', $directory);

    $self->{AppConfig}->file($file) || die "unable to parse config file";
    $self->_initLinkPatterns();

    # set the File Separators
    $self->{AppConfig}->set('FS', $FS);
    $self->{AppConfig}->set('FS1', $FS1);
    $self->{AppConfig}->set('FS2', $FS2);
    $self->{AppConfig}->set('FS3', $FS3);

    return $self;
}

sub _initConfig {
    my $self = shift;

    foreach my $var (@BOOLEAN_CONFIGS) {
        $self->{AppConfig}->define($var, {
                ARGCOUNT => AppConfig::ARGCOUNT_NONE,
            });
    }

    foreach my $var (@SCALAR_CONFIGS) {
        $self->{AppConfig}->define($var, {
                ARGCOUNT => AppConfig::ARGCOUNT_ONE,
            });
    }

    foreach my $var (@LIST_CONFIGS) {
        $self->{AppConfig}->define($var, {
                ARGCOUNT => AppConfig::ARGCOUNT_LIST,
            });
    }

    return $self;
}

# Autoload passthrough to AppConfig, see comments on new()
# for reasons why.
sub AUTOLOAD {
    my $self = shift;
    my $auto = our $AUTOLOAD;
    $auto =~ s/^PurpleWiki::Config:://;
    return if $auto eq 'DESTROY';
    return $self->{AppConfig}->get($auto);
}

# Creates the strings and regular expressions used for
# link matching. 
#
# FIXME: with the parsers in place these are really 
# only used for checking to see if an incoming request
# is kosher, which makes these a bit redundant. The
# fat has been trimmed but it still leaves a fair 
# piece.
sub _initLinkPatterns {
    my $self = shift;
    my $LinkPattern;
    my $FreeLinkPattern;
    
    my ($UpperLetter, $LowerLetter, $AnyLetter, $LpA, $LpB, $QDelim);

    $UpperLetter = "[A-Z";
    $LowerLetter = "[a-z";
    $AnyLetter   = "[A-Za-z";

    if ($self->NonEnglish) {
        $UpperLetter .= "\xc0-\xde";
        $LowerLetter .= "\xdf-\xff";
        $AnyLetter   .= "\xc0-\xff";
    }

    if (!$self->SimpleLinks) {
        $AnyLetter .= "_0-9";
    }
    $UpperLetter .= "]"; $LowerLetter .= "]"; $AnyLetter .= "]";

    # Main link pattern: lowercase between uppercase, then anything
    $LpA = $UpperLetter . "+" . $LowerLetter . "+" . $UpperLetter
         . $AnyLetter . "*";
    # Optional subpage link pattern: uppercase, lowercase, then anything
    $LpB = $UpperLetter . "+" . $LowerLetter . "+" . $AnyLetter . "*";

    if ($self->UseSubpage) {
        # Loose pattern: If subpage is used, subpage may be simple name
        $LinkPattern = "((?:(?:$LpA)?\\/$LpB)|$LpA)";
        # Strict pattern: both sides must be the main LinkPattern
        # $LinkPattern = "((?:(?:$LpA)?\\/)?$LpA)";
    } else {
        $LinkPattern = "($LpA)";
    }

    $QDelim = '(?:"")?';     # Optional quote delimiter (not in output)
    $LinkPattern .= $QDelim;

    if ($self->FreeLinks) {
        # Note: the - character must be first in $AnyLetter definition
        if ($self->NonEnglish) {
            $AnyLetter = "[-,.()' _0-9A-Za-z\xc0-\xff]";
        } else {
            $AnyLetter = "[-,.()' _0-9A-Za-z]";
        }
    }

    $FreeLinkPattern = "($AnyLetter+)";

    if ($self->UseSubpage) {
        $FreeLinkPattern = "((?:(?:$AnyLetter+)?\\/)?$AnyLetter+)";
    }
    $FreeLinkPattern .= $QDelim;

    $self->{AppConfig}->set('FreeLinkPattern', $FreeLinkPattern);
    $self->{AppConfig}->set('LinkPattern', $LinkPattern);

}

  
1;
