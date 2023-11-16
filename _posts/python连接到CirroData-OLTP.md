---
title: python连接到CirroData-OLTP
date: 2023-10-23 17:29:56
tags:
categories:
    - CirroData-OLTP
description:
    - 如何使用python访问CirroData-OLTP
---


### 运行CirroData-OLTP

确保CirroData-OLTP已经安装并在你的系统上运行。

### 安装MySQL驱动程序 `mysql-connector-python`

确保你的Python版本符合要求，并且可以在有网络环境（python最低要求为3.11版本）或无网络环境（python最低要求为2.7版本）下安装MySQL驱动程序。

#### 在有网络环境下安装：

```bash
pip3 install mysql-connector-python
```

这将自动下载并安装最新版本的MySQL驱动程序。

#### 在无网络环境下安装：

1. 下载离线安装包 [mysql-connector-python-8.0.18.tar.gz](https://downloads.mysql.com/archives/get/p/29/file/mysql-connector-python-8.0.18.tar.gz) 到你的系统中。

2. 使用以下命令解压缩文件：

```bash
tar xvfz mysql-connector-python-8.0.18.tar.gz
```

3. 进入解压后的目录：

```bash
cd mysql-connector-python-8.0.18
```

4. 执行以下命令进行安装，可以指定安装路径：

```bash
python setup.py install --prefix=/path/to/your/directory
```

`--prefix=/path/to/your/directory` 是可选项，用于指定你希望安装mysql-connector-python的路径。

### Python连接CirroData-OLTP示例

以下是Python脚本示例，用于连接到CirroData-OLTP服务器并执行查询：

```python
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

确保按照脚本中的注释更改连接参数以匹配你的CirroData-OLTP配置。
通过执行上述脚本，你可以连接到CirroData-OLTP服务器并执行查询。这个示例中的查询是 `SHOW DATABASES;`，你可以根据你的需要更改查询。

执行脚本

``` bash
python show_databases.py
```

![show_databases](/images/python连接到CirroData-OLTP/show_databases.png)


更多API介绍详见[Connector/Python API Reference](https://dev.mysql.com/doc/connector-python/en/connector-python-reference.html)
