# PurpleWiki::API.pm
# vi:ai:sw=4:ts=4:et:sm
#
# $Id$
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
#
package PurpleWiki::API;
use strict;
use warnings;
use Carp;
use PurpleWiki::Config;
use PurpleWiki::Database;
use PurpleWiki::Database::Page;
use PurpleWiki::Database::KeptRevision;
use PurpleWiki::Parser::WikiText;
use PurpleWiki::View::Filter;
use base qw(PurpleWiki::Singleton);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = { @_ };

    $self->{config} = PurpleWiki::Config->instance();

    bless($self, $class);
    return $self;
}

sub getAllPages {
    my $self = shift;
    return PurpleWiki::Database::AllPagesList();
}

sub getPageInfo {
    my ($self, $pageName) = @_;
    return $self->getPageInfoVersion($pageName, -1);
}

sub getPageInfoVersion {
    my ($self, $pageName, $version) = @_;
    my $section;
    my %pageInfo;

    if (not $self->pageExistsVersion($pageName, $version)) {
        croak "$pageName not found";
    }

    # Handle version specific stuffs.
    if ($version >= 0) { # An old version
        my $keptRev = $self->getKeptRevision($pageName);
        $section = $keptRev->getRevision($version);
        $pageInfo{version} = $version;
    } else { # Current version
        my $page = $self->getPageObject($pageName);
        $page->openPage();
        $section = $page->getSection();
        $pageInfo{version} = $section->getRevision();
    }

    $pageInfo{author} = $section->getUsername() || "";
    $pageInfo{name} = $pageName;
    $pageInfo{lastModified} = gmtime($section->getTS());
    $pageInfo{host} = $section->getHost() || "";
    $pageInfo{ip} = $section->getIP() || "";
    $pageInfo{userID} = $section->getID() || "";
    $pageInfo{timeStamp} = $section->getTS();

    return %pageInfo;
}

sub getKeptRevision {
    my ($self, $pageName) = @_;
    return new PurpleWiki::Database::KeptRevision('id' => $pageName);
}

sub getPageObject {
    my ($self, $pageName) = @_;
    return $self->getPageObjectVersion($pageName, -1);
}

sub getPageObjectVersion {
    my ($self, $pageName, $version) = @_;
    my $keptRev = $self->getKeptRevision($pageName);
    my $page;

    if ($version < 0) {
        $page = $self->getPageObject(id => $pageName);
    } elsif ($keptRev->hasRevision($version)) {
        $page = $keptRev->getRevision($version);
    } else {
        croak "Could not find version $version of $pageName";
    }

    return $page;
}

sub getTree {
    my ($self, $pageName) = @_;
    return $self->getTreeVersion($pageName, -1);
}

sub getTreeVersion {
    my ($self, $pageName, $version) = @_;
    my $parser = new PurpleWiki::Parser::WikiText;
    my $page;

    if (not $self->pageExistsVersion($pageName, $version)) {
        my $error = "$pageName could not be found";
        $error = "Version $version of ".$error if $version >= 0;
        croak $error;
    }

    $page = $self->getPageObjectVersion($pageName, $version);
    $page->openPage();
    return $parser->parse($page->getText()->getText(),
                          'add_node_ids' => 0,
                          'url' => $self->{config}->FullUrl."?".$pageName);
}

sub pageExists {
    my ($self, $pageName) = @_;
    return $self->pageExistsVersion($pageName, -1);
}

sub pageExistsVersion {
    my ($self, $pageName, $version) = @_;
    my $page = $self->getPageObject($pageName);
    my $keptRev = $self->getKeptRevision($pageName);

    return ($page->pageExists() and 
            ($version < 0 or $keptRev->hasRevision($version)));
}

sub getFormattedPage {
    my ($self, $pageName, $format) = @_;
    return $self->getFormattedPageVersion($pageName, -1, $format);
}

sub getFormattedPageVersion {
    my ($self, $pageName, $version, $format) = @_;
    return $self->getTreeVersion($pageName, $version)->view($format);
}

sub getNodes {
    return shift->getNodesVersion(shift, -1, @_);
}

sub getNodesVersion {
    my ($self, $pageName, $version, $typeRegex) = @_;
    my @nodes = ();
    my $filter;
    my $handler;

    $typeRegex = '.*' if not defined $typeRegex;
    $handler = sub { 
        my $nodeRef = shift;
        push @nodes, $nodeRef if $nodeRef->type =~ /$typeRegex/;
    };

    $filter = new PurpleWiki::View::Filter("Main" => $handler);
    $filter->process($self->getTreeVersion($pageName, $version));

    return @nodes;
}

sub getLinks {
    my ($self, $pageName) = @_;
    $self->getLinksVersion($pageName, -1);
}

sub getLinksVersion {
    my ($self, $pageName, $version) = @_;
    my $regex = "wikiword|freelink|image|url|link";
    return $self->getNodes($pageName, $version, $regex);
}

sub getBackLinks {
    my ($self, $pageName) = @_;
    my @backLinks = ();

    for my $page ($self->getAllPages()) {
        for my $nodeRef ($self->getNodes("wikiword|freelink")) {
            push @backLinks, $page if $nodeRef->content eq $pageName;
        }
    }

    return @backLinks;
}

sub putPage {
    my ($self, $pageName, $newContent, %attributes) = @_;
    my $page;     # A PurpleWiki::Database::Page that represents $pageName
    my $keptRev;  # A PurpleWiki:Database::KeptRevision history for $pageName
    my $textObject;  # A PurpleWiki::Database::Text object for the page's text
    my $section;  # The PurpleWiki::Database::Section object for the page.
    my $oldContent; # The page's old WikiText content, this is a string.
    my $oldTimeStamp; # The page's old time stamp (second's since the epoch)
    my $tree; # A PurpleWiki::Tree that represents the page.
    my $newAuthor; # 1 if we're a new author of the page, 0 otherwise.
    my $now = time();  # The current timestamp, seconds since the epoch.
    my $parser = new PurpleWiki::Parser::WikiText;  # Our WikiText parser.

    # Normalize the attributes hash.
    for my $key (qw(timeStamp minorEdit summary username
                    userID host updateRC)) {
        if (not defined $attributes{$key}) {
            $attributes{$key} = ""
        }
    }

    # Make sure we were passed in valid data
    croak "Undefined page name" if not defined $pageName; 
    croak "Undefined content" if not defined $newContent;

    # Scrub out UTF-8 from content and page name.
    $pageName = pack('A*', unpack('A*', $pageName));
    $newContent = pack('A*', unpack('A*', $newContent));

    # Set default summary info and make sure minorEdit is a number, 1 or 0.
    # Also, the default is to make additions to the RecentChanges file.
    $attributes{summary} = "*" if not $attributes{summary};
    $attributes{minorEdit} = ($attributes{minorEdit}) ? 1 : 0;
    $attributes{updateRC} = 1 if $attributes{updateRC} eq "";

    # Clean up the content and summary to make them safe for the DB:
    my $fsexp = $self->{config}->FS;
    $newContent =~ s/$fsexp//g;
    $newContent =~ s/\r//g;
    $newContent .= "\n" if not $newContent =~ /\n$/;
    $attributes{summary} =~ s/[\r\n]//g;
    $attributes{summary} =~ s/$fsexp//g;

    # Parse the WikiText we were given.
    $tree = $parser->parse($newContent,
                           'add_node_ids' => 1,
                           'url' => $self->{config}->fullUrl."?".$pageName);
    $newContent = $tree->view("wikitext");

    # Request a lock before we start pulling out old information.
    $self->requestLock();

    # Load up object representations of the page and its revision history.
    $page = $self->getPageObject($pageName);
    $keptRev = $self->getKeptRevision($pageName);

    # Open the page and pull out its old content.
    $page->openPage();
    $textObject = $page->getText();
    $section = $page->getSection();
    $oldContent = $textObject->getText();
    $oldTimeStamp = $section->getTS();

    # See if any changes were made to the input
    if ($oldContent eq $newContent) {
        $self->releaseLock();
        return;
    }

    # Check to see if we're a new author of a page:
    if ($attributes{userID} > 399 || $section->getID() > 399) {
        $newAuthor = ($attributes{userID} ne $section->getID());  # known users
    }
    $newAuthor = 1 if $section->getRevision() == 0;  # New page
    $newAuthor = ($newAuthor) ? 1 : 0;  # Force numeric value.

    # If we're not working on a new page, see if the timestamp of the new data
    # and the old data are different, this means the old data changed while we
    # were editing.  This is bad.
    if ($section->getRevision() > 0) {
        # Make sure we ahev a timeStamp
        if (not $attributes{timeStamp}) {
            $self->releaseLock();
            croak "No timestamp found in attributes.";
        }

        # Make sure timestamps haven't changed.
        if ($attributes{timeStamp} ne $oldTimeStamp) {
            $self->releaseLock();
            croak "Given time stamp \"".$attributes{timeStamp}."\" and found". 
                  " time stamp \"$oldTimeStamp\"";
        }
    }

    # Only set if this was a major edit.
    if (not $attributes{minorEdit}) {
        $page->setPageCache('oldmajor', $section->getRevision());
    }

    # Only set if the author has changed.
    if ($newAuthor) {
        $page->setPageCache('oldauthor', $section->getRevision());
    }

    # Generate Diff information if that option is set.
    if ($self->{config}->UseDiff) {
        &PurpleWiki::Database::UpdateDiffs($page, $keptRev, $pageName, $now, 
                                           $textObject->getText(), $newContent, 
                                           $attributes{minorEdit}, $newAuthor);
    }

    # Save the content of the page. $textObject is the page's text object,
    # $section is the page's section object, $kepRev is the pages revision
    # history.  We save all the necessary info and then write it out with the
    # last few lines.
    $textObject->setText($newContent); # Set the content of the text object.
    $textObject->setMinor($attributes{minorEdit});
    $textObject->setNewAuthor($newAuthor);
    $textObject->setSummary($attributes{summary});
    $section->setHost($attributes{host});
    $section->setRevision($section->getRevision() + 1);
    $section->setTS($now); # Set time stamp
    $keptRev->addSection($section, $now);
    $keptRev->trimKepts($now);  # Trim kept revisions before $now
    $page->setRevision($section->getRevision());
    $page->setTS($now); # Set time stamp
    $keptRev->save(); # Save out to disk.
    $page->save(); # Save and be done!

    # Write out Recent Changes information.
    if ($attributes{updateRC}) {
        $self->putRecentChanges($pageName, $now, %attributes);
    }

    # Release our lock;
    $self->releaseLock();
}

sub validPageName {
    my ($self, $pageName) = @_;
    my $linkRegex = $self->{config}->LinkPattern;
    my $freeLinkRegex = $self->{config}->FreeLinkPattern;

    # Make sure name is not the sample undefined page:
    return 0 if $pageName eq 'SampleUndefinedPage';
    return 0 if $pageName eq 'Sample_Undefined_Page';

    return 0 if length($pageName) > 120; # Check length:
    return 0 if $pageName =~ /\s+/; # Check for Spaces

    # Tests specific to Subpages:
    if ($self->{config}->UseSubpage()) {
        return 0 if $pageName =~ /.*\/.*\//; # SubPages can only have one slash
        return 0 if $pageName =~ /^\//; # SubPages can't begin with a slash
        return 0 if $pageName =~ /\/$/; # SubPages can't end with a slash
    }

    # Tests specific to Free Links:
    if ($self->{config}->FreeLinks()) {
        $pageName =~ s/ /_/g;  # Replace spaces with underscores

        # Don't allow slash if we don't use sub pages
        if (not $self->{config}->UseSubpage()) {
            return 0 if $pageName =~ /\//;
        }

        # Make sure page name is a valid free link
        return 0 if not $pageName =~ /^$freeLinkRegex$/; 

        return 0 if $pageName  =~ /\.db$/;   # Don't let links end in .db
        return 0 if $pageName  =~ m/\.lck$/; # Don't let links end in .lck
    } else {
        # If no FreeLinks then it must match the conf. link pattern
        return 0 if not $pageName  =~ /^$linkRegex$/;
    }

    # Page name is valid if it passed all our tests.
    return 1;
}

sub getRecentChanges {
    my ($self, $timeStamp) = @_;
    my @RCInfo = ();

    # Default to showing all changes.
    $timeStamp = 0 if not defined $timeStamp;

    open(IN, $self->{config}->RcFile)
        || croak $self->{config}->RCName." log error: $!";

    for my $logEntry (<IN>) {
        chomp $logEntry;
        my $fsexp = $self->{config}->FS3;
        my @entries = split /$fsexp/, $logEntry;
        if (@entries >= 7 && $entries[0] >= $timeStamp) {  # Check timestamp
            my %info;
            $info{name} = $entries[1];
            $info{summary} = $entries[2];
            $info{minorEdit} = $entries[3];
            $info{host} = $entries[4];
            $info{author} = "";

            # $entries[5] is garbage and so we ignore it...

            # Get extra info
            my $fsexp = $self->{config}->FS2;
            @entries = split /$fsexp/, $entries[6];
            if (@entries == 2) {
                $info{userID} = $entries[0];
                $info{author} = $info{username} = $entries[1];
            }

            push @RCInfo, \%info;
        }
    }

    close(IN);
    return @RCInfo;
}

sub putRecentChanges {
    my ($self, $pageName, $now, %attributes) = @_;
    my ($extraTemp, %extra);

    # Normalize the attributes hash.
    for my $key (qw(timeStamp minorEdit summary username userID 
                    host updateRC)) {
        if (not defined $attributes{$key}) {
            $attributes{$key} = ""
        } else {
            # Remove noise in the data.
            my $fsexp1 = $self->{config}->FS;
            my $fsexp2 = $self->{config}->FS2;
            my $fsexp3 = $self->{config}->FS3;
            $attributes{$key} =~ s/[\r\n]//g;
            $attributes{$key} =~ s/$fsexp1//g;
            $attributes{$key} =~ s/$fsexp2//g;
            $attributes{$key} =~ s/$fsexp3//g;
        }
    }

    # Set default summary info and make sure minorEdit is a number, 1 or 0.
    # Also, the default is to make additions to the RecentChanges file.
    $attributes{minorEdit} = ($attributes{minorEdit}) ? 1 : 0;

    # Setup some extra info to add to the RecentChanges log.
    %extra = ();
    $extra{'id'} = $attributes{userID} || 3307;
    $extra{'name'} = $attributes{username} if $attributes{username};
    $extraTemp = join($self->{config}->FS2, %extra);

    # The two fields at the end of the line are kind of an extension-hash
    my $logEntry = join($self->{config}->FS3, $now, $pageName, 
                        $attributes{summary}, $attributes{minorEdit}, 
                        $attributes{host}, "0", $extraTemp);

    # Write the changes out:
    open(OUT, ">>".$self->{config}->RcFile)
        || croak $self->{config}->RCName." log error: $!";
    print OUT $logEntry."\n";
    close(OUT);
}

sub requestLock {
    &PurpleWiki::Database::RequestLock()
        || croak "Failed to get a lock on the Wiki database";
}

sub releaseLock {
    &PurpleWiki::Database::ReleaseLock();
}

sub DESTROY {
    shift->releaseLock();
}

1;
__END__

=head1 NAME

PurpleWiki::API - PurpleWiki Application Programming Interface

=head1 SYNOPSIS

    #!/usr/bin/perl
    use strict;
    use warnings;
    use PurpleWiki::Config;
    use PurpleWiki::API;

    PurpleWiki::Config->new('/path/to/wikidb/');

    my $api = new PurpleWiki::API;
    my $pageName = shift || die "Usage: $0 pagename\n";
    for my $imageNodeRef ($api->getNodes($pageName, "image")) {
        print $imageNodeRef->href, "\n";
    }

=head1 DESCRIPTION

This object provides an idiomatic entry point into the PurpleWiki libraries.
It provides methods to do many of the common tasks a programmer would want
to do with the Wiki.

=head1 METHODS

=over

=item new()

Creates a new instance of the PurpleWiki::API object.  new() does not take
any arguments, but will save any key/value pairs passed in to its internal
state and then subsequently ignore them.

=item getAllPages()

Returns a list of all local pages on the Wiki, sorted alphabetically.

=item getPageInfo($pageName)

Returns information on the current version of the page with name $pageName.  If
the page does not exist than a fatal error occurs.  The page information is
returned in a hash with the following fields:

=over

=item author

The name of last person to author the page.  Empty string if unknown.

=item name

The name of the page.  Equal to $pageName.

=item lastModified

The date, in UTC format, of the last modification of the page.

=item timeStamp

Time in seconds since January 1st 1970 GMT of the last modification date of the
page.

=item host

Hostname of the last user to edit the page.  Empty string if unknown.

=item ip

IP address of the last user to edit the page.  Empty string if unknown.

=item userID

Username of the last user to edit the page.  Empty string if unknown.

=item version

The version number of the page.

=back

=item getPageInfoVersion($pageName, $version)

Same as getPageInfo() except the information for version $version is returned
instead.  If $version is negative then the most recent version is used.

=item getKeptRevision($pageName)

Returns the PurpleWiki::Database::KeptRevision object associated with the page
named $pageName.

=item getPageObject($pageName)

Returns the PurpleWiki::Database::Page object associated with the page named
$pageName.

=item getPageObjectVersion($pageName, $version)

Same as getPageObject() except version $version of the page named $pageName is
returned.  It is a fatal error if the version doesn't exist.  If $version is
negative then the most recent version is returned.

=item getTree($pageName)

Returns the PurpleWiki::Tree associated with the current version of the page
named $pageName.

=item getTreeVersion($pageName, $version)

Same as getTree() except returns version $version.  It is a fatal error if
the version doesn't exist.  If $version is negative then the most  recent
version is returned.

=item pageExists($pageName)

Returns true if the page named $pageName exists, otherwise false.

=item pageExistsVersion($pageName, $version)

Returns true if version $version of the paged named $pageName exists, otherwise
false.  If $version is negative then the most recent version is assumed.

=item getFormattedPage($pageName, $format)

Returns the current version of the page named $pageName rendered in the format
specified by $format.  $format can be any of the valid view driver formats,
defer to driver specific documentation for help.

=item getFormattedPageVersion($pageName, $version, $format)

Same as getFormattedPage() except version $version of the page named $pageName
is used.  If the version doesn't exist a fatal error occurs.  If $version is
negative then the most recent version of the page named $pageName is used.

=item getNodes($pageName, $regex)

Returns a list of PurpleWiki::*Node objects whos' type field match the regex
specified by $regex.

=item getNodesVersion($pageName, $version, $regex)

Same as getNodes() except version $version of the page named $pageName is used.
If the version does not exist then a fatal error occurs.  If $version is 
negative then the most recent version is used.

=item getLinks($pageName)

Returns a list of PurpleWiki::InlineNode references representing all the links
in the page named $pageName.  Links include wikiwords, freelinks, images, urls,
etc.  Each node reference supports a href, content, and type method which
can be used to extract the corresponding information.

=item getLinksVersion($pageName, $version)

Same as getLinks() except version $version of the page named $pageName is
used.  If the version does not exist then an error occurs.  If $version is
negative then the most recent version is used.

=item getBackLinks($pageName)

Returns a list of page names whose current version contain a wikiword or
freelink which references the page named $pageName.

=item putPage($pageName, $newContent, %attributes)

Places the content stored in $newContent into the page named $pageName.  If
the page named $pageName doesn't exist it is created.  The hash %attributes
has the following keys:

=over

=item timeStamp

The time in seconds since January 1st 1970 GMT of the last modification of the
current version of the page named $pageName.  The timeStamp is the only
required attribute and it is only required if the page named $pageName
previously existed.

=item minorEdit

Set to a true value if the change is a minor change.  Defaults to false.

=item summary

The summary information to be used in RecentChanges for the update.

=item username

The Wiki username of the person making the change.

=item userID

The user ID of the person making the change.

=item host

The hostname of the person making the change.

=item updateRC

Set to a true value if RecentChanges should be updated.  Defaults to true.
   
=back

=item validPageName($pageName)

Returns true if the string represented by $pageName is a valid name to be
used in the Wiki.  Returns false otherwise.

=item getRecentChanges($timeStamp)

Returns a list of hash refrences representing all of the changes before or
on the date represented by the time stamp $timeStamp, which is in seconds
since January 1st 1970.  The hashes contain the following fields, which
are set to the empty string if not present:

=over

=item name

The name of the page whos entry this hash represents.

=item summary

The summary text of the change associated with the page.

=item minorEdit

True if the user marked the changes as being minor, false otherwise.

=item host

Hostname of the user who last edited the page.

=item author

Name of the user who last edited the page.

=item userID

User ID of the user who last edited the page.

=back

=item putRecentChanges($pageName, $timeStamp, %attributes)

Writes out an entry to the RecentChanges file for the page named $pageName. The
date of the entry is represented by $timeStamp, which is in seconds since
January 1st, 1970.   The %attributes hash has the same fields as the hash
references returned for getRecentChanges().

=item requestLock()

Gets a lock on the Wiki Database.  A fatal error occurs if the lock fails.

=item releaseLock()

Gives up a lock on the Wiki Database.

=back

=head1 AUTHORS

Matthew O'Connor, E<lt>matthew@canonical.orgE<gt>

Chris Dent, E<lt>cdent@blueoxen.orgE<gt>

Eugene Eric Kim, E<lt>eekim@blueoxen.orgE<gt>

=cut
