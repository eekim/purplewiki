#
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
