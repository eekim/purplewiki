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

sub getPageInfo {
    my ($self, $pageName) = @_;
    return $self->getPageInfoVersion($pageName, -1);
}

sub getPageInfoVersion {
    my ($self, $pageName, $version) = @_;
    my $page = new PurpleWiki::Database::Page('id' => $pageName);
    my $keptRev = new PurpleWiki::Database::KeptRevision('id' => $pageName);
    my $section;
    my %pageInfo;

    croak "$pageName not found" if not $page->pageExists();
    $page->openPage();

    # Handle version specific stuffs.
    if ($version >= 0) { # An old version
        if ($keptRev->hasRevision($version)) {
            $section = $keptRev->getRevision($version);
            $pageInfo{version} = $version;
        } else {
            die "Could not find version $version of $pageName\n";
        }
    } else { # Current version
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

sub getPage {
    my ($self, $pageName) = @_;
    return new PurpleWiki::Database::Page(id => $pageName);
}

sub getPageVersion {
    my ($self, $pageName, $version) = @_;
    my $keptRev = new PurpleWiki::Database::KeptRevision('id' => $pageName);
    my $page;

    return $self->getPage($pageName) if $version < 0;

    if ($keptRev->hasRevision($version)) {
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
        croak "Version $version of $pageName could not be found";
    }

    $page = $self->getPageVersion($pageName, $version);
    $page->openPage();
    return $parser->parse($page->getText()->getText(),
                          'add_node_ids' => 0,
                          'url' => $self->{config}->FullUrl."?".$pageName);
}


sub getLinks {
    my ($self, $pageName) = @_;
    my @pageLinks = ();
    my @types = qw(wikiword freelink image url link);
    my $extractor = sub { push @pageLinks, shift };
    my $filter;

    $filter = new PurpleWiki::View::Filter(map { $_ => $extractor } @types);
    $filter->process($self->getTree($pageName));

    return @pageLinks;
}

sub getBackLinks {
    my ($self, $pageName) = @_;
    my @backLinks = ();

    for my $page ($self->getAllPages()) {
        for my $linkInfo ($self->getLinks($page)) {
            if ($linkInfo->{type} =~ /wikiword|freelink/) {
                push @backLinks, $page if $linkInfo->{content} eq $pageName;
            }
        }
    }

    return @backLinks;
}

sub putPage {
    use Data::Dumper;
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
    &PurpleWiki::Database::RequestLock()
        || croak "Failed to get a lock on the Wiki database";

    # Load up object representations of the page and its revision history.
    $page = $self->getPage($pageName);
    $keptRev = new PurpleWiki::Database::KeptRevision('id' => $pageName);

    # Open the page and pull out its old content.
    $page->openPage();
    $textObject = $page->getText();
    $section = $page->getSection();
    $oldContent = $textObject->getText();
    $oldTimeStamp = $section->getTS();

    # See if any changes were made to the input
    if ($oldContent eq $newContent) {
        &PurpleWiki::Database::ReleaseLock();
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
            &PurpleWiki::Database::ReleaseLock();
            croak "No timestamp found in attributes.";
        }

        # Make sure timestamps haven't changed.
        if ($attributes{timeStamp} ne $oldTimeStamp) {
            &PurpleWiki::Database::ReleaseLock($self->{config});
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
    &PurpleWiki::Database::ReleaseLock();
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

sub pageExists {
    my ($self, $pageName) = @_;
    return $self->pageExistsVersion($pageName, -1);
}

sub pageExistsVersion {
    my ($self, $pageName, $version) = @_;
    my $page = $self->getPage($pageName);
    my $keptRev = new PurpleWiki::Database::KeptRevision('id' => $pageName);

    return ($page->pageExists() and 
            ($version < 0 or $keptRev->hasRevision($version)));
}

sub getFormattedPage {
    my ($self, $pageName, $format) = @_;
    return $self->getFormattedPageVersion($pageName, $format, -1);
}

sub getFormattedPageVersion {
    my ($self, $pageName, $format, $version) = @_;
    return $self->getTreeVersion($pageName, $version)->view($format);
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
        || die $self->{config}->RCName." log error: $!\n";
    print OUT $logEntry."\n";
    close(OUT);
}

sub DESTROY {
    &PurpleWiki::Database::ReleaseLock();
}

1;
__END__
