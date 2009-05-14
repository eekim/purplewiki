#!/usr/bin/perl
#
# mediawikiConvert.pl - Converts to MediaWiki
#
# 1. Output each revision as PurpleWiki.
# 2. Output a copy of the current revision for each page as MediaWiki.
# 3. Output as MediaWiki dump format.

package UseModWiki;  # nasty hack

use lib '/home/eekim/devel/ChurchOfPurple/PurpleWiki/trunk';
use strict;
use DB_File;
use PurpleWiki::Archive::PlainText;
use PurpleWiki::Config;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::UserDB::UseMod;

my $data_dir = $ARGV[0];
my $config = new PurpleWiki::Config($data_dir);
my $user_dir = '/home/eekim/convert/user';
my $username = &get_username_hash($user_dir);
my $pagemap_file = '/home/eekim/convert/pagemap.txt';
my $page_map = &get_page_map($pagemap_file);

&print_header;
my $pages = PurpleWiki::Archive::PlainText->new(DataDir => $data_dir);
for my $id ($pages->allPages) {
    print "  <page>\n";
    print "    <title>" . &convert_link_name($id) . "</title>\n";
    my @revisions = $pages->getRevisions($id);
    push(@revisions, { revision => 1 + scalar @revisions,
                       dateTime => time,
                       userId => 1002,
                       summary => 'Converted from PurpleWiki'
                     });
    for my $page (@revisions) {
        print "    <revision>\n";
        print "      <id>" . $page->{revision} . "</id>\n";
        print "      <timestamp>" . &timestamp($page->{dateTime}) . "</timestamp>\n";
        print "      <contributor>\n";
#        print "        <id>" . $page->{userId} . "</id>\n";
        my $u = $username->{$page->{userId}};
        print "        <username>$u</username>\n" if $u;
        print "        <ip>" . $page->{host} . "</ip>\n" if $page->{host};
        print "      </contributor>\n";
        print "      <comment>" . &escape_html($page->{summary}) . "</comment>\n"
          if $page->{summary};
        print "      <text xml:space=\"preserve\"><![CDATA[";
        my $page_text;
        if ($page->{revision} == scalar @revisions) {
            # Convert to MediaWiki WikiText
            my $p = $pages->getPage($id, $page->{revision} - 1);
            $page_text = $p->getTree->view('mediawiki', pagemapFile => $pagemap_file);
        }
        else {
            my $p = $pages->getPage($id, $page->{revision});
            $page_text = $p->getTree->view('wikitext');
        }
        print &strip_special_chars($page_text);
        print "]]></text>\n";
        print "    </revision>\n";
    }
    print "  </page>\n";
}
&print_footer;

### fini

sub strip_special_chars {
    my $text = shift;
    $text =~ s/\x{85}/.../g;
    $text =~ s/\x{87}/>/g;
    $text =~ s/\x{92}/\'/g;
    $text =~ s/\x{93}/\"/g;
    $text =~ s/\x{94}/\"/g;
    $text =~ s/\x{95}/*/g;
    $text =~ s/\x{96}/--/g;
    $text =~ s/ï/i/g;
    return $text;
}

sub convert_link_name {
    my $page_name = shift;
    if ($page_map->{$page_name}) {
        return $page_map->{$page_name};
    }
    else {
        $page_name =~ s/([A-Z])/ $1/g;
        $page_name =~ s/^ *//;
        $page_name =~ s/\# /\#/;
        return $page_name;
    }
}

sub get_page_map {
    my $page_map = shift;
    my %pm;
    open(PM, $page_map);
    while (<PM>) {
        chomp;
        my ($key, $val) = split(/:/);
        $pm{$key} = $val;
    }
    close(PM);
    return \%pm;
}

sub get_username_hash {
    my $user_dir = shift;
    my $userDb = new PurpleWiki::UserDB::UseMod;
    my %users;
    my %usernames;
    tie %users, "DB_File", "$user_dir/usernames.db", O_RDONLY, 0444, $DB_HASH;
    foreach my $username (keys %users) {
        $usernames{$users{$username}} = ucfirst($username);
    }
    untie %users;
    return \%usernames;
}

sub escape_html {
    my $text = shift;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
#    $text =~ s/&/&amp;amp;/g;
    return $text;
}

sub timestamp {
    my @t = localtime(28800 + shift); # PT -> UTC
    return sprintf("%d-%02d-%02dT%02d:%02d:%02dZ", $t[5] + 1900, $t[4] + 1,
                   $t[3], $t[2], $t[1], $t[0]);
}

sub print_header {
    print '<mediawiki xmlns="http://www.mediawiki.org/xml/export-0.3/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.mediawiki.org/xml/export-0.3/ http://www.mediawiki.org/xml/export-0.3.xsd" version="0.3" xml:lang="en">';
    print "\n";
}

sub print_footer {
    print "</mediawiki>\n";
}

### more nasty hack

sub TimeToText { return shift; }
sub QuoteHtml { return shift; }
