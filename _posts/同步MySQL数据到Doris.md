---
title: 同步MySQL数据到Doris
date: 2023-12-15 09:56:48
tags:
    - CATALOG
    - MySQL
categories:
    - doris
description: 使用jdbc,通过创建CATALOG加载MySQL数据到Doris
---


## 下载驱动程序

``` shell
wget https://cdn.mysql.com//Downloads/Connector-J/mysql-connector-j-8.2.0.tar.gz .
tar xvfz mysql-connector-j-8.2.0.tar.gz
```

也可以去MySQL官网下载其他版本[Connector/J](https://dev.mysql.com/downloads/connector/j/)
建议选择**Platform Independent**的压缩包，解压即可使用

![Alt text](/images/同步MySQL数据到Doris/Connector_J.png)

## be和fe配置jdbc驱动目录

``` conf
jdbc_drivers_dir = /root/doris/mysql-connector-j-8.2.0
```

![Alt text](/images/同步MySQL数据到Doris/配置jdbc驱动目录.png)

## 从MySQL导入数据到Doris示例

1. 创建目标表

``` sql
CREATE TABLE example_tbl (
    id INT COMMENT "id",
		name VARCHAR(20)  COMMENT "name"
)
DISTRIBUTED BY HASH(id) BUCKETS 10
PROPERTIES("replication_num" = "1");
```

2. 创建 MySQL CATALOG

``` sql
-- CREATE CATALOG jdbc_mysql PROPERTIES (
--     "type"="jdbc",
--     "user"="root",
--     "password"="123456",
--     "jdbc_url" = "jdbc:mysql://172.16.48.9:4486/demo",
--     "driver_url" = "mysql-connector-j-8.2.0.jar",
--     "driver_class" = "com.mysql.jdbc.Driver"
-- )

CREATE CATALOG jdbc_mysql PROPERTIES (
    "type"="jdbc",
    "user"="root",
    "jdbc_url" = "jdbc:mysql://172.16.48.9:4486",  -- 可以不指定具体数据库
    "driver_url" = "mysql-connector-j-8.2.0.jar",
    "driver_class" = "com.mysql.jdbc.Driver"
);
```

![Alt text](/images/同步MySQL数据到Doris/CREATE_CATALOG.png)

3. 查看 CATALOGS

``` sql
SHOW CATALOGS;
```

![Alt text](/images/同步MySQL数据到Doris/SHOW_CATALOGS.png)


4. 插入数据

``` sql
-- INSERT INTO <doris_Catalog_Name>.<db_name>.<table_name> SELECT * FROM <mysql_Catalog_Name>.<db_name>.<table_name>;
INSERT INTO internal.demo.example_tbl SELECT * FROM jdbc_mysql.demo.t1;

-- 由于当前在 doris CATALOG 下,可以省略Catalog_Name与db_name
INSERT INTO example_tbl SELECT * FROM jdbc_mysql.demo.t1;
```

![Alt text](/images/同步MySQL数据到Doris/insert.png)

5. 可以切换使用 MySQL 环境

``` sql
switch jdbc_mysql;

-- 当前在MySQL CATALOG 下, 可以省略Catalog_Name与db_name
INSERT INTO internal.demo.example_tbl SELECT * FROM t1;
```