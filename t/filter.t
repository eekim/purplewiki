# filter.t
# vi:sw=4:ts=4:ai:sm:et

use strict;
use warnings;
use Test;

# A rudimentary test of PurpleWiki::View::Filter to see that
# it works as advertised.

BEGIN { plan tests => 5};

#use lib '.'; # makes this test runnable alone from the base of the dist
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Config;
use PurpleWiki::View::Filter;

my $configdir = 't';
my $content=<<"EOF";
Hello this is a wiki page, using WikiPage as a WikiWord.

== Header Injection ==

* this is a list one
* this is a list two

[http://www.burningchrome.com/ this is a link]

EOF
# parse content
my $config = new PurpleWiki::Config($configdir);
my $parser = PurpleWiki::Parser::WikiText->new();
my $wiki = $parser->parse($content, add_node_ids => 1);
my @nids;
my $filter = PurpleWiki::View::Filter->new(
  useOO => 1,
  start => sub {
    shift->{nids} = \@nids;
  }
);
$filter->setFilters(Main =>
  sub {
    my $self = shift;
    my $node = shift;
    my $nid = $node->id();
    push (@{$self->{nids}}, $nid) if $nid;
  }
);
$filter->process($wiki);

my $i = 1;
foreach (@nids) {
    ok($_ == $i++);
}

sub END {
    unlink('tDB/sequence');
}
