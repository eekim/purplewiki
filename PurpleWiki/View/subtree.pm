package PurpleWiki::View::subtree;
use 5.005;
use strict;
use warnings;
use PurpleWiki::View::Driver;
use Data::Dumper;

############### Package Globals ###############

our $VERSION = '0.9.1';

our @ISA = qw(PurpleWiki::View::Driver);


############### Overloaded Methods ###############

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    die "No nid given to PurpleWiki::View::subtree()\n" 
        unless defined $self->{nid};

    # Object State
    $self->{nidFound} = 0;
    $self->{newChildren} = [];

    bless($self, $class);
    return $self;
}

sub view {
    my ($self, $wikiTree) = @_;

    $self->SUPER::view($wikiTree);

    return $self;
}

sub getSubTree {
    my $self = shift;
    return $self->{subtree};
}

sub traverse {
    my ($self, $nodeListRef) = @_;
    my $nidFound = 0;

    if (not defined $nodeListRef) {
        warn "Warning: tried to traverse on an undefined list\n";
        return;
    }

    foreach my $nodeRef (@{$nodeListRef}) {
        $self->processNode($nodeRef) if defined $nodeRef;

        if ($self->{nidFound}) {
	    $self->{subtree} = $nodeRef;
	    $self->{nidFound} = 0;
	    last;
        }

    }
}

sub Post {
    my ($self, $nodeRef) = @_;
    if ($nodeRef->isa('PurpleWiki::StructuralNode') and defined $nodeRef->id) {
        if ($nodeRef->id eq $self->{nid}) {
            $self->{nidFound} = 1;
        }
    }
}

1;
__END__
