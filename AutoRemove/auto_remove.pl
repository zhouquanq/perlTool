#!/usr/bin/perl
#实现跨文件夹日志和数据库备份的删除
BEGIN{
	use FindBin;
	$::APPLICATION_PATH = $FindBin::Bin;
	$::PARENT_PATH = $::APPLICATION_PATH."/../";
	push( @INC, $::APPLICATION_PATH, $::PARENT_PATH);
	chdir( $::APPLICATION_PATH);
	
	$::APPLICATION_ISRUN = 1;
	
	# 防止意外关闭
	$SIG{HUP} = sub {};
	$SIG{INT} = sub { $::APPLICATION_ISRUN = 0;};
	$| = 1;
}
use strict;
use warnings;
use Data::Dumper;
use POSIX qw(strftime);
use File::Path qw(make_path remove_tree);
use Date::Parse;

use File::Copy;

require 'common.pl';
require 'srv.pl';

#*************************要修改的***************************
my $configs = [
	{
		type	=>	'log',			#类型,包括 日志log和数据库备份dbbk
		dir	=>	'/mnt/data/GMAutoUpload/gs_log',				#扫描的目录
		days	=>	60,				#删除该天数之前的
	},
	 {
		 type	=>	'dbbk',
		 dir		=>	'/mnt/data/GMAutoUpload/gs_db',
		 full_count	=>	6,			#留取的全备份次数
	 },
	#{
	#	type	=>	'sql',
	#	dir		=>	'/GMAutodown/dbback',
	#	remain_count	=>	2,			#每个数据库留取的备份次数
	#},
	#{
	#	type	=>	'webbk',
	#	dir		=>	'/GMAutodown/website_backup',
	#	remain_count	=>	2,			#每个数据库留取的备份次数
	#},
];
#****************************************************

our $delete_count = 0;
while ($::APPLICATION_ISRUN) {
	my $start_time = strftime("%Y-%m-%d %H:%M:%S", localtime(time));
	
	$delete_count = 0;
	foreach my $hConfig (@$configs) {
		if($hConfig->{type} eq 'log') {
			traversal_dir_delete_log($hConfig->{dir}, $hConfig->{days});
		} elsif ($hConfig->{type} eq 'dbbk') {
			traversal_dir_delete_dbbk($hConfig->{dir}, $hConfig->{full_count});
		} elsif ($hConfig->{type} eq 'sql') {
			traversal_dir_delete_sql($hConfig->{dir}, $hConfig->{remain_count});
		} elsif ($hConfig->{type} eq 'webbk') {
			traversal_dir_delete_webbk($hConfig->{dir}, $hConfig->{remain_count});
		}
	}
	
	my $end_time = strftime( "%Y-%m-%d %H:%M:%S", localtime(time));

	log2("Success,unlinked $delete_count files!");	
	log2("start_time:".$start_time);
	log2("end_time:".$end_time);
	log2("--------------------------------- ---------------------------------\n\n");
	
	sleep 86400;
}

#递归删除文件夹下的45天前的日志
sub traversal_dir_delete_log {
	my ($src_dir, $del_days) = @_;
	
	our $delete_count;
	
	my @dir_lists = glob($src_dir."/*");
	
	foreach (@dir_lists) {
		my $src_tmp = $_;
		#print $src_tmp."\n";
		
		if(-f $src_tmp) {
			next if $src_tmp !~ /(\d{10})\.lzo$/;
			my $log_str = $1;
			
			my $min_t = ts2str(time - $del_days * 86400);
			my ($min_y, $min_m, $min_d, $min_h) = $min_t =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):\d{2}:\d{2}/;
			my $min_str = $min_y.$min_m.$min_d.$min_h;
						
			#删除大于$del_days天前的日志
			if ($min_str > $log_str) {
				unlink $src_tmp or die "unlink $src_tmp failed: $!";
				$delete_count++;
				log2("unlinked file $src_tmp");
			}
		} elsif (-d $src_tmp) {
			traversal_dir_delete_log($src_tmp,$del_days);
		}
	}
}

sub traversal_dir_delete_dbbk {
	my ($src_dir, $full_remain) = @_;
		
	our $delete_count;
	
	my $dir_lists = [sort(glob($src_dir."/*"))];
	my $fullfile_lists = [sort(glob($src_dir."/*full*"))];
	my $min_ts = undef;
	if(defined($fullfile_lists) && 2 <= scalar(@$fullfile_lists)) {
		#/GMAutodown/lywm_db/gs7/1352468486_full.tar.gz
		($min_ts) = $fullfile_lists->[scalar(@$fullfile_lists) - $full_remain] =~ /(\d{10})_full\.tar\.gz$/;
	}
	
	foreach my $src_tmp (@$dir_lists) {
		#print $src_tmp."\n";
		
		if(-f $src_tmp && defined($min_ts)) {
			next if $src_tmp !~ /(\d{10})_/;
			my $log_ts = $1;
						
			#删除两个全备份前的增量
			if ($min_ts > $log_ts) {
				unlink $src_tmp or die "unlink $src_tmp failed: $!";
				$delete_count++;
				log2("unlinked file $src_tmp");
			}
		} elsif (-d $src_tmp) {
			traversal_dir_delete_dbbk($src_tmp,$full_remain);
		}
		
		if(-f $src_tmp) {
			next if $src_tmp !~ /(\d{10})_/;
			my $log_ts = $1;			
			
			#删除20天之前的增量
			if($log_ts < time() - 86400*22) {
				unlink $src_tmp or die "unlink $src_tmp failed: $!";
				$delete_count++;
				log2("unlinked old file $src_tmp");
			}
		}
	}
}

sub traversal_dir_delete_sql {
	my ($src_dir, $remain_count) = @_;
		
	our $delete_count;
	
	my $dir_lists = [sort(glob($src_dir."/*"))];
	my $sql_files = {};
	
	foreach my $src_tmp (@$dir_lists) {
		next unless $src_tmp =~ /^(.*)_(\d{10})\.sql$/;
		push @{$sql_files->{$1}},$2; 
	}
	
	foreach my $tbase (keys %{$sql_files}) {
		my @tbase_files = sort(@{$sql_files->{$tbase}});
		next unless scalar(@tbase_files) > $remain_count;
		while(scalar(@tbase_files) > $remain_count) {
			#print "$tbase tbase_files:\n".Dumper([@tbase_files]);
			my $file_time =  shift @tbase_files;			
			unlink $tbase."_".$file_time.".sql" or die "unlink ".$tbase."_".$file_time.".sql"." failed: $!";
			$delete_count++;
			log2("deleted ".$tbase."_".$file_time.".sql");
		}
	}
}

sub traversal_dir_delete_webbk {
	my ($src_dir, $remain_count) = @_;
		
	our $delete_count;
	
	my $dir_lists = [sort(glob($src_dir."/*"))];
	my $webbk_files = {};
	
	foreach my $src_tmp (@$dir_lists) {
		next unless $src_tmp =~ /^(.*)_(\d{8})\.tar\.gz$/;
		push @{$webbk_files->{$1}},$2; 
	}
	
	foreach my $tbase (keys %{$webbk_files}) {
		my @tbase_files = sort(@{$webbk_files->{$tbase}});
		next unless scalar(@tbase_files) > $remain_count;
		while(scalar(@tbase_files) > $remain_count) {
			#print "$tbase tbase_files:\n".Dumper([@tbase_files]);
			my $file_time =  shift @tbase_files;			
			unlink $tbase."_".$file_time.".tar.gz" or die "unlink ".$tbase."_".$file_time.".tar.gz"." failed: $!";
			$delete_count++;
			log2("deleted ".$tbase."_".$file_time.".tar.gz");
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
