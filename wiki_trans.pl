#!/usr/bin/perl

use IO::File;
use PurpleWiki::Parser::WikiText;

if (@ARGV < 1) {
  print "Usage: $0 wikifile.txt [output_driver]\n";
  exit;
}

my $wikiContent = &readFile($ARGV[0]);
my $wikiParser = PurpleWiki::Parser::WikiText->new;
my $wiki = $wikiParser->parse($wikiContent, 'add_node_ids'=>1);
$wiki->title($ARGV[0]);

if (@ARGV == 2) {
    print $wiki->view($ARGV[1]);
}
else {
    print $wiki->view('Debug');
}

#$wiki->view('XHTML','collapse'=>[2]);

# fini

### functions

sub readFile {
    my $fileName = shift;
    my $fileContent;

    $fh = new IO::File $fileName;
    if (defined $fh) {
        local ($/);
        $fileContent = <$fh>;
        $fh->close;
        return $fileContent;
    }
    else {
        return;
    }
}
