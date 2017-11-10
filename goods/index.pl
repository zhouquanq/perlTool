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
# 避免插入数据库乱码
$dbh->do("SET NAMES utf8");

open(FILE, "<iap.log");
while (<FILE>) {
    # 正则匹配所需要提取的值
	if($_ =~ /([1-9]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1]) ([0-2]?\d):[0-5]\d:[0-5]\d)(.+)amount=(\w+)(.+)orderId=(\w+)(.+)regionId=(\w+)(.+)price=(\w+)(.+)purchaseId=(\w+)(.+)goodsName=(.+),(.+)userId=(\d+)/){
        # print "$16 \n";
        # print $1,$6,$8,$10,$12,$14,$16,$18,"\n";
        # print "INSERT INTO goodslog
        #     (amout,orderId,regionId,price,purchaseId,goodsName,userId,time)
        #     values
        #     ($6,$8,$10,$12,$14,$16,$18,$1);";\

        # 使用 prepare() API 预处理 SQL 语句
        my $sth = $dbh->prepare("INSERT INTO goodslog (amout,orderId,regionId,price,purchaseId,goodsName,userId,time) values ($6,'$8',$10,$12,$14,'$16',$18,'$1');");
        # 使用 execute() API 执行 SQL 语句
        $sth->execute() or die $DBI::errstr;
        # 使用 finish() API 释放语句句柄
        $sth->finish();
	}
}
# 隐藏自动提交错误提示
$dbh->{Warn} = 0;
$dbh->commit;
$dbh->disconnect();