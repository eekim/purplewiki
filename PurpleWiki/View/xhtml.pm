package PurpleWiki::View::xhtml;
use 5.005;
use strict;
use warnings;
use PurpleWiki::View::Driver;
use PurpleWiki::View::wikihtml;

############### Package Globals ###############

our $VERSION = '0.9.1';

# Note that we don't inherit directly from Driver.pm like the other drivers.
our @ISA = qw(PurpleWiki::View::wikihtml); 


############### Overloaded Methods ###############

sub view {
    my ($self, $wikiTree) = @_;

    $self->SUPER::view($wikiTree);
    $self->{outputString} = $self->_htmlHeader($wikiTree) .
                            $self->{outputString} . $self->_htmlFooter();

    return $self->{outputString};
}


############### Private Methods ###############

sub _htmlHeader {
    my ($self, $wikiTree) = @_;
    my $outputString;

    $outputString = qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 ) .
       qq(Strict//EN"\n) .
       qq("http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\n) .
       qq(<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">) .
       qq(<head>\n);
    $outputString .= '<title>' . $wikiTree->title . "</title>\n"
        if ($wikiTree->title);
    if ($self->{params}->{css_file}) {
        $outputString .= '<link rel="stylesheet" href="';
        $outputString .= $self->{params}->{css_file};
        $outputString .= '" type="text/css" />' . "\n";
    }
    $outputString .= "</head>\n<body>\n";
    if ($wikiTree->title) {
        $outputString .= '<h1 class="title">';
        $outputString .= $wikiTree->title;
        $outputString .= "</h1>\n";
    }
    if ($wikiTree->subtitle) {
        $outputString .= '<h2 class="subtitle">';
        $outputString .= $wikiTree->subtitle;
        $outputString .= "</h2>\n";
    }
    if ($wikiTree->authors) {
        $outputString .= '<p class="authors">';
        foreach my $author (@{$wikiTree->authors}) {
            $outputString .= $author->[0];
            $outputString .= ' &lt;' . $author->[1] . '&gt;'
                if (scalar @{$author} > 1);
            $outputString .= "<br />\n";
        }
        $outputString .= "</p>\n";
    }
    if ($wikiTree->id || $wikiTree->version || $wikiTree->date) {
        $outputString .= '<p class="docinfo">';
        if ($wikiTree->id) {
            $outputString .= $wikiTree->id;
            if ($wikiTree->version) {
                $outputString .= "<br />\n";
            }
        }
        if ($wikiTree->version) {
            $outputString .= $wikiTree->version;
            if ($wikiTree->date) {
                $outputString .= "<br />\n";
            }
        }
        $outputString .= $wikiTree->date if ($wikiTree->date);
        $outputString .= "</p>\n";
    }
    return $outputString;
}

sub _htmlFooter {
    return "</body>\n</html>\n";
}
1;
__END__
