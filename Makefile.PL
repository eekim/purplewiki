use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'PurpleWiki',
    'VERSION'	=> '0.2',
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT   => 'WikiWiki with purple numbers',
       AUTHOR     => 'Chris Dent <cdent@blueoxen.org>, Eugene Eric Kim <eekim@blueoxen.org>') : ()),
);
