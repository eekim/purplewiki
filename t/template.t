# template.t

use strict;
use warnings;
use Test;

BEGIN { plan tests => 3 };

use PurpleWiki::Config;
use PurpleWiki::Template::Base;

my $configdir = 't';
my $config = PurpleWiki::Config->new($configdir);

# MANIFEST doesn't allow you to specify directories.  So, we need to
# make sure that the appropriate directories exist, and if they don't,
# we need to make them.
mkdir "$configdir/templates" if (!-d "$configdir/templates");
mkdir "$configdir/templates/en" if (!-d "$configdir/templates/en");
mkdir "$configdir/templates/fr" if (!-d "$configdir/templates/fr");

#########################

# Don't specify a language
my $template = PurpleWiki::Template::Base->new;
ok($template->language, 'en');

# Specify German first, then French, then English
my @languages = ('de', 'fr', 'en');
$template->language('de', 'fr', 'en');
ok($template->language, 'fr');

# Specify Germn
$template->language('de');
ok($template->language, 'en');
