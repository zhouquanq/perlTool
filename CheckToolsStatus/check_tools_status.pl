#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use JSON;


my $continue = 1;
BEGIN
{
    our $AppPath = $FindBin::Bin;
    
    my ($_parent_dir) = $FindBin::Bin =~ /(.*\/).*/;
	push(@INC, $FindBin::Bin, $_parent_dir);
	#chdir($FindBin::Bin);
}
require 'srv.pl';
require 'common.pl';

my $script_file_name = "docker_gs.pl";

my $script_file = $::AppPath . "/" . "$script_file_name";
if ( !(-e $script_file)){
	$script_file = $::AppPath . "/../" . "$script_file_name";
}

if (!(-e $script_file)) {
	# die "can not find ${script_file}!!!";
}

my $status_file = $script_file;
$status_file  =~ s/\.pl/\.sta/ig;


my ($base_file) = ($0 =~ /(.*?)(\.[^\.]*)?$/);
my $cfg_file = "$base_file.cfg";
die "cfg file: '$cfg_file' not exists!" unless -e $cfg_file;

my $jar_tool = $::AppPath . "/SmsTools.jar";
die "jar tool: '$jar_tool' not exists!" unless -e $jar_tool;


# print $base_file,"\n";
# print $jar_tool,"\n";
# die(3);

while($continue)
{	
	run();
	my $now = ts2str(time());
	log2("now: $now Sleeping...");
	sleep(600);
	#test
}

sub run 
{
	
	my $cfg_ini = load_ini($cfg_file);
	my $mobile = "";
	my $auto_bak = "";
	my $ftp_load = "";
	my $Interval = "";
	foreach my $section(@{$cfg_ini}) {
		if ($section->{'name'} eq "check") {
			$mobile = get_section_value($section, "mobile", "15072757377");
			$auto_bak = get_section_value($section, "auto_bak", "");
			$ftp_load = get_section_value($section, "ftp_load", "");
			$Interval = get_section_value($section, "Interval", "300");
		}	
	}
	#die($Interval);
	open (F, "<$auto_bak") or die "open $auto_bak error: $! ";
	my $auto_bak_time =<F>;
	open (F, "<$ftp_load") or die "open $ftp_load error: $! ";
	my $ftp_load_time =<F>;
	my $date = time();
	my $report_content = "";

	if($date - $auto_bak_time > $Interval){
	#	$report_content .= "auto_bak is down.";
	#	SendSMSErrorReport($mobile,$report_content);
	}

	if($date - $ftp_load_time > $Interval){
		$report_content .= "ftp_load is down.";
		SendSMSErrorReport($mobile,$report_content);
	}
	print $date - $auto_bak_time,"\n";
	print $date - $ftp_load_time,"\n";
	log2("Done.");
	close F;
}

=pod
sub ExecCmd{
	my( $cmd) = @_;
	printf( "%s\n", $cmd);
	if (system($cmd)!=0) {
		die "exec $cmd faild!\n";
	}
	
}
=cut



sub SendSMSErrorReport {
	my ($mobile,$content) =@_;
	return if (!$content);
	log2("sms content: $content");
	my $cmd = "java -jar $jar_tool \"$mobile\" \"$content\"";
	cmd($cmd) == 0 or die "exec SmsTools.jar failed!!!";
	log2("sms content: ok");
}

sub postFormLinkReport {
	my ($params) = @_;
	my $linkStr =  "";
	foreach my $key (sort keys %$params) {
		print $key,"\t",$params->{$key},"\n";
		$linkStr .= "&" if($linkStr);
		$linkStr .= $key ."=". $params->{$key};
	}
	print $linkStr,"\n";
	return $linkStr;
}


