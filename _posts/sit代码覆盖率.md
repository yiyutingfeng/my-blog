---
title: sit代码覆盖率
date: 2023-04-28 14:34:07
tags:
    - 覆盖率
categories:
    - CirroData
description:
    - 通过 sit 测试生成覆盖率报告
---

1. 编译coverage版本

``` bash
./build.sh --build=coverage --pack_all=1 --pack_type=onebox all
```

2. 搭建环境,配置参数`brpc_dsink_enable`需改为`false`

3. 进行sit

4. kill 行云进程号

``` bash
kill ${pid}
```

5. 等待1分钟,查看是否生成*.gcda文件的时间是否在当前时间左右,若是则成功了
建议命令,执行效率高

``` bash
ls -lhR gcda/ | grep "\.gcda$"
```

或

``` bash
find gcda/ -name "*.gcda" -exec ls -lh {} \;
```

6. 将文件打包,并copy到代码执行编译的目录下

``` bash
tar cjf gcda.tar.bz2 gcda/*
```

7. 在编译路径下，执行report_coverage.sh脚本生成覆盖率报告（会生成coverage目录）

``` bash
./report_coverage.sh -gcda=./gcda.tar.bz2 ${模块名1} ${模块名2} ${模块名...}
```

指定模块,则生成对应模块的覆盖率文件
不指定模块,则生成整个项目的覆盖率文件

8. coverage/xcloud.report/下，执行命令

``` bash
python -m SimpleHTTPServer 12345
```

9.	查看覆盖率
在浏览器输入当前节点的IP:12345
