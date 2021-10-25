---
title: "Presto in Action 1"
date: 2021-06-02T13:29:40+08:00
draft: true
tags: ["presto"]
categories: ["bigdata"]
---

[TOC]

# 前言

公司因为架构调整，需要进行数据的实时加载。原本的方案是直接通过客户端查询索引，同时通过索引返回的``id``查询详情，整个流程比较复杂，并且其中涉及到索引压力大，无法及时加载完毕；针对大数据任务，延迟很大，无法做到实时分析。

这里，了解到``Presto``是一个分布式的查询引擎，本身也是支持各种数据源：Hadoop、Elasticsearch、MySQL等。所以尝试使用``Presto``进行数据加载，具体效果还得验证过后才知道，在这里作为一个记录。

## 安装``Presto``

在[Presto官网](https://prestodb.io/download.html)可以直接下载，分为三个包：

[presto-server-0.253.1.tar.gz](https://repo1.maven.org/maven2/com/facebook/presto/presto-server/0.253.1/presto-server-0.253.1.tar.gz)：这个是服务端的包，使用这个进行部署及配置；

[presto-cli-0.253.1-executable.jar](https://repo1.maven.org/maven2/com/facebook/presto/presto-cli/0.253.1/presto-cli-0.253.1-executable.jar)：这个是命令行模式的客户端，可以直接连接服务端，直接进行一些操作；

[presto-jdbc-0.253.1.jar](https://repo1.maven.org/maven2/com/facebook/presto/presto-jdbc/0.253.1/presto-jdbc-0.253.1.jar)：这个就是``Java``的``JDBC``驱动了，引入后，就可以在程序中连接``Presto``了；

### 使用 docker 部署

1. 准备

   在使用``docker``部署前，我们先需要准备几个文件夹和文件：

   ```bash
   mkdir data etc
   ```

   编辑``etc/node.properties``文件内容为：

   ```properties
   // 表示环境，可以用 TEST/production
   node.environment=production
   // 实例的唯一 ID，同一台机器不同实例的时候，必须保证不同；同一个实例重启、恢复后，需要保持不变，否则无法恢复到原有实例
   node.id=ffffffff-ffff-ffff-ffff-ffffffffffff
   // 实例的数据目录，用来存放数据、日志等
   node.data-dir=/var/presto/data
   ```

   编辑``etc/config.properties``文件内容为：

   ```properties
   // 是否为协调节点
   coordinator=true
   node-scheduler.include-coordinator=true
   // 实例端口
   http-server.http.port=8080
   discovery-server.enabled=true
   // 界面地址
   discovery.uri=http://localhost:8080
   ```

   编辑``etc/jvm.config``文件内容为：

   ```bash
   -server
   // 根据实际情况修改堆大小
   -Xmx1G
   -XX:+UseG1GC
   -XX:G1HeapRegionSize=32M
   -XX:+UseGCOverheadLimit
   -XX:+ExplicitGCInvokesConcurrent
   -XX:+HeapDumpOnOutOfMemoryError
   -XX:+ExitOnOutOfMemoryError
   -Djdk.attach.allowAttachSelf=true
   ```

2. 编写``docker-compose.yml``文件

   ```yaml
   version: "2"
   services:
     presto:
       image: ahanaio/prestodb-sandbox:0.254
       volumes:
         - ./data:/var/presto/data
         - ./etc:/opt/presto-server/etc
       ports:
         - 8080:8080
       container_name: presto
   ```

3. 启动

   启动直接使用下列命令即可：

   ```bash
   docker-compose up -d
   ```

4. 访问界面

   在启动成功后，就可以访问``http://host:8080``查看了。

## 简单使用

使用``docker``部署后，就可以进入命令行模式进行使用了：

```bash
docker exec -it presto  presto-cli
```

常用命令：

```bash
// 查看库
show catalogs;
// 查看指定库内的 schema
show schemas in {catalog};
// 进入指定库的 schema
use {catalog}.{schema};
// 查看 schema 中的表；
show tables;
// 查询表
select * from {table} limit 1;
```

# 数据源接入

``Presto``的一大优势就是可以接入不同的数据，并且进行联合查询、聚合及操作；

## Elasticsearch 接入

1. 先准备一个``es``集群，创建一个索引：

   ```json
   PUT users/_mapping/_doc
   {
   "properties": {
     "key": {
       "type": "keyword"
     },
     "username": {
       "type": "keyword"
     },
     "email": {
       "type": "keyword"
     }
   }
   }
   ```

   

2. 编写`$PRESTO_HOME/etc/catalog/elasticsearch.properties`文件：

   ```properties
   connector.name=elasticsearch
   elasticsearch.host=localhost
   elasticsearch.port=9200
   elasticsearch.default-schema-name=my_schema
   ```

3. 编写``$PRESTO_HOME/etc/elasticsearch/my_schema.users.json``文件：

   ```json
   {
     "tableName": "users",
     "schemaName": "my_schema",
     "clusterName": "elasticsearch",
     "index": "users",
     "type": "doc",
     "columns": [
         {
             "name": "key",
             "type": "varchar",
             "jsonPath": "key",
             "jsonType": "varchar",
             "ordinalPosition": "0"
         }
     ]
   }
   ```

4. 连接``presto``:

   ```bash
   docker exec -it presto  presto-cli
   ```

5. 查询

   ```sql
   SELECT * FROM users LIMIT 1;
   ```

这样，就是``Elasticsearch``的完整接入了，如果是多个集群，只需要添加对应的``catalog``及``schema``文件，然后重启``presto``集群即可。

