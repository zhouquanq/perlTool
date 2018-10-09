#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Encode; 
require 'srv.pl';
require 'common.pl';

my $AppPath = $FindBin::Bin;
my $continue = 1;
my $WARN_LOCKCOUNT = 0;

my ($base_file) = ($0 =~ /(.*?)(\.[^\.]*)?$/);
my $status_file = "$base_file.sta";
if(!(-e $status_file)){
    open(F_STATUS, ">$status_file") or die "can't write status output file: $status_file";
    print F_STATUS time();
    close F_STATUS;
}
while($continue)
{   
    run();
    my $now = ts2str(time());
    print "now: $now Sleeping...\n";
    sleep(60);
}

sub run
{
    my ($sec, $min, $hour, $day, $mon, $year) = localtime(time());
    $year += 1900;
    $mon += 1;      
    if($min ==0){
        system ("perl serverRestart.pl restart");
        #system ("perl serverRestart.pl start");
    }
    
    open(F_STATUS, ">$status_file") or die "can't write status output file: $status_file";
    print F_STATUS time();
    close F_STATUS;
    
}

