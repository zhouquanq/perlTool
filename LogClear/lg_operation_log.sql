/*
Navicat MySQL Data Transfer

Source Server         : 127.0.0.1
Source Server Version : 50617
Source Host           : localhost:3306
Source Database       : logclear

Target Server Type    : MYSQL
Target Server Version : 50617
File Encoding         : 65001

Date: 2017-11-30 18:59:36
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `lg_operation_log`
-- ----------------------------
DROP TABLE IF EXISTS `lg_operation_log`;
CREATE TABLE `lg_operation_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增ID',
  `rid` varchar(18) NOT NULL DEFAULT '0' COMMENT '服务器ID',
  `uid` int(11) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `level` int(11) NOT NULL DEFAULT '1' COMMENT '等级',
  `vipLevel` int(11) NOT NULL DEFAULT '0',
  `do` varchar(100) NOT NULL DEFAULT '' COMMENT '操作',
  `resource` char(255) NOT NULL DEFAULT '' COMMENT '资源得失',
  `date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '时间',
  PRIMARY KEY (`id`),
  KEY `do` (`do`),
  KEY `id` (`id`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of lg_operation_log
-- ----------------------------
