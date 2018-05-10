<?php 
	date_default_timezone_set('PRC');
	$mysql_conf = array(
	    'host'    => '10.10.133.13', 
	    'db'      => 'managerserver', 
	    'db_user' => 'root', 
	    'db_pwd'  => 'YMuOR9MI3fQDk6UxjNlT', 
	    );
	$mysql_conn = @mysql_connect($mysql_conf['host'], $mysql_conf['db_user'], $mysql_conf['db_pwd']);
	if (!$mysql_conn) {
	    die("could not connect to the database:\n" . mysql_error());//诊断连接错误
	}
	mysql_query("set names 'utf8'");//编码转化
	$select_db = mysql_select_db($mysql_conf['db']);
	if (!$select_db) {
	    die("could not connect to the db:\n" .  mysql_error());
	}
	$selecesql = "select * from server_online;";
	$res = mysql_query($selecesql);
	if (!$res) {
	    die("could get the res:\n" . mysql_error());
	}

	//把当前时间插入记录表
	while ($row = mysql_fetch_assoc($res)) {
	    $insertsql = "insert into server_online_record (serverid,online,addtime) values ('$row[serverid]','$row[online]','$row[addtime]')";
		mysql_query($insertsql);
		$date = $row['addtime'];
	}

	//删除3小时之前的记录
	$date = date("Y-m-d H:i:s",strtotime($date)-3610*24); 
	// var_dump($date);
	$delsql = "delete from server_online_record where addtime < '$date'";
	mysql_query($delsql);
	mysql_close($mysql_conn);
 ?>
