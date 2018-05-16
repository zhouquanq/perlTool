<?php 
	date_default_timezone_set("Etc/GMT-7");
	//查询服务器
	$conn1 = @mysql_connect("10.10.133.13", "root", "YMuOR9MI3fQDk6UxjNlT");
	mysql_query("set names 'utf8'");//编码转化
	mysql_select_db("managerserver");
	$queryServer = "select sl_id from serverlist where sl_id>10000;";
	$server = mysql_query($queryServer);
	$Rank = array();
	$date = date('Y-m-d H:i:s',time());
	//查总排行
	$conn2 = @mysql_connect("10.10.133.11", "root", "YMuOR9MI3fQDk6UxjNlT");
	mysql_select_db("ygo_battle");
	$queryDate = "select * from tb_period where ID=1";
	$queryDate = mysql_query($queryDate);
	while ($startDate = mysql_fetch_assoc($queryDate)) {
		$startDate = $startDate['StartTime'];
		break;
	}
	$queryRankSql = "select UID,RID,Trophy,2 as type from tb_user where StartTime = '{$startDate}' order by Trophy desc limit 50;";
	$competitiveRankSql = "select UID,RID,LadderExTrophy,3 as type from tb_user where StartTime = '{$startDate}' order by LadderExTrophy desc limit 50;";
	$queryTotalRank = mysql_query($queryRankSql);
	$competitiveRank = mysql_query($competitiveRankSql);
	//循环查每个服务器的排行  duel_rank
	while ($rid = mysql_fetch_assoc($server)) {
	    $conn3 = @mysql_connect("10.10.133.13", "root", "YMuOR9MI3fQDk6UxjNlT");
		mysql_select_db("ygo_{$rid['sl_id']}");
		$queryRank = "select UID,RID,Name,Trophy,1 as type from tb_user order by Trophy desc limit 50;";
		$Rank = mysql_query($queryRank);
		$conn4 = @mysql_connect("10.10.133.13", "root", "YMuOR9MI3fQDk6UxjNlT");
		mysql_select_db("managerserver");
		while ($row = mysql_fetch_assoc($Rank)) {
			$insertRank = "insert into duel_rank (UID,Name,ServerID,Score,date,type) values ('$row[UID]','$row[Name]','$row[RID]','$row[Trophy]','$date','$row[type]')";
			mysql_query($insertRank);
		}
	}
	while ($rank = mysql_fetch_assoc($queryTotalRank)) {
		$insertsql = "insert into duel_rank (UID,ServerID,Score,date,type) values ('$rank[UID]','$rank[RID]','$rank[Trophy]','$date','$rank[type]')";
		mysql_query($insertsql);
	}
	while ($rank = mysql_fetch_assoc($competitiveRank)) {
		$insertsql = "insert into duel_rank (UID,ServerID,Score,date,type) values ('$rank[UID]','$rank[RID]','$rank[LadderExTrophy]','$date','$rank[type]')";
		mysql_query($insertsql);
	}
	mysql_close($conn1);
	mysql_close($conn2);
	mysql_close($conn3);
	mysql_close($conn4);
 ?>
