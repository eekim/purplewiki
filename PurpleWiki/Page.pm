package PurpleWiki::Page;

# mappings between PurpleWiki code and code withing useMod

# $Id: Page.pm,v 1.1 2002/10/23 05:53:06 cdent Exp $

sub getWikiWordLink {
    my $id = shift;

    my $results = &UseModWiki::GetPageOrEditLink($id, '');

    return _makeURL($results);;

}

sub getInterWikiLink {
    my $id = shift;
    
    my $results = (&UseModWiki::InterPageLink($id, ''))[0];

    return _makeURL($results);

}

sub getFreeLink {
    my $id = shift;

    #my $results = &UseModWiki::StorePageOrEditLink($id, '');
    my $results = (&UseModWiki::GetPageOrEditLink($id, ''))[0];
    print STDERR "freelink: $results\n";
    return _makeURL($results);

}

                  

sub _makeURL {
    my $string = shift;
    return ($string =~ /\"([^\"]+)\"/)[0];
}



1;

