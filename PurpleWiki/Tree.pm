# PurpleWiki::Tree.pm
#
# $Id: Tree.pm,v 1.24.2.1 2003/01/20 23:06:09 eekim Exp $
#
# Copyright (c) Blue Oxen Associates 2002-2003.  All rights reserved.
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

package PurpleWiki::Tree;

use 5.005;
use strict;
use PurpleWiki::StructuralNode;
use PurpleWiki::View::debug;
use PurpleWiki::View::text;
use PurpleWiki::View::wikihtml;
use PurpleWiki::View::wikitext;
use PurpleWiki::View::xhtml;

### constructor

sub new {
    my $this = shift;
    my (%options) = @_;
    my $self;

    $self = {};
    $self->{lastNid} = $options{lastNid} ? $options{lastNid} : undef;
    $self->{title} = $options{title} ? $options{title} : undef;
    $self->{subtitle} = $options{subtitle} ? $options{subtitle} : undef;
    $self->{id} = $options{id} ? $options{id} : undef;
    $self->{date} = $options{date} ? $options{date} : undef;
    $self->{version} = $options{version} ? $options{version} : undef;
    $self->{authors} = &_validateAuthors($options{authors})
	? $options{authors} : undef;

    $self->{rootNode} = PurpleWiki::StructuralNode->new(type=>'document');

    bless($self, $this);
    return $self;
}

### accessors/mutators

sub root {
    my $this = shift;

    return $this->{rootNode};
}

sub lastNid {
    my $this = shift;

    $this->{lastNid} = shift if @_;
    return $this->{lastNid};
}

sub title {
    my $this = shift;

    $this->{title} = shift if @_;
    return $this->{title};
}

sub subtitle {
    my $this = shift;

    $this->{subtitle} = shift if @_;
    return $this->{subtitle};
}

sub id {
    my $this = shift;

    $this->{id} = shift if @_;
    return $this->{id};
}

sub date {
    my $this = shift;

    $this->{date} = shift if @_;
    return $this->{date};
}

sub version {
    my $this = shift;

    $this->{version} = shift if @_;
    return $this->{version};
}

sub authors {
    my $this = shift;
    my $authors = shift;

    if (&_validateAuthors($authors)) {
	$this->{authors} = $authors;
    }
    return $this->{authors};
}

### methods

sub view {
    my $this = shift;
    my ($driver, %params) = @_;

    if (lc($driver) eq 'debug') {
        return &PurpleWiki::View::debug::view($this, %params);
    } 
    elsif (lc($driver) eq 'wikihtml') {
        return &PurpleWiki::View::wikihtml::view($this, %params);
    }
    elsif (lc($driver) eq 'wikitext') {
        return &PurpleWiki::View::wikitext::view($this, %params);
    }
    elsif (lc($driver) eq 'text') {
        return &PurpleWiki::View::text::view($this, %params);
    }
    elsif (lc($driver) eq 'xhtml') {
        return &PurpleWiki::View::xhtml::view($this, %params);
    }
}

### private

sub _validateAuthors {
    my $authors = shift;

    if ($authors && ref($authors) eq 'ARRAY') {
	foreach my $author (@{$authors}) {
	    if ( (ref($author) ne 'ARRAY') ||
		 (scalar @{$author} > 2) ||
		 (scalar @{$author} < 1) ) {
		return 0;
	    }
	}
	return 1;
    }
    else {
	return 0;
    }
}

1;
__END__

=head1 NAME

PurpleWiki::Tree - Basic PurpleWiki data structure

=head1 SYNOPSIS

  use PurpleWiki::Tree;

  my $wiki = PurpleWiki::Tree->new;

  $wiki->title("WikiPage");  # sets the title to "WikiPage"

  $wiki->lastNid(23);        # sets the last NID to 23
  print $wiki->lastNid;      # prints "23"

  $wiki->authors([ ['Joe Schmoe', 'joe@schmoe.net'],
                   ['Bob Marley', 'bob@jamaica.net'] ]);

  $wiki->root;               # returns the root StructuralNode

  $wiki->view('WikiHTML');   # serializes tree as XHTML

=head1 DESCRIPTION

PurpleWiki views Wiki pages as a tree of StructuralNodes, which in
turn are trees of InlineNodes.  A PurpleWiki::Tree is generated by a
parser, and the tree is traversed using the nodes' methods, starting
with the root node.

PurpleWiki::Tree's main purpose is to hold the document's root node
and metadata about the document.  Current metadata are lastNid, title,
subtitle, id, date, version, and authors.  PurpleWiki only uses the
first two, but the rest are useful if PurpleWiki is used as a document
authoring system.

The root node of a tree should always be a structural node of type
'document'.

=head1 VIEW DRIVERS

PurpleWiki::Tree can be serialized using the view method, which uses
the output format defined by a view driver.  View drivers are perl
modules with a function called view().  view() takes two parameters: a
PurpleWiki::Tree object, and an optional hash containing options for
the view driver.

Currently, there are three view drivers:

  Debug    -- Text debugging output
  WikiHTML -- XHTML w/ no header tags
  WikiText -- Wiki text markup

You can create your own view drivers, although you will have to modify
the view() method so that it is aware of the new driver.

=head1 METHODS

=head2 new(%options)

Constructor.  Creates a root StructuralNode object.  The %options has
contains default metadata values.

If you want to include a default value for author, then
$options{author} must be a reference to a list of arrays.  The first
value of the array is the author's name, the second value is the
author's e-mail.

For example:

 my $wiki = PurpleWiki::Tree->new(author=>[
    ['Chris Dent', 'cdent@blueoxen.org'] ]);

=head2 root()

Returns the root StructuralNode object.

=head2 Accessors/Mutators

 lastNid()
 title()
 subtitle()
 id()
 date()
 version()
 authors()

authors() returns a list reference.  See the documentation for new()
for details.  A side effect of the way authors() is implemented is
that once you have given it a value, you can change that value, but
you can't clear it.  This shouldn't be an issue, but if it ever
becomes one, we should add a clearAuthors() method.

=head2 view($driver, %params)

$driver is the name of the view driver, %params contains parameters
that are passed to the driver.  See "VIEW DRIVERS" above for more
details.  This implementation is rudimentary at the moment.  All
existing drivers must be hardcoded into this method.  This method
currently knows about the following drivers:

  Debug
  WikiHTML
  WikiText

=head1 AUTHORS

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=head1 SEE ALSO

L<PurpleWiki::StructuralNode>, L<PurpleWiki::InlineNode>.

=cut
