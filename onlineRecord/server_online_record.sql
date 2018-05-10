/*
Navicat MySQL Data Transfer

Source Server         : 127.0.0.1
Source Server Version : 50617
Source Host           : localhost:3306
Source Database       : ccu

Target Server Type    : MYSQL
Target Server Version : 50617
File Encoding         : 65001

Date: 2018-05-09 10:02:49
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `server_online_record`
-- ----------------------------
DROP TABLE IF EXISTS `server_online_record`;
CREATE TABLE `server_online_record` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `serverid` int(11) unsigned NOT NULL COMMENT '服务器时间',
  `online` int(11) unsigned NOT NULL COMMENT '在线人数',
  `addtime` varchar(50) NOT NULL COMMENT '添加时间',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of server_online_record
-- ----------------------------
