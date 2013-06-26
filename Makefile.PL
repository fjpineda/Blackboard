use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Blackboard',
    VERSION_FROM      => 'lib/Blackboard.pm', # finds $VERSION
    PREREQ_PM         => {
    	Moose         => 1.13,
    	File::NFSLock => 1.20,
    	File::Spec    => 3.33,
    	Fcntl         => 1.05,
    	Sys::Hostname => 1.11
    }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Blackboard.pm', # retrieve abstract from module
       AUTHOR         => 'Fernando J. Pineda <fernando.pineda@jhu.edu>') : ()),
);
