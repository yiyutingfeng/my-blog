---
title: 如何通过hadoop访问s3存储桶
date: 2023-05-30 10:14:12
tags:
    - hadoop
    - s3
categories:
    - s3
description:
    - 如何在不改变 hadoop 原有配置的情况下访问s3存储桶
---

## 在s3a配置文件所在目录下创建脚本文件并添加可执行权限

```
touch set_s3a_classpath.sh
chomod +x set_s3a_classpath.sh
```

## 复制以下内容到`set_s3a_classpath.sh`脚本文件中

``` shell
#!/bin/bash
set -euo pipefail
error_flag=0
hadoop_conf_dir=$(pwd)

# 检查并复制核心配置文件
s3a_core_file_path=$(find "$hadoop_conf_dir" -name "*core-site.xml" | head -n 1)

if [ -n "$s3a_core_file_path" ]; then
    if [ ! -e "$hadoop_conf_dir/core-site.xml" ]; then
        cp "$s3a_core_file_path" "$hadoop_conf_dir/core-site.xml"
    fi
else
    echo "找不到配置文件"
    error_flag=1
fi

# 获取Hadoop版本信息
hadoop_version=$(hadoop version | head -n 1 | awk '{print $2}')
echo "Hadoop版本为: $hadoop_version"

# 判断版本是否为CDH
if [[ "$hadoop_version" != *"-cdh"* ]]; then
    # 查找Hadoop安装目录
    hadoop_bin=$(hadoop version | tail -n 1 | awk '{print $6}')
    if [ -z "$hadoop_bin" ]; then
        echo "未找到Hadoop安装目录."
        error_flag=1
    fi

    hadoop_dir=$(dirname "$(dirname "$hadoop_bin")")

    # 查找包含S3AFileSystem类的JAR文件
    if [ -d "$hadoop_dir" ]; then
        s3a_jar_sdk_path=$(find "$hadoop_dir" -name "aws-java-sdk-bundle-*.jar" | head -n 1)
        s3a_jar_path=$(find "$hadoop_dir" -name "hadoop-aws*.jar" | head -n 1)

        if [ -z "$s3a_jar_sdk_path" ]; then
            echo "未找到S3A JAR文件."
            error_flag=1
        fi

        if [ -z "$s3a_jar_path" ]; then
            echo "未找到S3A JAR文件."
            error_flag=1
        fi

        if [ $error_flag -eq 0 ]; then
            echo "找到S3A JAR文件: $s3a_jar_sdk_path"
            export HADOOP_CLASSPATH=$(hadoop classpath):"$s3a_jar_sdk_path"

            echo "找到S3A JAR文件: $s3a_jar_path"
            export HADOOP_CLASSPATH=$(hadoop classpath):"$s3a_jar_path"
        fi
    fi
fi

if [ $error_flag -eq 0 ]; then
    # 生成log4j.properties文件
    log4j_file="$hadoop_conf_dir/log4j.properties"

    if [ ! -e "$log4j_file" ]; then
        echo "# 全局日志配置" >>"$log4j_file"
        echo "log4j.rootLogger=ERROR, console" >>"$log4j_file"
        echo "" >>"$log4j_file"
        echo "# 控制台appender配置" >>"$log4j_file"
        echo "log4j.appender.console=org.apache.log4j.ConsoleAppender" >>"$log4j_file"
        echo "log4j.appender.console.target=System.err" >>"$log4j_file"
        echo "log4j.appender.console.layout=org.apache.log4j.PatternLayout" >>"$log4j_file"
        echo "log4j.appender.console.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss} %-5p %c{1}:%L - %m%n" >>"$log4j_file"
        echo "" >>"$log4j_file"
        echo "# Hadoop S3AFileSystem日志配置" >>"$log4j_file"
        echo "log4j.logger.org.apache.hadoop.fs.s3a.S3AFileSystem=ERROR" >>"$log4j_file"

        echo "生成log4j.properties文件: $log4j_file"
    fi

    # 设置HADOOP_CONF_DIR为包含core-site.xml的目录
    export HADOOP_CONF_DIR="$hadoop_conf_dir"
    echo "添加环境变量完成."
fi

```

## 执行脚本,以设置环境变量

``` bash
. set_s3a_classpath.sh
```

## 访问s3存储桶

``` bash
hadoop fs -ls s3a://<bucket_name>/
```

如果您想屏蔽Hadoop中的日志，可以通过更改Hadoop的日志级别来实现。以下是一些步骤，可以帮助您完成这个任务：

1. 找到Hadoop的日志配置文件，`log4j.properties`
2. 打开日志配置文件，找到与S3A相关的日志记录器。在这个文件中，您可能会看到一些类似`log4j.logger.org.apache.hadoop.fs.s3a.S3AFileSystem=DEBUG`的行，这些行指定了日志级别。
3. 将日志级别调整为您想要的级别。常见的级别包括：
   - `OFF`：完全关闭日志记录。
   - `FATAL`：仅记录严重错误。
   - `ERROR`：记录错误信息。
   - `WARN`：记录警告和错误信息。
   - `INFO`：记录一般信息、警告和错误信息。
   - `DEBUG`：记录详细的调试信息。

   如果您只想屏蔽S3A的日志，可以将对应的日志记录器级别设置为`OFF`。
4. 保存并关闭日志配置文件。

以下是一个示例的log4j.properties文件，用于访问S3并屏蔽日志：

``` conf
# Global logging configuration
log4j.rootLogger=ERROR, console

# Console appender configuration
log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.target=System.err
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss} %-5p %c{1}:%L - %m%n

# Hadoop S3AFileSystem logger configuration
log4j.logger.org.apache.hadoop.fs.s3a.S3AFileSystem=ERROR
```
