use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'PurpleWiki',
    'VERSION'	=> '0.9.1',
    'PREREQ_PM'		=> {
    	Text::Wrap => 0,
	Text::Diff => 0,
	LWP::UserAgent => 0,
	IO::File => 0,
	DB_File => 0,
	AppConfig => 1.55,
	CGI => 0,
	CGI::Carp => 0,
	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT   => 'WikiWiki with purple numbers',
       AUTHOR     => 'Chris Dent <cdent@blueoxen.org>, Eugene Eric Kim <eekim@blueoxen.org>') : ()),
);
