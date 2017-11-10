#!/usr/bin/perl -w
use strict;
use DBI;

my $host = "localhost";         # 主机地址
my $driver = "mysql";           # 接口类型 默认为 localhost
my $database = "logclear";        # 数据库
# 驱动程序对象的句柄
my $dsn = "DBI:$driver:database=$database:$host";
my $userid = "root";            # 数据库用户名
my $password = "";        # 数据库密码
# 连接数据库
my $dbh = DBI->connect($dsn, $userid, $password ) or die $DBI::errstr;
# my $sth = $dbh->prepare("SELECT * FROM websites");   # 预处理 SQL  语句

open(FILE, "<iap.log");
while (<FILE>) {
	# if($_ =~ /([1-9]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1]) ([0-2]?\d):[0-5]\d:[0-5]\d,\d{3})(.+)Delay -> (\S+)/){
	if($_ =~ /([1-9]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1]) ([0-2]?\d):[0-5]\d:[0-5]\d)(.+)amount=(\w+)(.+)orderId=(\w+)(.+)regionId=(\w+)(.+)price=(\w+)(.+)purchaseId=(\w+)(.+)goodsName=(.+),(.+)userId=(\d+)/){
        # print "$16 \n";
        # print $1,$6,$8,$10,$12,$14,$16,$18,"\n";
        # print "INSERT INTO goodslog
        #     (amout,orderId,regionId,price,purchaseId,goodsName,userId,time)
        #     values
        #     ($6,$8,$10,$12,$14,$16,$18,$1);";

        my $sth = $dbh->prepare("INSERT INTO goodslog (amout,orderId,regionId,price,purchaseId,goodsName,userId,time) values ($6,'$8',$10,$12,$14,'$16',$18,'$1');");
        $sth->execute() or die $DBI::errstr;
        $sth->finish();
        $dbh->commit;
	}
}
$dbh->disconnect();