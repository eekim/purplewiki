# wikihtml.t

use strict;
use warnings;
use Test;
use Text::Diff;

BEGIN { plan tests => 13 };

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

my $config = new PurpleWiki::Config($configdir);
my $wikiParser = PurpleWiki::Parser::WikiText->new;
my ($input, $output, $shouldBe, $wiki, $diff);

my $database_package = $config->DatabasePackage
                         || "PurpleWiki::Database::Page";
eval "require $database_package";
$database_package .= "s" unless ($database_package =~ /s$/);
my $pages = $database_package->new ($config);
$config->{pages} = $pages;

# FIXME: move those files not yet used into the live @files
#        as willpower allows.
#my @files = qw(tree_freelinks tree_hr tree_interlinks tree_lists tree_pre
#               tree_test01 tree_test02 tree_test03
#               tree_test04 tree_test05 tree_test06 tree_test07 tree_test08
#               tree_test09 tree_test11 tree_test12
#               hr1 hr2 hr3 hr4 hr5 hr6 hr7);
my @files = qw(hr1 hr2 hr3 hr4 hr5 hr6 hr7
               tree_hr tree_freelinks tree_lists tree_pre tree_mixedlists
               tree_test01);

foreach my $filename (@files) {
    print $filename, "\n";
    $input = &readFile("t/txt/$filename.txt");
    $shouldBe = &readFile("t/output/$filename.html");
    $wiki = $wikiParser->parse($input);
    $output = $wiki->view('wikihtml');
    $diff = Text::Diff::diff(\$shouldBe, \$output, {STYLE => 'Unified'});
    ok($diff, '');
}
