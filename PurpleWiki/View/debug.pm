package PurpleWiki::View::debug;
use 5.005;
use strict;
use warnings;
use PurpleWiki::View::Driver;

############### Package Globals ###############

our $VERSION = '0.9.1';

our @ISA = qw(PurpleWiki::View::Driver);


############### Overloaded Methods ###############

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    # Object State
    $self->{outputString} = "";
    $self->{indentLevel} = 0;

    bless($self, $class);
    return $self;
}

sub view {
    my ($self, $wikiTree) = @_;
    $self->SUPER::view($wikiTree);

    my $title = $wikiTree->title || '';

    $self->{outputString} = 'title:' . $title . "\n" . 
                             $self->{outputString};
    return $self->{outputString};
}

sub Main {
    my ($self, $nodeRef) = @_;
    if ($nodeRef->type =~ /^(section|indent|ul|ol|dl)$/) {
        $self->{indentLevel}++;
    }
}

sub Post {
    my ($self, $nodeRef) = @_;
    if ($nodeRef->type =~ /^(section|indent|ul|ol|dl)$/) {
        $self->{indentLevel}--;
    }
}

sub sectionPre { shift->_headingWithNewline(@_) }
sub indentPre { shift->_headingWithNewline(@_) }
sub ulPre { shift->_headingWithNewline(@_) }
sub olPre { shift->_headingWithNewline(@_) }
sub dlPre { shift->_headingWithNewline(@_) }

sub hPre { shift->_heading(@_) }
sub pPre { shift->_heading(@_) }
sub liPre { shift->_heading(@_) }
sub ddPre { shift->_heading(@_) }
sub dtPre { shift->_heading(@_) }
sub prePre { shift->_heading(@_) }
sub sketchPre { shift->_heading(@_) }

sub bPre { shift->{outputString} .= uc(shift->type) . ':' }
sub iPre { shift->{outputString} .= uc(shift->type) . ':' }
sub ttPre { shift->{outputString} .= uc(shift->type) . ':' }
sub nowikiPre { shift->{outputString} .= uc(shift->type) . ':' }
sub transclusionPre { shift->{outputString} .= uc(shift->type) . ':' }
sub linkPre { shift->{outputString} .= uc(shift->type) . ':' }
sub urlPre { shift->{outputString} .= uc(shift->type) . ':' }
sub wikiwordPre { shift->{outputString} .= uc(shift->type) . ':' }
sub freelinkPre { shift->{outputString} .= uc(shift->type) . ':' }
sub imagePre { shift->{outputString} .= uc(shift->type) . ':' }

sub textMain { shift->{outputString} .= shift->content . "\n" }
sub nowikiMain { shift->{outputString} .= shift->content . "\n" }
sub transclusionMain { shift->{outputString} .= shift->content . "\n" }
sub linkMain { shift->{outputString} .= shift->content . "\n" }
sub urlMain { shift->{outputString} .= shift->content . "\n" }
sub wikiwordMain { shift->{outputString} .= shift->content . "\n" }
sub freelinkMain { shift->{outputString} .= shift->content . "\n" }
sub imageMain { shift->{outputString} .= shift->content . "\n" }


############### Private Methods ###############

sub _heading {
    my ($self, $nodeRef) = @_;
    $self->{outputString} .= ' 'x(2 * $self->{indentLevel});
    $self->{outputString} .= $nodeRef->type.":";
}

sub _headingWithNewline {
    my ($self, $nodeRef) = @_;
    $self->{outputString} .= ' 'x(2 * $self->{indentLevel});
    $self->{outputString} .= $nodeRef->type.":\n";
}
1;
__END__
