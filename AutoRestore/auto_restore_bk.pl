#!/usr/bin/perl
BEGIN {
	use FindBin;
	my ($_parent_dir) = $FindBin::Bin =~ /(.*\/).*/;
	push(@INC, $FindBin::Bin, $_parent_dir);
}
use strict;
use warnings;
use File::Path;
use Data::Dumper;

require 'common.pl';

our $g_app_path;

main();
sub main
{
	$g_app_path = $FindBin::Bin;
	
	my $dbsrvname = "mysql_6033";
	my $port	  = "6033";	
	my $dbdatadir = "/GMDB/tempdb";
	my $workpath  = "/GMDBase/tempdb";
	my $dbconfigfile = "/etc/$dbsrvname.cnf";

	my ($arg1) = @ARGV;
	if (defined($arg1) && $arg1 eq 'cleanup') {
		cleanup($dbsrvname, $dbdatadir, $workpath);
		return;
	}

	my ($base_file) = ($0 =~ /(.*?)(\.[^\.]*)?$/);
	my ($logpath, $restore_day, $restore_time) = @ARGV;
	die "Usage: $base_file.pl logpath restore_point(yyyy-mm-dd hh:mm:ss)" unless 3 == scalar @ARGV;
	$logpath =~ s/[\\\/]\s*$//;
	my $restorets = str2ts($restore_day.' '.$restore_time);
		
	opendir(DIR_SCAN, $logpath);
	my @files = readdir DIR_SCAN;
	closedir DIR_SCAN;	
	@files = sort(grep /\d+_(full|inc)\.tar\.gz$/, @files);
	
	#从最近的full包开始取
	my @full_files = sort(grep /\d+_full/,@files);
	my @full_files2;
	if (scalar(@full_files) < 1) {
		print "Can't find the first full backup.\n";
		return;
	};	
	for(my $k = 0;$k < scalar @full_files; ++$k) {
		my $ts = $full_files[$k] =~ /(\d+)_full/;
		if($ts <= $restorets) {
			push @full_files2,$full_files[$k];
		}
	}
	my ($last_full_ts) = $full_files2[-1] =~ /(\d+)_full/;
	
	
	my @tmp_files;
	for (my $k = 0;$k < scalar @files; ++$k) {
		$files[$k] =~ /(\d+)_(full|inc)/;
		if($1 >= $last_full_ts) {
			push @tmp_files,$files[$k];
		}
	}
	@files = @tmp_files;	
	
	print Dumper(@full_files);
	print Dumper($last_full_ts);

	my $i = 0;
	for (;$i < scalar @files; ++$i) {
		$files[$i] =~ /(\d+)_(full|inc)/;
		last if ($restorets <= $1);
	}
	
	if (0 == $i || scalar @files == $i) {
		$i-- if (scalar @files == $i);
		$files[$i] =~ /(\d+)_(full|inc)/;	
		
		print $files[$i]." (Backup time: ".ts2str($1).")\n";
		print "\nAbove is the closest bakcupfile. Do you want to restore to it?(y/n)";
		my $ipt = <STDIN>;
		chomp $ipt;

		if ('y' eq $ipt) {
			cleanup($dbsrvname, $dbdatadir, $workpath);
			install($dbsrvname, $dbdatadir, $port);

			mkpath($workpath);
			mkpath($dbdatadir);

			my $j = 0;
			my $newest_full = 0;
			for (; $j <= $i; ++$j) {
				my $bkfile = $files[$j];
				diecmd("tar -zxvf $logpath/$bkfile -C $workpath");

				if ($bkfile =~ /(\d+)_full/) {
					$newest_full = $1;
					diecmd("xtrabackup_55 --defaults-file=$dbconfigfile --prepare --apply-log-only --target-dir=$workpath/full --redo-only");
				} elsif ($bkfile =~ /(\d+)_inc/ && $1 > $newest_full) {					
					my ($dirname) = $bkfile =~ /(\d+_inc)/;
					diecmd("innobackupex --defaults-file=$dbconfigfile --apply-log $workpath/full --incremental-dir=$workpath/$dirname");
					rmtree("$workpath/$dirname");
				}
			}

			diecmd("innobackupex --copy-back --defaults-file=$dbconfigfile $workpath/full");
			diecmd("chown mysql:mysql $dbdatadir -R");
			diecmd("service $dbsrvname start");	
			
			print "\n Database has be restored.(port 6033)\n";
		}
	}
	else {
		$files[$i - 1] =~ /(\d+)_(full|inc)/;
		print "[1] ".$files[$i - 1]." (Backup time: ".ts2str($1).")\n";
		$files[$i] =~ /(\d+)_(full|inc)/;
		print "[2] ".$files[$i]." (Backup time: ".ts2str($1).")\n";

		print "\nAbove are the closest bakcupfile. Please choice the num you want to resotre(Enter other quit directly without restore):";
		my $ipt = <STDIN>;
		chomp $ipt;

		if ('1' eq $ipt || '2' eq $ipt) {
			cleanup($dbsrvname, $dbdatadir, $workpath);
			install($dbsrvname, $dbdatadir, $port);

			mkpath($workpath);
			mkpath($dbdatadir);
			
			my $j = 0;
			my $newest_full = 0;
			$i-- if ('1' eq $ipt);
			for (; $j <= $i; ++$j) {
				my $bkfile = $files[$j];
				diecmd("tar -zxvf $logpath/$bkfile -C $workpath");

				if ($bkfile =~ /(\d+)_full/) {
					$newest_full = $1;
					diecmd("xtrabackup_55 --defaults-file=$dbconfigfile --prepare --apply-log-only --target-dir=$workpath/full --redo-only");
				} elsif ($bkfile =~ /(\d+)_inc/ && $1 > $newest_full) {	
					my ($dirname) = $bkfile =~ /(\d+_inc)/;
					diecmd("innobackupex --defaults-file=$dbconfigfile --apply-log $workpath/full --incremental-dir=$workpath/$dirname");
					rmtree("$workpath/$dirname");
				}
			}

			diecmd("innobackupex --copy-back --defaults-file=$dbconfigfile $workpath/full");
			diecmd("chown mysql:mysql $dbdatadir -R");
			diecmd("service $dbsrvname start");	

			print "\n Database has be restored.(port 6033)\n";
		}
	}
}

sub install
{
	my ($dbsrvname, $dbdatadir, $port) = @_;
	
	$dbdatadir =~ s/\//\\\//g;	
	diecmd("cp -f mysql_template.cnf /etc/$dbsrvname.cnf");
	diecmd("perl -p -i -e \"s/{dbsrvname}/$dbsrvname/g\" /etc/$dbsrvname.cnf");			
	diecmd("perl -p -i -e \"s/{dbdatadir}/$dbdatadir/g\" /etc/$dbsrvname.cnf");
	diecmd("perl -p -i -e \"s/{port}/$port/g\" /etc/$dbsrvname.cnf");

	diecmd("cp -f mysql_template.service /etc/rc.d/init.d/$dbsrvname");
	diecmd("perl -p -i -e \"s/{dbsrvname}/$dbsrvname/g\" /etc/rc.d/init.d/$dbsrvname");
	diecmd("chmod a+x /etc/rc.d/init.d/$dbsrvname");

	diecmd("mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql");
	diecmd("mkdir -p /var/pid && chown mysql:mysql /var/pid");

	print "Install Done!\n";
}

sub cleanup
{
	my ($dbsrvname, $dbdatadir, $workpath) = @_;

	cmd("service $dbsrvname stop");			

	cmd("rm -f /var/log/mysql/$dbsrvname.log");
	cmd("rm -f /var/pid/$dbsrvname.pid");
	cmd("rm -f /tmp/$dbsrvname.sock");	
	
	cmd("rm -f /etc/$dbsrvname.cnf");
	cmd("rm -f /etc/rc.d/init.d/$dbsrvname");

	cmd("rm -rf $dbdatadir");
	cmd("rm -rf $workpath");

	print "Cleanup Done!\n";
}

sub diecmd
{
	my ($cmd) = @_;
	print "$cmd\n";
	(0 == system($cmd)) or die("Fail:$cmd");
}