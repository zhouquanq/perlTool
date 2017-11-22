#!/usr/bin/perl
BEGIN {
	use FindBin;
	my ($_parent_dir) = $FindBin::Bin =~ /(.*\/).*/;
	push(@INC, $FindBin::Bin, $_parent_dir);
}
use strict;
use warnings;
use File::Path;
use File::Copy;
use Net::FTP;
use MysqlX;
use Data::Dumper;

require 'srv.pl';
require 'common.pl';

our $g_app_path;
our $copy_count = 0;
our $makepath_count = 0;

my $g_continue;
my $WARN_LOCKCOUNT;

my %isneedcopybak;

eval{
	main();
};
log2("deadly wrong:".$@) if $@;

sub main
{
	$| = 1;
	$g_app_path = $FindBin::Bin;
	$g_continue = 1;

	my ($base_file) = ($0 =~ /(.*?)(\.[^\.]*)?$/);
	my $cfg_file = "$base_file.cfg";
	die "cfg file: '$cfg_file' not exists!" unless -e $cfg_file;

	while ($g_continue) {
		my $now = ts2str(time());
		log2("%%%%%%%%%%%%%%%% service start %%%%%%%%%%%%%%%%");

		my $cfg_ini = load_ini($cfg_file);
		
		my ($dbname, $server, $port, $passive, $username, $password, $ext, $filter_ext, $downpath, $ftp_from_dir, $workpath, $dbdatadir, $dbsrvname, $dstconinfo);
		foreach my $section(@{$cfg_ini}) {
			if ($section->{'name'} eq "restore") {
				$workpath = get_section_value($section, "workpath", "");		
				$dbdatadir = get_section_value($section, "dbdatadir", "");
				$dbsrvname = get_section_value($section, "dbsrvname", "");
				$dstconinfo = get_section_value($section, "dstconinfo", "");
			}
			# if ($section->{'name'} eq "ftp") {
				# $server = get_section_value($section, "server", "");		
				# $port = get_section_value($section, "port", "");
				# $passive = get_section_value($section, "passive", "");
				# $username = get_section_value($section, "username", "");
				# $password = get_section_value($section, "password", "");
				# $ext = get_section_value($section, "ext", "");
				# $filter_ext = get_section_value($section, "filter_ext", "");
				# $downpath = get_section_value($section, "ftp_to_dir", "");
			# }
		}
		
		#扩展名trim
		my $exts;
		{
			my @tmp_exts = split(/,/, $ext);
			for (@tmp_exts)
			{
				my $e = $_;
				$e =~ s/^\s+//;
				$e =~ s/\s+$//;

				$exts->{lc($e)} = 1;
			}
		}
		
		foreach my $section (@{$cfg_ini}) {
			my $dbname_base = $section->{'name'};
			next unless $dbname_base;
			next if $dbname_base eq "restore" || $dbname_base eq "ftp";
			if ($dbname_base ne "restore" && $dbname_base ne "ftp" ) {
				#my $ftp_from_base = get_section_value($section, "ftp_from_base", "");
				my $srcdb = get_section_value($section, "srcdb", "");
				my $downpath_base = get_section_value($section, "downpath_base", "");
				
				my $startday = ts2str(time(), 1);
				my %srcdb = str2arr($srcdb);
				#从数据库查询该运营商需要分析日志的服务器
				my $conn = MysqlX::genConn(\%srcdb);
				my $db = new MysqlX($conn);
				my $sql = "
					SELECT * FROM needrunserver WHERE theday = '$startday' GROUP BY serverid
				";
				my $run_servers = [];
				#push @{$run_servers},{'ftp_from_dir'=>$ftp_from_base."/ga",'dbname'=>$dbname_base."_ga"};
				push @{$run_servers},{'dbname'=>$dbname_base."_ga", 'downpath'=>$downpath_base."/ga"};
				my $servers = $db->fetchAll($sql);
				#对该运营商的每个服务器进行数据库还原(包括账号服)
				foreach (@{$servers}) {
					my $theday = $_->{'theday'};
					my $serverid = $_->{'serverid'};
					
					my $params = {
						#'ftp_from_dir'	=>	$ftp_from_base."/gs".$serverid,
						'dbname'	=>	$dbname_base."_gs".$serverid,
						'downpath'	=>	$downpath_base."/gs".$serverid,
					};
					push @{$run_servers},$params;
				}
				log2("---need run servers:\n".Dumper($run_servers));
				
				foreach (@{$run_servers}) {
												
						uninstall($cfg_file);
						log2("uninstall done!");
						install($cfg_file);
						log2("install done!");				
						
						my $dbname = $_->{dbname};
						#my $ftp_from_dir = $_->{ftp_from_dir};
						my $downpath = $_->{downpath};
					
						log2("\n\n===========================Start restore $dbname ==============================");
						my $start_time = ts2str(time);
						my $restore_return = dbrebuild($downpath, $workpath, $dbdatadir, $dbsrvname);	
						my $end_time = ts2str(time);
						
						log2("dbrebuild param-----\n downpath:$downpath\n workpath:$workpath\n dbdatadir:$dbdatadir\n dbsrvname:$dbsrvname\n");
						log2("restore start_time:".$start_time);
						log2("restore end_time:".$end_time);
						log2("++++restore_return:\n".Dumper($restore_return));
						
						my %dstconinfo = str2arr($dstconinfo);
						my $dstconn = MysqlX::genConn(\%dstconinfo);
						my $dstcon = new MysqlX($dstconn);
						
						my $row;
						#还原时没有返回值,说明还原失败
						if(!defined($restore_return)) {
							$row = {
								db_name	=>	$dbname,
								reducible	=>	0,
								start_restore_time	=>	$start_time,
								end_restore_time	=>	$end_time,
							};
							log2("insert row: \n".Dumper($row));
							write_into_metable6('restore_info', $row, ['db_name'], $dstcon);					
							log2("===========================restored $dbname wrong ==============================");
						} 
						else {
							my $isold = 0;
							my $last_ts;
							if($restore_return->{lastnewfile}) {
								($last_ts) = $restore_return->{lastnewfile} =~ /(\d+)/;
							} else {
								($last_ts) = $restore_return->{full_file} =~ /(\d+)/;
							}							
							log2("starttime:".ts2str(time())."  lasttime:".ts2str($last_ts));
							if(time() - $last_ts > 7200) {
								log2("the last db file is too old");
								$isold = 1;
							}
							
							$row = {
								db_name	=>	$dbname,
								reducible	=>	1,
								last_full_file	=>	$restore_return->{full_file},					
								last_file_time	=>	ts2str($last_ts),
								isold	=>	$isold,
								start_restore_time	=>	$start_time,
								end_restore_time	=>	$end_time,
							};
							$row->{last_inc_file} = $restore_return->{lastnewfile} if defined $restore_return->{lastnewfile};
							log2("insert row: \n".Dumper($row));
							write_into_metable6('restore_info', $row, ['db_name'], $dstcon);
							
							log2("===========================end restore $dbname ==============================");
							
						}
						sleep 60;
				}
			}
			sleep 3;
		}
				
		sleep(10);	
		log2("%%%%%%%%%%%%%%%% service end %%%%%%%%%%%%%%%%");
	}
}

sub dbrebuild
{
	my ($downpath, $workpath, $dbdatadir, $dbsrvname) = @_;
	
	$downpath =~ s/[\\\/]\s*$//;
	$workpath =~ s/[\\\/]\s*$//;
	$dbdatadir =~ s/[\\\/]\s*$//;

	if (!-d $workpath) {
		mkpath($workpath);
	}
	
	my $dbconfigfile = "/etc/$dbsrvname.cnf";
	my $processed_log = "$workpath/processed.log";
	my %processed_files = load_processed_files($processed_log);		
	
	my $full_file = undef;
	my $newest_full = 0;
	my @newfiles = ();
	my $lastnewfile = undef;
	
	if (opendir(DIR_SCAN, $downpath)) {
		my @files = sort(readdir DIR_SCAN);
		closedir DIR_SCAN;
	

		foreach my $filename(@files) {			
			if ($filename =~ /(\d+)_full\.tar\.gz$/) {
				if ($1 > $newest_full) {					
					$full_file = $filename;
					$newest_full = $1;
				}
			}
		}
		return unless $newest_full;
		foreach my $filename(@files) {
			if ($filename =~ /(\d+)_inc\.tar\.gz$/ && !exists($processed_files{$filename})) {
				push @newfiles, $filename if $1 > $newest_full;
			}
		}
		$lastnewfile = [sort(@newfiles)]->[-1] if scalar(@newfiles) > 0;
		my $isfullprocessed = exists($processed_files{$full_file}) ? 1 : 0;
		
		log2("---newest_full:".Dumper($newest_full));
		log2("---newfiles:".Dumper([@newfiles]));
		my $targetfile = shift @newfiles;		
		while ($g_continue) {
			if ($isfullprocessed && defined($targetfile)) {				
				print "processing file: $targetfile\n";	
				my ($dirname) = $targetfile =~ /(\d+_inc)/;

				return if logcmd("tar -zxvf $downpath/$targetfile -C $workpath");

				return if logcmd("innobackupex --defaults-file=$dbconfigfile --apply-log $workpath/full --incremental-dir=$workpath/$dirname");
								
				append_processed_files($processed_log, lc($targetfile));
				
				rmtree("$workpath/$dirname");
				$isneedcopybak{$dbsrvname} = 1;

				$targetfile = shift @newfiles;

			} elsif (0 == $isfullprocessed && defined($full_file)) {
				print "processing file: $full_file\n";	

				rmtree("$workpath/full");

				return if logcmd("tar -zxvf $downpath/$full_file -C $workpath");

				return if logcmd("innobackupex --defaults-file=$dbconfigfile --apply-log $workpath/full --redo-only");
				
				append_processed_files($processed_log, $full_file);

				$isneedcopybak{$dbsrvname} = 1;				
				$isfullprocessed = 1;

			} elsif ($isneedcopybak{$dbsrvname}) {				
				print "copying DB data. DB is going to restart!\n";	
				
				rmtree($dbdatadir);
				mkpath($dbdatadir);
				return if logcmd("innobackupex --copy-back --defaults-file=$dbconfigfile $workpath/full");	

				return if logcmd("chown mysql:mysql $dbdatadir -R");

				return if logcmd("service $dbsrvname restart");
				
				#sleep(5);

				$isneedcopybak{$dbsrvname} = 0;
			} else {
				last;
			}
		}
	}
	my $return_value;
	if(defined($lastnewfile) || defined($full_file)) {
		$return_value = {lastnewfile => $lastnewfile,full_file=>$full_file};
	} else {
		$return_value = undef;
	}
	return $return_value;
	log2("++++return value:\n".Dumper($return_value));
}


sub diecmd
{
	my ($cmd) = @_;

	(0 == cmd($cmd)) or die("Fail:$cmd");
}

sub logcmd
{
	my ($cmd) = @_;
	my $ret = cmd($cmd);
	log2("---exc:$cmd	ret:".Dumper($ret));
	log2("Fail:$cmd") if ($ret);
	return $ret;
}

sub install
{
	my ($cfg_file) = @_;

	my $cfg_ini = load_ini($cfg_file);
	
	mkpath "/var/pid" unless -d "/var/pid";
	return if logcmd("chown mysql:mysql /var/pid -R");
	
	foreach my $section(@{$cfg_ini}) {
		if ($section->{'name'} eq "restore") {
			my $dbsrvname = get_section_value($section, "dbsrvname", "");
			my $dbdatadir = get_section_value($section, "dbdatadir", "");
			my $port	  = get_section_value($section, "port", "");
			$dbdatadir =~ s/\//\\\//g;
			
			diecmd("cp -f $g_app_path/mysql_template.cnf /etc/$dbsrvname.cnf");
			diecmd("perl -p -i -e \"s/{dbsrvname}/$dbsrvname/g\" /etc/$dbsrvname.cnf");			
			diecmd("perl -p -i -e \"s/{dbdatadir}/$dbdatadir/g\" /etc/$dbsrvname.cnf");
			diecmd("perl -p -i -e \"s/{port}/$port/g\" /etc/$dbsrvname.cnf");

			diecmd("cp -f $g_app_path/mysql_template.service /etc/rc.d/init.d/$dbsrvname");
			diecmd("perl -p -i -e \"s/{dbsrvname}/$dbsrvname/g\" /etc/rc.d/init.d/$dbsrvname");
			diecmd("chmod a+x /etc/rc.d/init.d/$dbsrvname");
		}
	}

	print "Install Done!\n";
}

sub uninstall
{
	my ($cfg_file) = @_;

	my $cfg_ini = load_ini($cfg_file);

	foreach my $section(@{$cfg_ini}) {
		if ($section->{'name'} eq "restore") {
			my $dbsrvname = get_section_value($section, "dbsrvname", "");
			my $dbdatadir = get_section_value($section, "dbdatadir", "");
			my $port	  = get_section_value($section, "port", "");
			my $workpath = get_section_value($section, "workpath", "");

			cmd("service $dbsrvname stop");			

			cmd("rm -f /var/log/mysql/$dbsrvname.log");
			cmd("rm -f /var/pid/$dbsrvname.pid");
			cmd("rm -f /tmp/$dbsrvname.sock");	
			
			cmd("rm -f /etc/$dbsrvname.cnf");
			cmd("rm -f /etc/rc.d/init.d/$dbsrvname");

			cmd("rm -rf $dbdatadir");
			cmd("rm -rf $workpath");
		}
	}

	print "Uninstall Done!\n";
}

sub createFTP {
	my ($server, $port, $passive, $username, $password) = @_;
	
	#FTP连接
	my $ftp = 0;
	my $tryCount = 3;
	while ($tryCount--) {
		$ftp = Net::FTP->new($server, Port => $port, Debug => 0, Passive => $passive, Timeout => 3600);
		
		if($ftp) {
			last;
		} else {
			sleep 10;
		}
	}
	if (!$ftp) {
		log2("connect to ftp error: $@");
		return;
	}
	#ftp登录
	my $b_logined = 0;
	$tryCount = 3;
	while ($tryCount--) {
		$b_logined = $ftp->login($username, $password);
		
		if($b_logined) {
			last;
		} else {
			sleep 10;
		}
	}
	if (!$b_logined) {
		log2("login to ftp($server) error: $@");
		return;
	}
	#ftp切换传输模式
	if (!$ftp->binary()) {
		log2("can't change ftp($server) mode to binary: $@");
		return;
	}
	return $ftp;
}

sub ftp_down_file6 {
	my ($ftp, $ftp_path, $download_path, $ftp_file_names) = @_;
	return unless defined($ftp) && $ftp;
	foreach my $file_name (@{$ftp_file_names}) {
		my $ftp_file = $ftp_path."/".$file_name;
		my $local_file = $download_path."/".$file_name;
		
		my $tmpfile = $local_file.".tmp";
		
		my $tmpfilesize;	
		if(-e $local_file) {
			print "file $local_file exists,next...\n";
			next;
		} elsif (-e $tmpfile) {
			$tmpfilesize = -s $tmpfile;
			if ($tmpfilesize < $ftp->size($ftp_file)) {
				if (!$ftp->get($ftp_file, $tmpfile, $tmpfilesize)) {
					log2("ftp get file $ftp_file error: $@");
					return;
				}
			}
		} else {
			#log2("-----------------------\nget $ftp_file...");
			if (!$ftp->get($ftp_file, $tmpfile)) {
					log2("ftp get file $ftp_file error: $@");
					return;
			}
		}

		#下载完整性检查	
		return unless -e $tmpfile;	
		$tmpfilesize = -s $tmpfile;
		unless (defined($tmpfilesize) && $tmpfilesize > 0) {
			return;
		}
		
		#log2("local size:$tmpfilesize		remote size:".$ftp->size($ftp_file));
		if ($tmpfilesize == $ftp->size($ftp_file)) {
			move($tmpfile, $local_file);
			$copy_count++;
		}
		elsif ($tmpfilesize > $ftp->size($ftp_file)) {
			log2("Delete too large tmpfile: $tmpfile");
			unlink $tmpfile;
		}
	}
}

$SIG{__WARN__} = sub{
	
	my ($text) = @_;
    my @loc = caller(0);
   	chomp($text);
   	
   	my $text_ = $text ? $text : "";
	log2('warn: '. $text_); 
	
	my $index = 1;
    for(@loc = caller($index); scalar(@loc); @loc = caller(++$index))
	{
		log2( sprintf( " callby %s(%s) %s", $loc[1], $loc[2], "$loc[3]")); 
	};
    return 1;
};

$SIG{__DIE__} = sub{
	
	my ($text) = @_;
    my @loc = caller(0);
   	chomp($text);

	my $text_ = $text ? $text : "";
	log2('error: '. $text_); 
	
	my $index = 1;
    for(@loc = caller($index); scalar(@loc); @loc = caller(++$index))
	{
		log2( sprintf( " callby %s(%s) %s", $loc[1], $loc[2], "$loc[3]")); 
	};
    return 1;
};