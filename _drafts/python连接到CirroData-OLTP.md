---
title: python连接到CirroData-OLTP
date: 2023-10-23 17:29:56
tags:
categories:
    - CirroData-OLTP
description:
    - 如何使用python访问CirroData-OLTP
---


## 安装CirroData-OLTP

安装并启动CirroData-OLTP

## 安装MySQL驱动程序`mysql-connector-python`

- 前提

python 需要2.7.5及以上版本

- 有网络环境

执行以下命令进行安装

``` bash
pip install mysql-connector-python
```

- 无网络环境

1. 下载离线安装包[mysql-connector-python-8.0.18.tar.gz](https://downloads.mysql.com/archives/get/p/29/file/mysql-connector-python-8.0.18.tar.gz)

2. 执行以下命令进行安装

``` bash
tar xvfz mysql-connector-python-8.0.18.tar.gz
cd mysql-connector-python-8.0.18
python setup.py install --prefix=/path/to/your/directory
```

`--prefix=/path/to/your/directory`为可选项,`/path/to/your/directory`是你希望安装mysql-connector-python的路径，根据实际情况进行调整

## python连接CirroData-OLTP示例:

``` py
#!/usr/bin/env python
# coding=utf-8

import sys

# 手动安装mysql-connector-python且指定了安装路径则需要将安装路径添加到Python模块搜索路径,路径至少要精确到site-packages目录
sys.path.append("/path/to/your/directory/lib/python3.6/site-packages")
import mysql.connector

# 连接到MySQL服务器
conn = mysql.connector.connect(
    host='127.0.0.1',   # 连接名称，默认127.0.0.1
    user='root',        # 用户名
    passwd='password',  # 密码，若无密码删除改行
    port=4486,          # 端口，默认为3306，修改为CirroData-OLTP配置的端口号
    db='test'           # 数据库名称
)

# 创建游标对象
cursor = conn.cursor()

# 执行SQL查询
cursor.execute("SHOW DATABASES;")

# 检索查询结果
results = cursor.fetchall()

# 打印结果
for row in results:
    print(row)

# 关闭游标和连接
cursor.close()
conn.close()
```

执行脚本

``` bash
python show_databases.py
```

![show_databases](/images/python连接到CirroData-OLTP/show_databases.png)


更多API介绍详见[Connector/Python API Reference](https://dev.mysql.com/doc/connector-python/en/connector-python-reference.html)
