# viewer09.t

# test that the wikitext viewer is doign something like the right
# thing. written because it was not

use strict;
use Test;

BEGIN { plan tests => 1 };

use IO::File;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::Config;
my $configdir = 't';

sub readFile {
    my $fileName = shift;
    my $fileContent;

    my $fh = new IO::File $fileName;
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

#########################

### viewer_text01.txt -- hard rules

my $config = new PurpleWiki::Config($configdir);
my $wikiContent = &readFile('t/viewer_test01.txt');
my $wikiParser = PurpleWiki::Parser::WikiText->new;
my $wiki = $wikiParser->parse($wikiContent, config => $config);
my $wikitext = $wiki->view('wikitext', config => $config);

{
    my $content = $wikiContent;
    my $text = $wikitext;
    $content =~ s/^\s+//gs;
    $text =~ s/^\s+//gs;
    $content =~ s/\s+$//gs;
    $text =~ s/\s+$//gs;
    ok($content eq $text);
    print $content, "\n\n";
    print $text, "\n\n";
}

