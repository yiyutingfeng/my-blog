---
title: s3a
date: 2023-04-03 09:09:05
tags:
categories:
description:
---

hadoop s3a 支持测试

<!-- more -->

### 确定每次I/O量

|  | 最大读取长度 | 最大写长度 |
| --- | --- | --- |
| csv | csv_file_max_buffer_size (默认16M) 或<br>csv_file_with_clob_max_buffer_size(默认64M) | csv_file_max_buffer_size (默认16M) 或<br>csv_file_with_clob_max_buffer_size(默认64M) |
| 标准parquet | 无限制,取决于标准parquet记录的下次读取长度| arrow控制，具体不知 |
| orc | 256KB |  |
| remote hdfs | 64KB |
| s3a | 128KB, 每次实际读取长度未知 | |
| libs3 | int32_max | 5GB |

#### 问题：
1. csv，orc类型文件可以控制，读取数据量，但parquet无法控制
2. 测试不同API性能，如何控制I/O，尤其s3a读取的不确定性


### 若开发测试
1. 为测试s3a 与 libs3, parser解析增加s3a://${buck\_name}/[${key}]?coreSiteFile=${core_site_xml_path}，以使得可同时测试s3a 与 libs3
2. 计划增加s3a处理
3. ClientCacheHdfs与HdfsAccessService添加s3a连接

#### 问题:
1. s3a使用hdfs逻辑，还是新增封装
2. 测试流程所说的写数据源，使用内存如何实现，即写测试数据源是什么
