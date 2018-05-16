/*
Navicat MySQL Data Transfer

Source Server         : 127.0.0.1
Source Server Version : 50617
Source Host           : localhost:3306
Source Database       : duel_rank

Target Server Type    : MYSQL
Target Server Version : 50617
File Encoding         : 65001

Date: 2018-05-11 14:48:50
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `duel_rank`
-- ----------------------------
DROP TABLE IF EXISTS `duel_rank`;
CREATE TABLE `duel_rank` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `UID` char(100) NOT NULL DEFAULT '' COMMENT 'UID',
  `Name` char(100) NOT NULL DEFAULT '' COMMENT '用户名',
  `ServerID` int(11) NOT NULL DEFAULT '0' COMMENT '服务器ID',
  `Score` int(11) NOT NULL DEFAULT '0' COMMENT '分数（法老遗产）',
  `date` datetime NOT NULL,
  `type` enum('2','1') NOT NULL COMMENT '类型(1,区排行,2,总排行)',
  PRIMARY KEY (`id`),
  KEY `date` (`date`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='巅峰对决排名记录表';

-- ----------------------------
-- Records of duel_rank
-- ----------------------------
