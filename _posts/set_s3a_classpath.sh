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
