package PurpleWiki::InlineNode;

use strict;

### constructor

sub new {
    my $this = shift;
    my (%attrib) = @_;
    my $self = {};

    # TODO: Type checking.
    $self->{'type'} = $attrib{'type'} if ($attrib{'type'});
    $self->{'href'} = $attrib{'href'} if ($attrib{'href'});
    $self->{'content'} = $attrib{'content'} if ($attrib{'content'});
    $self->{'children'} = $attrib{'children'} if ($attrib{'children'});
    bless $self, $this;
    return $self;
}

### accessors/mutators

sub type {
    my $this = shift;

    $this->{'type'} = shift if @_;
    return $this->{'type'};
}

sub href {
    my $this = shift;

    $this->{'href'} = shift if @_;
    return $this->{'href'};
}

sub content {
    my $this = shift;

    $this->{'content'} = shift if @_;
    return $this->{'content'};
}

sub children {
    my $this = shift;

    $this->{'children'} = shift if @_;
    return $this->{'children'};
}

sub populate {
    my $this = shift;
    my $contentRef = shift;

    # TODO: type checking
    if (scalar @{$contentRef} > 1) {
        $this->{'children'} = $contentRef;
    }
    else {
        $this->{'content'} = $contentRef->[0];
    }
}

1;
