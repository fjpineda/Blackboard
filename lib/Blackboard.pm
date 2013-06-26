############################################################################
### TITLE:   Blackboard.pm                                                 #
### AUTHOR:  Fernando J. Pineda                                            #
### DATE:    Oct 12, 2011                                                  #
############################################################################

package Blackboard;

use warnings;
use strict;
use File::NFSLock qw(uncache);
use Fcntl qw(LOCK_EX LOCK_NB);
use Sys::Hostname;
use File::Spec;
use Cwd qw(cwd abs_path);


#------------------------------------
# private variables and functions
#------------------------------------

my $blackboard_dir   = './blackboard'; #default
my $timestamp        = '';
my $lockfile         = $blackboard_dir.'/lockfile';
my $hostname         = hostname();
my $pid              = $$;
my $task             = '';
my $basename         = '';
my $blocking_timeout = 40;
my $time_stamp       = undef;

#######################
# new() -- creates new blackboard object
#######################
sub new      # creates new blackboard object
{
    my $invocant = shift;
    my %args = @_;

    if(defined($args{blackboard})) { 
        $blackboard_dir = $args{blackboard};
        $lockfile       = $blackboard_dir.'/lockfile';
    };
    if(defined($args{timeout})) 
        { $blocking_timeout = $args{timeout} };

    # confirm that blackboard directory exists
    unless(-d $blackboard_dir) {
        die("blackboard directory does not exist:\n$blackboard_dir");
    }

    $time_stamp = _time_stamp();
    my $class = ref($invocant)||$invocant;
    return bless ({}, $class);
}


#######################
# needs_processing() -- tests if task must be performed on this file basename
#######################
sub needs_processing 
{
    my $self= shift;
    # my ($task, $basename) = @_;

    my %arguments = @_;
    $basename  =  $arguments{basename};
    $task      =  $arguments{task};
    my $msg    =  $arguments{message};
    
    if( my $lock = File::NFSLock->new({ 
        file=> $lockfile, 
        blocking_timeout   => $blocking_timeout,   # return undef if can't create lock file after this many secs 
        lock_type=>'EXCLUSIVE'
        }))
    {

        my $filename = $blackboard_dir."/$basename.$task.status";
        if(-e $filename) { 
            $lock->unlock();
            return 0; # false because status file exists another instance is working on this
        }
        else { # create the status file, save the task, and return true
            open(FILE,">$filename");
            print FILE  _time_stamp()."|$hostname|$pid|$basename|$task|$msg\n";
            close(FILE);            
            $lock->unlock();
            return 1;
        }
    }
    else {
        my $msg = "Blackboard abort: timeout while attempting to write lockfile\n";
        die($msg);
    }
}

sub _time_stamp {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    $time_stamp = sprintf ("%4d-%02d-%02d %02d:%02d:%02d",
                            $year+1900,$mon+1,$mday,$hour,$min,$sec
                            );
    return $time_stamp;
}

#######################
# update_status() -- update status msg in status file
#######################
sub update_status 
{
    my ($self,$msg) = @_;
    chomp $msg;

    if( my $lock = File::NFSLock->new({ 
        file=> $lockfile, 
        blocking_timeout   => $blocking_timeout,   # return undef if can't create lock file after this many secs 
        lock_type=>'EXCLUSIVE'
        })) 
    {
        my $filename = $blackboard_dir."/$basename.$task.status";
        if(-e $filename) { 
            open(FILE,">$filename");
            print FILE  _time_stamp()."|$hostname|$pid|$basename|$task|$msg\n";
            close(FILE);
            
            $lock->unlock();
            return 1;
        }
        else {
            $lock->unlock();
            return 0;
        }
    }
    else {
        my $msg = "Blackboard abort: timeout while attempting to write lockfile\n";
        die($msg);
    }

}

#######################
# basename_from()  -- makes a basename from an input filename
# assumes filename has an extension
#######################
sub basename_from 
{
    my ($self, $path) = @_;
    my ($volume,$directories,$file) = File::Spec->splitpath( $path );
    my ($basename) = ($file =~ /(.*)\.\w+$/); # strip the extension
    return $basename;
}


1;

__END__

=head1 NAME

    Blackboard - Perl module that implements simple concurrenty control 

=head1 SYNOPSIS

    use Blackboard;

    my @datafiles = glob("./data/*.txt");

    my $bb = Blackboard->new(); # initialize a new blackboard

    #######################
    # the first task in dummy pipeline is preprocessing
    #######################

    foreach my $path (@datafiles) {
        my $basename = $bb->basename_from($path);
        if($bb->needs_processing( 
            basename => $basename , 
            task     =>'preprocessing', 
            message  =>"started")
        ) {
                
            busywork($path);
            $bb->update_status("completed");
        }
    }

    #######################
    # the second task in the dummy pipeline is postprocesing
    #######################

    foreach my $path (@datafiles) {
        my $basename = $bb->basename_from($path);
        if($bb->needs_processing( 
            basename => $basename , 
            task     =>'postprocessing', 
            message  =>"started")
        )  {
            busywork($path);
            $bb->update_status("completed");
        }
    }

    #######################
    # placeholder routine for your favorite processing
    #######################

    sub busywork {
        sleep(5);
    }


=head1 DESCRIPTION


A light-weight stand-alone concurrency control system for perl scripts. 
No additional software (MPI, relational database, etc.) is required. 
Methods in the module monitor and update status files in a 'blackboard' 
directory. A lockfile strategy ensures that only one agent at a time is 
allowed to access the blackboard directory, thereby eliminating race 
conditions. 

A perl script that performs processing on data file can be converted into 
an agent by using the three methods in Blackboard.pm.

=head1 METHODS


new()

    Blackboard->new(<arguments>)
    
Creates a new blackboard object. A blackboard directory is created if 
one does not already exist. Default is a subdirectory of the current 
working directory. If parameters are not specified, default blackboard 
directory 'blackboard' is created in the current working directory. 
Default timeout is 40 seconds.

    blackboard  => path_to_blackboard_directory
    timeout     => seconds_before_timeout_when_creating_lockfile
         
needs_processing()

    $bb->needs_processing(basename=>$basename, task=>$task, message=>"started")

Checks if a status file exists. Writes a status file with the message 
and returns true if status file does not exist. Start you processing the 
given task if true is returned.
    
    basename => <status_files_base_name>
    task     => <alphanumeric name_of_task_to_be_performed>
    message  => <alphanumeric string message>
        
The task must be a single alphanumeric, e.g. "preprocessing". A short message 
is best, e.g. "done", but  this is not required. Status files have a standard 
naming convention:

        <basename>.<task>.status

basename_from()

    $bb->basename_from($full_path_to_file);

Extracts and returns a basename from a fully qualified file name. The 
basename is used to build status file names. It is assumeed that file 
extensions are 3 character.
    
update_status()

    $bb->update_status('completed');

Updates the status message field in the status file. The single 
argument is a message string.

=head1 EXPORT


None 

=head1 AUTHOR


Fernando J. Pineda, <lt>fernando.pineda@jhu.edu<gt>

=head1 COPYRIGHT AND LICENSE


(c) Fernando J. Pineda

LICENSE: GNU GENERAL PUBLIC LICENSE, Version 3, June 1991
http://www.gnu.org/licenses/gpl.txt


=cut

