# PurpleWiki::Archive::Sequence
# vi:sw=4:ts=4:ai:sm:et:tw=0
#
# $Id$
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

our $VERSION;
$VERSION = sprintf("%d", q$Id$ =~ /\s(\d+)\s/);

use PurpleWiki::View::Filter;
package PurpleWiki::Archive::Sequence;

sub getCurrentValue {
  my $pages = shift;
  my $seq = _getSequencer($pages);
  $seq->getCurrentValue();
}

sub setCurrentValue {
  my $pages = shift;
  my $value = shift;
  my $seq = _getSequencer($pages);
  $seq->setCurrentValue($value);
}

sub updateNIDs {
  my ($pages, $url, $tree, $maxRef) = @_;
  $tree = $pages->getPage($tree)->getTree() unless (ref($tree));
  my $seq = _getSequencer($pages);
  my @nids;
  my $filter = PurpleWiki::View::Filter->new(
    useOO => 1,
    start => sub {
      shift->{nids} = \@nids;
    }
  );
  $filter->setFilters(Main =>
    sub {
      my $pages = shift;
      my $node = shift;
      my $nid = $node->id();
      push (@{$pages->{nids}}, $nid) if $nid;
    }
  );
  $filter->process($tree);

  $seq->updateURL($url, \@nids);
  if ($maxRef) {
    my $max = $$maxRef;
    for my $nid (@nids) {
      $max = $nid if ($seq->compareNID($max, $nid) < 0);
    }
    $$maxRef = $max;
  }
}

sub _getSequencer {
  my $pages = shift;
  my $ret;
  return $ret if (defined($ret = $pages->{sequence}));

  $pages->{sequence} = new PurpleWiki::Sequence($pages->{seqdir}, $pages->{sequrl});
}

1;
__END__

=head1 NAME

PurpleWiki::Archive::Sequence - 

=head1 DESCRIPTION



=head1 METHODS

=head2 getCurrentValue($pages)



=head2 setCurrentValue($pages, $value)



=head2 updateNIDs($pages, $url, $tree, $maxRef)



=head1 AUTHOR

Gerry Gleason, E<lt>gerry@geraldgleason.comE<gt>

=head1 SEE ALSO

L<PurpleWiki::Sequence>.

=cut
