/*
Navicat MySQL Data Transfer

Source Server         : 127.0.0.1
Source Server Version : 50617
Source Host           : localhost:3306
Source Database       : logclear

Target Server Type    : MYSQL
Target Server Version : 50617
File Encoding         : 65001

Date: 2017-11-08 16:15:04
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for `goodslog`
-- ----------------------------
DROP TABLE IF EXISTS `goodslog`;
CREATE TABLE `goodslog` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `amout` int(11) NOT NULL DEFAULT '0' COMMENT '合计',
  `orderId` varchar(24) NOT NULL DEFAULT '' COMMENT '订单ID',
  `regionId` int(11) NOT NULL DEFAULT '0' COMMENT '区ID',
  `price` int(11) NOT NULL DEFAULT '0' COMMENT '价格',
  `purchaseId` int(11) NOT NULL DEFAULT '0' COMMENT '购买ID',
  `goodsName` char(255) NOT NULL DEFAULT '' COMMENT '商品名称',
  `userId` int(11) NOT NULL DEFAULT '0' COMMENT '用户ID',
  `time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of goodslog
-- ----------------------------
INSERT INTO `goodslog` VALUES ('1', '6480', '20171012153739BNBG25', '10002', '648', '1466', '6480', '236', '2017-10-12 15:37:38');
