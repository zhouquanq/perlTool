#!/usr/bin/perl
BEGIN {
    use FindBin;
    my ($_parent_dir) = $FindBin::Bin =~ /(.*\/).*/;
    push(@INC, $FindBin::Bin, $_parent_dir);
}
use strict;
use DBI;
use warnings;
use File::Path;

require 'srv.pl';
require 'common.pl';

our $g_app_path;

my $g_continue;
my $WARN_LOCKCOUNT;

my %isneedcopybak;

main();
sub main
{
    $| = 1;
    $g_app_path = $FindBin::Bin;
    $g_continue = 1;

    my ($base_file) = ($0 =~ /(.*?)(\.[^\.]*)?$/);
    my $cfg_file = "$base_file.cfg";
    die "cfg file: '$cfg_file' not exists!" unless -e $cfg_file;

    my $status_file = "$base_file.sta";
    while ($g_continue) {
        my $now = ts2str(time());
        # die "$now";
        print "now: $now Sleeping...\n";

        my $cfg_ini = load_ini($cfg_file);

        foreach my $section(@{$cfg_ini}) {
            if ($section->{'name'} eq "mysql_info") {
                dbrebuild($section);
                die "-----Done!------";
                # sleep(10);
            }
        }

        open(F_STATUS, ">$status_file") or die "can't write status output file: $status_file";
        print F_STATUS time();
        close F_STATUS;
    }
}

sub dbrebuild
{
    my ($section) = @_;
    my $host = get_section_value($section, "host", "");
    my $driver = get_section_value($section, "driver", "");       
    my $database = get_section_value($section, "database", "");
    my $dbuser = get_section_value($section, "dbuser", "");
    my $dbpass = get_section_value($section, "dbpass", "");
    my $port = get_section_value($section, "port", "");
    my $logpath = get_section_value($section, "logpath", "");

    $logpath =~ s/[\\\/]\s*$//;

    # die "$logpath";

    if (!-d $logpath) {
        mkpath($logpath);
    }
    
    my $processed_log = "$logpath/processed.log";
    my %processed_files = load_processed_files($processed_log); 

    if (opendir(DIR_SCAN, $logpath)) {
        my @files = sort(readdir DIR_SCAN);
        closedir DIR_SCAN;
        
        my $full_file = undef;
        my $newest_full = 0;
        my @newfiles = ();

        foreach my $filename(@files) {
            # 把没处理的文件寻到newfiles
            if ($filename =~ /sgland.log_(\d+)/ && !exists($processed_files{$filename})) {
                push @newfiles, $filename if $1 > $newest_full;
            }
        }
        my $isfullprocessed = exists($processed_files{$full_file}) ? 1 : 0;
        my $targetfile = shift @newfiles;   

        
        if(defined($targetfile)){
            # 驱动程序对象的句柄
            my $dsn = "DBI:$driver:database=$database:$host";
            # 连接数据库
            my $dbh = DBI->connect($dsn, $dbuser, $dbpass ) or die $DBI::errstr;
            open(FILE, "$logpath/$targetfile");
            while (<FILE>) {
                # if($_ =~ /([1-9]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1]) ([0-2]?\d):[0-5]\d:[0-5]\d)(.+)rid":(\d+)(.+)id":(\d+)(.+)do":"(.+)",(.+)infoId":1,(.+)num":(.+)}}/){
                if($_ =~ /([1-9]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1]) ([0-2]?\d):[0-5]\d:[0-5]\d)(.+)rid":(\d+)(.+)id":(\d+)(.+)level":(\d+)(.+)vip":(\d+)(.+)do":"(.+)",/){
                    # print "$_";
                    # print "*****" , "\n", $1 , "  ",  $6 , "  ",  $8 , "  " ,$10 , "  ",$12 , "  ",  $14  ,"\n";
                    my $date = $1;
                    my $rid = $6;
                    my $uid = $8;
                    my $level = $10;
                    my $vipLevel = $12;
                    my $do = $14;

                    next if $_ !~ /"resource":(.+)}/;
                    my $resource = $1;
                    $resource = defined($resource) ? $resource : "";
                    # print ("INSERT INTO lg_operation_log (rid,uid,level,vipLevel,do,resource,date) values ($rid,$uid,$level,$vipLevel,'$do','$resource','$date';" , "\n");
                    my $sth = $dbh->prepare("INSERT INTO lg_operation_log (rid,uid,level,vipLevel,do,resource,date) values ($rid,$uid,$level,$vipLevel,'$do','$resource','$date');");
                    $sth->execute() or die $DBI::errstr;
                    $sth->finish();
                    $dbh->commit;
                }
            }
            $dbh->disconnect();
            append_processed_files($processed_log, lc($targetfile));
            $targetfile = shift @newfiles;
        }

    }


}