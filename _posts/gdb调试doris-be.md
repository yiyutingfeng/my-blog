---
title: gdb调试doris_be
date: 2023-12-20 15:49:20
tags:
categories:
description: Doris BE开发调试环境
---

## 环境准备

### 使gdb调试时，能正确访问源码的方法

1. 若测试环境与编译环境在同一个节点，在使用docker时映射源码路径与真实源码路径完全一致即可

例如:
``` bash
-v /data1/workspace/gaoyuanfeng/gyf-doris/doris:/data1/workspace/gaoyuanfeng/gyf-doris/doris
```

2. 若测试环境与编译环境不在同一个节点，那么只需要在测环境下放置一份代码，代码所在路径要与编译环境的路径一致

### 检查测试环境gdb版本

要求gdb版本不低于10.2

``` bash
gdb --version
```

若无网环境，可手动安装gdb 14.1，以下是手动安装gdb到用户目录下的示例：

1. 先下载并上传以下安装包到服务器用户根目录下

[gmp-6.3.0](https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz)
[mpfr-4.2.1](https://www.mpfr.org/mpfr-current/mpfr-4.2.1.tar.gz)
[gdb-14.1](https://ftp.gnu.org/gnu/gdb/gdb-14.1.tar.gz)

2. 执行以下操作
``` bash
cd
mkdir .gmp .mpfr .gdb
tar xvf /gmp-6.3.0.tar.xz
cd gmp-6.3.0
./configure --prefix=$HOME/.gmp
make -j64
make install
cd
tar xvfz mpfr-4.2.1.tar.gz
cd mpfr-4.2.1
./configure --prefix=$HOME/.mpfr --with-gmp=$HOME/.gmp
make -j64
make install
cd
tar xvfz gdb-14.1.tar.gz
cd gdb-14.1
./configure --prefix=$HOME/.gdb --with-gmp=$HOME/.gmp --with-mpfr=$HOME/.mpfr
make -j64
make install
cd
echo 'export PATH=$HOME/.gdb/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

可根据需求自行修改安装目录

## 编译debug版doris_be

``` bash
BUILD_TYPE=Debug sh build.sh
```

## gdb调试

1. fe.conf添加配置

目的：避免因为gdb调试中因超过心跳时间限制导致超时，进而SQL执行报错而终止

``` conf
max_backend_heartbeat_failure_tolerance_count = 100
```

[参数官方说明](https://doris.apache.org/zh-CN/docs/dev/admin-manual/config/fe-config/#max_backend_heartbeat_failure_tolerance_count)

2. 启动doris

3. 调试

``` bash
gdb -p {be_pid}
```

## 使用vscode调试

1. 安装 C/C++ 插件，也可下载离线包进行安装[cpptools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools)

![Alt text](/images/gdb调试doris-be/cpptools.png)

2. 配置launch.json, 也可在工作目录下手动创建 .vscode/launch.json

``` json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) Attach",
            "type": "cppdbg",
            "request": "attach",
            "program": "/data09/workspace/gaoyuanfeng/gyf-doris/doris/output/be/lib/doris_be",
            "processId": "${command:pickProcess}",
            "MIMode": "gdb",
            "miDebuggerPath": "/home/gaoyuanfeng/.gdb/bin/gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ]
        },
        {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "/data09/workspace/gaoyuanfeng/gyf-doris/doris/output/be/lib/doris_be",
            "args": [],
            "stopAtEntry": false,
            "cwd": "/data09/workspace/gaoyuanfeng/gyf-doris/doris/output/be",
            "environment": [
                {
                    "name": "DORIS_HOME",
                    "value": "/data09/workspace/gaoyuanfeng/gyf-doris/doris/output/be"
                },
                {
                    "name": "UDF_RUNTIME_DIR",
                    "value": "/data09/workspace/gaoyuanfeng/gyf-doris/doris/output/be/lib/udf-runtime"
                },
                {
                    "name": "LOG_DIR",
                    "value": "/data09/workspace/gaoyuanfeng/gyf-doris/doris/output/be/log"
                },
                {
                    "name": "PID_DIR",
                    "value": "/data09/workspace/gaoyuanfeng/gyf-doris/doris/output/be/bin"
                }
            ],
            "externalConsole": false,
            "MIMode": "gdb",
            "miDebuggerPath": "/home/gaoyuanfeng/.gdb/bin/gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ]
        }
    ]
}
```

根据实际情况修改gdb等路径

3. 演示

![Alt text](/images/gdb调试doris-be/gdb.png)
![Alt text](/images/gdb调试doris-be/调试.png)
