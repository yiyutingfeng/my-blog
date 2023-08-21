---
title: SQL
date: 2022-07-08 15:19:37
tags:
categories:
description:
    - CirroData 的一些常用或可能会用到的SQL
---

### 删除非空数据库

``` sql
DROP DATABASE db_name CASCADE
```

### 删除非空用户

``` sql
DROP USER user_name CASCADE
```

### 动态参数

``` sql
-- cluster用户
ALTER DATABASE dbname SET PARAMETER parameter_name = 'parameter_value';
SELECT * FROM V$CLUSTER_PARAMETERS_INFO;

-- db用户
ALTER SYSTEM PARAM SET parameter_name = 'parameter_value';
ALTER PC PARAM SET pc_name.parameter_name = 'parameter_value';
SELECT * FROM V$DB_PARAMETERS_INFO;
```

### 查询有哪些系统表

``` sql
SELECT * FROM V$SYS_VTABLES_VIEW;
```

### GB18030

``` sql
CREATE DATABASE DB_GB18030 CHARACTER SET 'GB18030' COMMENT 'GB18030'
```

### 创建有序表
``` sql
CREATE /*+ORDERED_TABLE*/ TABLE table_name(id LONG, name STRING, birthday DATE) SLICED BY(birthday, name, id) INTO 1 SLICES
```
### 检查是否为有序表
``` sql
select table_name, is_ordered from v$user_tables
```

### 查看当前DB空闲节点
``` sql
select * from V$DB_FREE_PUS;
```

### 清除DB的所有进程组配置信息(systemadmin用户)
```
ALTER PC CONFIG CLEAN ALL ON db_name;
```