package PurpleWiki::StructuralNode;

use strict;
use PurpleWiki::InlineNode;

### constructor

sub new {
    my $this = shift;
    my (%attrib) = @_;
    my $self = {};

    # TODO: Type checking.
    $self->{'type'} = $attrib{'type'} if ($attrib{'type'});
    $self->{'id'} = $attrib{'id'} if ($attrib{'id'});
    $self->{'content'} = $attrib{'content'} if ($attrib{'content'});
    bless $self, $this;
    return $self;
}

### methods

sub insertChild {
    my $this = shift;
    my (%attrib) = @_;

    my $newNode = PurpleWiki::StructuralNode->new(%attrib);
    $newNode->{'parent'} = $this;
    push(@{$this->{'children'}}, $newNode);
    return $newNode;
}

sub parent {
    my $this = shift;
    return $this->{'parent'};
}

sub children {
    my $this = shift;
    if ($this->{'children'}) {
        return $this->{'children'};
    }
    else {
        return undef;
    }
}

### accessors/mutators

sub type {
    my $this = shift;

    $this->{'type'} = shift if @_;
    return $this->{'type'};
}

sub id {
    my $this = shift;

    $this->{'id'} = shift if @_;
    return $this->{'id'};
}

sub content {
    my $this = shift;

    $this->{'content'} = shift if @_;
    return $this->{'content'};
}

1;
