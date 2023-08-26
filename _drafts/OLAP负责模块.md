---
title: OLAP负责模块
date: 2023-08-25 16:19:35
tags:
categories:
    - CirroData
description:
    概述自己 OLAP 负责的模块
---


## 维护模块

1. DATE 数据类型
2. INTERVAL 数据类型
3. TIMESTAMP 数据类型
4. NUMBER 数据类型
5. LOB 数据类型
6. 动态参数

## 已完成开发的

| 需求 | 开发需求单 | 编码提交单单号 |
| --- | :---: | :---: |
| 增加SQL支持修改存储容量类型参数的参数值带单位的功能 | #26225 | #27045 |
| 增加HDFS文件句柄缓存 | #30171 | #23531 |
| 增加用于远程读取的数据缓存 | #31500 | #31824 |
| 远程读数据缓存使用场景优化 | #36257 | #36778 |

## 已开发完成，但未合并到3.0

| 需求 | 开发需求单 | 编码提交单单号 | 开发分支 |
| --- | :---: | :---: | :---: |
| 新增BIT位串 | #34278 | #35038 | FeatureBranch/2.16 |
| 文件外部表&Export支持CEPH对象存储 | #39084 | #43649 | Requirement/3.0/39084 |

## 可参考文档

[CirroData NUMBER 数据类型](https://yiyutingfeng.github.io/2022/07/11/55/)
[CirroData LOB 数据类型](https://yiyutingfeng.github.io/2022/07/05/32/)
[动态参数](https://yiyutingfeng.github.io/2022/07/19/49/)
[本地数据缓存](https://yiyutingfeng.github.io/2022/07/19/52/)
[负责模块相关配置参数](https://yiyutingfeng.github.io/2023/01/12/33/)