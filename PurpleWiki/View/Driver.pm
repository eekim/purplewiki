# PurpleWiki::View::Driver.pm
#
# $Id$
#
# Copyright (c) Blue Oxen Associates 2002-2004.  All rights reserved.
#
# This file is part of PurpleWiki.  PurpleWiki is derived from:
#
#   UseModWiki v0.92          (c) Clifford A. Adams 2000-2001
#   AtisWiki v0.3             (c) Markus Denker 1998
#   CVWiki CVS-patches        (c) Peter Merel 1997
#   The Original WikiWikiWeb  (c) Ward Cunningham
#
# PurpleWiki is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA

package PurpleWiki::View::Driver;
use 5.005;
use strict;
use warnings;
use Carp;
use PurpleWiki::Tree;

######## Package Globals ########

our $VERSION = '0.9.1';

# This probably belongs in StructuralNode.pm
our @structuralNodeTypes = qw(document section indent ul ol dl h p li dd dt 
                              pre sketch);

# This probably belongs in InlineNode.pm
our @inlineNodeTypes = qw(b i tt text nowiki transclusion link url wikiword 
                          freelink image);

# I don't know where this belongs, but here is as good a place as any.
our @allNodeTypes = (@structuralNodeTypes, @inlineNodeTypes);

# Used to quickly see if a node type is valid, we need to do this in AUTOLOAD
# and so we make this a package global so as to incur the cost only once.
our %lookupTable = map { $_ => 1 } @allNodeTypes;


######## Public Methods ########

# Create a new driver.  The only required parameter is a config => config obj.
# which gives us access to the PurpleWiki::Config object.
sub new {
    my $proto = shift;
    my $self = { @_ };
    my $class = ref($proto) || $proto;

    # Make sure we were given a PurpleWiki::Config object.
    croak "PurpleWiki::Config object not found\n" unless $self->{config};

    # Object state.
    $self->{depth} = 0;

    bless($self, $class);
    return $self;
}

# View starts the processing of the PurpleWiki::Tree and returns the
# finished string.
sub view {
    my ($self, $wikiTree) = @_;
    $self->processNode($wikiTree->root) if defined $wikiTree->root;
}

# Recurse decends down the PurpleWiki::Tree depth first.  Structural nodes
# have two kinds of children: Inline and Structural, so we need to process
# the Inline children of a Structural Node seperately.
sub recurse {
    my ($self, $nodeRef) = @_;

    # recurse() should never be called on an undefined node.
    if (not defined $nodeRef) {
        carp "Warning: tried to recurse on an undefined node\n";
        return;
    }

    if ($nodeRef->isa('PurpleWiki::StructuralNode')) {
        $self->traverse($nodeRef->content) if defined $nodeRef->content;
    }

    $self->traverse($nodeRef->children) if defined $nodeRef->children;
}

# Traverse goes through a list of nodes calling their pre, main, and post
# handlers (in that order).  Recursion is depth first because the default
# main handler is recurse().
sub traverse {
    my ($self, $nodeListRef) = @_;

    # traverse() should never be called on an undefined node.
    if (not defined $nodeListRef) {
        carp "Warning: tried to traverse on an undefined node list\n";
        return;
    }
  
    foreach my $nodeRef (@{$nodeListRef}) {
        $self->processNode($nodeRef) if defined $nodeRef;
    }
}

# Call the pre, main, and post handlers for a specific node, as well as the
# generic structural/inline pre, main, and post handlers.
sub processNode {
    my ($self, $nodeRef) = @_;

    # processNode() should never be called on an undefined node.
    if (not defined $nodeRef) {
        carp "Warning: tried to process an undefined node\n";
        return;
    }

    # We have to construct each method name.  The method names are of the form
    # fooPre, fooMain, and fooPost where foo = $node->type.
    my $nodePre = $nodeRef->type."Pre";
    my $nodeMain = $nodeRef->type."Main";
    my $nodePost = $nodeRef->type."Post";

    $self->{depth}++;

    # Run all the handlers
    $self->Pre($nodeRef);
    $self->$nodePre($nodeRef);

    $self->Main($nodeRef);
    $self->$nodeMain($nodeRef);

    $self->$nodePost ($nodeRef);
    $self->Post($nodeRef);

    $self->{depth}--;
}

# Noop == No Operation.  Just a little stub since it's used by most of
# the handlers.  Most handlers are a noop by default.
sub noop {
    return;
}

######## Private Methods ########

# The AUTOLOAD function captures calls to non-existant methods.  This allows
# us to define a default behavior for a whole set of methods without having
# to declare each one individually.  
#
# AUTOLOAD is passed in the method name that was called, but not found.  Two 
# checks are done to resolve the method name and if they both fail the method
# is considered unfound.  The checks are as follow:
#
#       1) See if method name is is exactly equal to "Pre", "Main", or "Post"
#          and if it is call the noop method, which is the default behavior
#          for these methods.
#
#       2) Pattern match the method name pulling out the nodeType and opType
#          (opType is one of Pre, Main, or Post).  If the pattern match was
#          successful we just call the noop method for Pre and Post handlers,
#          and we call the recurse() method for Main handlers.
sub AUTOLOAD {
    our $AUTOLOAD;
    my $self = shift;
    my $method = $AUTOLOAD;

    # Remove all but the method name
    $method =~ s/(.*)://g;  # Reduces Foo::Bar::Baz::Quz::method to "method"

    # Bail on DESTROY, otherwise we'll cause an infinite loop when our object
    # is garbage collected.
    return if $method =~ /DESTROY/;

    # The generic Pre, Main, and Post handlers apply to every single node
    # and are noops by default, we just provide them for ease of use.
    if ($method eq "Pre" or $method eq "Main" or $method eq "Post") {
        $self->noop(@_);
        return;
    }  
    
    # Do a pattern match to see if $method is a node specific handler, and
    # extract out the nodeType and the opType if it is.
    if ($method =~ /^([a-z]+)(Pre|Main|Post)$/) {
        my ($nodeType, $opType) = ($1, $2);

        goto notFound if not exists $lookupTable{$nodeType};

        # Invoke the default behavior for undefined methods.
        if ($opType eq "Main") {
            $self->recurse(@_);  # fooMain handlers recurse by default
        } else {
            $self->noop(@_);  # fooPre/Post handlers are noops by default.
        }

        return;
    }

    notFound:
        croak "Could not locate $AUTOLOAD.\n";
}
1;
__END__

=head1 NAME

PurpleWiki::View::Driver - View driver base class

=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 METHODS

=head2 new(config => $config)



=head2 view($wikiTree)



=head2 recurse($nodeRef)



=head2 traverse($nodeListRef)



=head2 processNode($nodeRef)



=head2 noop()



=head1 AUTHOR

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

=cut
