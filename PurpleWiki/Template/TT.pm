# PurpleWiki::Template::TT.pm
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

package PurpleWiki::Template::TT;

use 5.005;
use strict;
use base 'PurpleWiki::Template::Base';
use IO::Select;
use IPC::Open3;
use Template;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

# command-line version of PHP
my $PHP = '/home/eekim/www/local/bin/php';

sub process {
    my $self = shift;
    my $file = shift;
    my $template = Template->new({ INCLUDE_PATH => [ $self->templateDir ],
				   POST_CHOMP => 1,
                                   FILTERS => { 'php' => \&_phpFilter } }) ||
        die Template->error(), "\n";
    my $output;

    if ($template->process("$file.tt", $self->vars, \$output)) {
        return $output;
    } else {
        die $template->error(), "\n";
    }
    # FIXME: Need to exit gracefully if error is returned.
}

sub _phpFilter {
    my $text = shift;
    my $newText;
    my ($cmd_in, $cmd_out, $cmd_err);

    ### Perl Cookbook (2nd ed) Recipe 16.9
    my $pid = open3($cmd_in, $cmd_out, $cmd_err, $PHP);
#    $SIG{CHLD} = sub {
#        print "REAPER: status $? on $pid\n" if waitpid($pid, 0) > 0
#    };
    print $cmd_in $text;
    close $cmd_in;

    my $selector = IO::Select->new;
    $selector->add($cmd_err, $cmd_out);
    while (my @ready = $selector->can_read) {
        foreach my $fh (@ready) {
            if (defined $cmd_err && (fileno($fh) == fileno($cmd_err)) ) {
                # do something with STDERR
            }
            else {
                $newText .= scalar <$cmd_out>;
            }
            $selector->remove($fh) if eof($fh);
        }
    }
    close $cmd_out if defined $cmd_out;
    close $cmd_err if defined $cmd_err;
    return $newText;
}

1;
__END__

=head1 NAME

PurpleWiki::Template::TT - Template Toolkit template driver.

=head1 SYNOPSIS

  use PurpleWiki::Template::TT;

=head1 DESCRIPTION



=head1 FILTERS

php filter

=head1 METHODS

=head2 process($file)

Returns the root StructuralNode object.


=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
