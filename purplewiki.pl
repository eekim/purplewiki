#!/usr/bin/perl

use IO::File;
use PurpleWiki::Tree;

if (@ARGV < 1) {
  print "Usage: $0 wikifile.txt\n";
  exit;
}

my $wikiContent = &readFile($ARGV[0]);
my $wiki = PurpleWiki::Tree->new('title'=>$ARGV[0]);

$wiki->parse($wikiContent);

$wiki->view('XHTML');
#$wiki->view('XHTML','collapse'=>[2]);
#$wiki->view('Text');
#$wiki->view('Purple');
#$wiki->view('Wiki');

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
