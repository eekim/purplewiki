package Pod::SAX::PurpleWiki;
use strict;
use warnings;
use base 'XML::SAX::Base';
$| = 1;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{wikitext} = "";
    $self->{metadata} = $args{metadata} || {};
    $self->{nowiki} ||= [];
    for my $item (@{$self->{nowiki}}) {
        $self->{"nowiki_$item"} = 1;
    }
    return $self;
}

sub start_document {
    my $self = shift;
    for my $key (keys %{$self->{metadata}}) {
        $self->{wikitext} .= "{$key " . $self->{metadata}->{$key} . "}\n";
    }
    $self->{pre} = 0;
    $self->{waspre} = 0;
}

sub end_document {
    my $self = shift;
    $self->end_verbatim() if $self->{waspre};
    if (ref($self->{output}) eq 'SCALAR') {
        ${$self->{output}} = $self->{wikitext} || "";
    }
}

sub start_element {
    my ($self, $ele) = @_;
    my $name = $ele->{LocalName};

    $self->end_verbatim() if $name ne 'verbatim' and $self->{waspre};

    if ($name  =~ /^head(\d+)$/) {
        $self->{wikitext} .= "\n" . "="x$1 . " ";
        if ($self->{"nowiki_head$1"}) {
            $self->{wikitext} .= "<nowiki>";
        }
    } elsif ($name eq 'para') {
        if ($self->{inlistitem}) {
            $self->{wikitext} .= ": ";
        } else {
            $self->{wikitext} .= "\n";
        }
        $self->{wikitext} .= "<nowiki>" if $self->{"nowiki_para"};
    } elsif ($name eq 'verbatim' and not $self->{waspre}) {
        $self->{wikitext} .= "\n{{{\n";
        $self->{pre} = 1;
        if ($self->{"nowiki_verbatim"}) {
            $self->{wikitext} .= "    <nowiki>\n";
        }
    } elsif ($name eq 'verbatim' and $self->{waspre}) {
        $self->{wikitext} .= "\n";
    } elsif ($name eq 'itemizedlist') {
        $self->{list} = ';';
    } elsif ($name eq 'orderedlist') {
        $self->{list} = '#';
    } elsif ($name eq 'listitem') {
        $self->{inlistitem} = 1 if $self->{list} eq ';';
        $self->{wikitext} .= "\n" . $self->{list} . " ";
    } elsif ($name eq 'B') {
        $self->{wikitext} .= "'''";
    } elsif ($name eq 'I') {
        $self->{wikitext} .= "''";
    } elsif ($name eq 'C') {
        $self->{wikitext} .= "<tt>";
    } elsif ($name eq 'F') {
        $self->{wikitext} .= "<tt>";
    } elsif ($name eq 'link') {
        $self->{wikitext} .= "<tt>";
    } 
}

sub end_element {
    my ($self, $ele) = @_;
    my $name = $ele->{LocalName};
    if ($name  =~ /^head(\d+)$/) {
        if ($self->{"nowiki_head$1"}) {
            $self->{wikitext} .= "</nowiki>";
        }
        $self->{wikitext} .= " " . "="x$1;
    } elsif ($name eq 'para') {
        if ($self->{"nowiki_para"}) {
            $self->{wikitext} .= "</nowiki>";
        }
    } elsif ($name eq 'verbatim') {
        $self->{waspre} = 1;
    } elsif ($name eq 'itemizedlist') {
        $self->{list} = '';
    } elsif ($name eq 'orderedlist') {
        $self->{list} = '';
    } elsif ($name eq 'listitem') {
        $self->{inlistitem} = 0;
    } elsif ($name eq 'B') {
        $self->{wikitext} .= "'''";
    } elsif ($name eq 'I') {
        $self->{wikitext} .= "''";
    } elsif ($name eq 'C') {
        $self->{wikitext} .= "</tt>";
    } elsif ($name eq 'F') {
        $self->{wikitext} .= "</tt>";
    } elsif ($name eq 'link') {
        $self->{wikitext} .= "</tt>";
    }
}

sub characters {
    my ($self, $content) = @_;
    if ($self->{pre}) {
        for my $line (split /\n/, $content->{Data}) {
            $self->{wikitext} .= " "x4 . $line . "\n";
        }
    } else {
        chomp $content->{Data} if $self->{inlistitem};
        $self->{wikitext} .= $content->{Data};
    }
}

sub end_verbatim {
    my $self = shift;
    if ($self->{"nowiki_verbatim"}) {
        $self->{wikitext} .= "\n    </nowiki>";
    }
    $self->{wikitext} .= "\n}}}\n";
    $self->{waspre} = 0;
    $self->{pre} = 0;
}


1;
