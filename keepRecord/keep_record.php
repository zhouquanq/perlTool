<?php 
    // date_default_timezone_set('PRC');
    date_default_timezone_set("Etc/GMT+5"); 
    //后台管理服务器
    $con = mysql_connect("127.0.0.1","root","YMuOR9MI3fQDk6UxjNlT");
    if (!$con){
        die('Could not connect: ' . mysql_error());
    }
    mysql_select_db("managerserver", $con);
    $result = mysql_query("SELECT * FROM serverlist where sl_id>10000");
    $date = date("Y-m-d H:i:s",time());
    $yesterday = date("Y-m-d", strtotime("-1 day", strtotime($date)));
    // var_dump($date);
    $i = array(2,4,8,16,31);
    // $row 服务器
    while($row = mysql_fetch_array($result)){
        // echo $row['sl_id'];
        mysql_select_db("ygo_{$row['sl_id']}", $con);
        foreach ($i as $k => $v) {
            $day = date("Y-m-d", strtotime("-$v day", strtotime($date)));
            $keeps = mysql_query("select count(*) as total from tb_user where LastLogin like '{$yesterday}%' and RegDate like '{$day}%'");
            $regs = mysql_query("select count(*) as total from tb_user where RegDate like '{$day}%'");
            $keeps = mysql_fetch_array($keeps);
            $regs = mysql_fetch_array($regs);
            $keep = $keeps['total'];
            $reg = $regs['total'];
            // var_dump("insert into keep_record (loginNum,regNum,keepDay,time,addtime) values ($keep,$reg,$v-1,'$day','$date')");
            //留存添加到数据库
            mysql_query("insert into keep_record (loginNum,regNum,keepDay,time,addtime) values ($keep,$reg,$v-1,'$day','$date')");
        }
    }
    mysql_close($con);
?>
