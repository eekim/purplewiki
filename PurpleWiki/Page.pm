package PurpleWiki::Page;

# mappings between PurpleWiki code and code withing useMod

# $Id: Page.pm,v 1.3 2002/10/23 08:23:11 cdent Exp $

sub exists {
    my $id = shift;

    return &UseModWiki::pageExists($id);
}

sub getWikiWordLink {
    my $id = shift;

    my $results = &UseModWiki::GetPageOrEditLink($id, '');

    return _makeURL($results);

}

sub getInterWikiLink {
    my $id = shift;
    
    my $results = (&UseModWiki::InterPageLink($id, ''))[0];

    return _makeURL($results);

}

sub getFreeLink {
    my $id = shift;

    my $results = (&UseModWiki::GetPageOrEditLink($id, ''))[0];
    return _makeURL($results);

}

                  

sub _makeURL {
    my $string = shift;
    return ($string =~ /\"([^\"]+)\"/)[0];
}



1;
