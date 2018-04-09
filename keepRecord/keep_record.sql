/*
Navicat MySQL Data Transfer

Source Server         : 127.0.0.1
Source Server Version : 50617
Source Host           : localhost:3306
Source Database       : test

Target Server Type    : MYSQL
Target Server Version : 50617
File Encoding         : 65001

Date: 2018-03-15 13:53:00
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `keep_record`
-- ----------------------------
DROP TABLE IF EXISTS `keep_record`;
CREATE TABLE `keep_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `loginNum` int(11) NOT NULL DEFAULT '0' COMMENT '登录人数',
  `regNum` int(11) NOT NULL COMMENT '当日注册',
  `keepDay` int(11) NOT NULL DEFAULT '0' COMMENT '留存日',
  `time` date NOT NULL COMMENT '当天时间',
  `addtime` datetime NOT NULL COMMENT '添加时间',
  PRIMARY KEY (`id`),
  KEY `date` (`time`),
  KEY `keep` (`keepDay`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of keep_record
-- ----------------------------
