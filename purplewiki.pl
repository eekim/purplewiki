#!/usr/bin/perl

use IO::File;
use PurpleWiki::Tree;

if (@ARGV < 1) {
  print "Usage: $0 wikifile.txt [output_driver]\n";
  exit;
}

my $wikiContent = &readFile($ARGV[0]);
my $wiki = PurpleWiki::Tree->new('title'=>$ARGV[0]);

$wiki->parse($wikiContent);

if (@ARGV == 2) {
    $wiki->view($ARGV[1]);
}
else {
    $wiki->view('Debug');
}

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
