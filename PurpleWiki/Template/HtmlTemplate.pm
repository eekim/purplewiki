# PurpleWiki::Template::HtmlTemplate.pm
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

package PurpleWiki::Template::HtmlTemplate;

use strict;
use base 'PurpleWiki::Template::Base';
use HTML::Template;

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

sub process {
    my $self = shift;
    my $file = shift;
    my $template = new HTML::Template(filename => "$file.ht",
                                      path => [ $self->templateDir ],
                                      global_vars => 1,
                                      die_on_bad_params => 0); 

    $template->param($self->vars);
    #print STDERR $template->param(), "\n";

    return $template->output();
    # FIXME: Need to exit gracefully if error is returned.
}

1;
__END__

=head1 NAME

PurpleWiki::Template::HtmlTemplate - HTML Template template driver.

=head1 SYNOPSIS

  use PurpleWiki::Template::HtmlTemplate;

=head1 DESCRIPTION



=head1 METHODS

=head2 process($file)

Returns the content of the processed template, as a string.


=head1 AUTHORS

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>
Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

=cut
