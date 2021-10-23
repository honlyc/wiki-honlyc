---
title: "Iceberg in Action 1"
date: 2021-09-17T09:27:09+08:00
draft: true
tags: ["iceberg","flink"]
categories: ["data lake"]
---



# 部署

## 安装 hadoop

1. 下载

   ```bash
   Hadoop ：https://archive.apache.org/dist/hadoop/core/hadoop-2.7.7/	
   ```

2. 解压

   ```bash
   tar -xvf hadoop-2.7.7.tar.gz
   ```

3. 配置环境变量

   ```bash
   export HADOOP_HOME=/path/to/hadoop-2.7.7
   export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
   export HADOOP_HDFS_HOME=$HADOOP_HOME
   export PATH=$PATH:$HADOOP_HOME/bin
   ```

4. 执行``source``

   ```bash
   source .bash_profile
   ```

5. 验证

   ```
   hadoop version
   ```

6. 配置``Hadoop``

   进入``~/etc/hadoop/`` 目录

   配置``hadoop-env.sh``配置：

   ```bash
   export JAVA_HOME=/path/to/java/
   ```

   配置``core-site.xml``:

   ```xml
   <configuration>
       <property>
           <name>fs.defaultFS</name>
           <value>hdfs://localhost:9000</value>
       </property>
   </configuration>
   ```

   配置``hdfs-site.xml``:

   ```xml
   <configuration>
     <configuration>
       <property>
         <name>dfs.replication</name>
         <value>1</value>
       </property>
       <property>
         <name>dfs.namenode.name.dir</name>
         <value>file:/path/to/hadoop/hdfs/namenode</value>
       </property>
       <property>
         <name>dfs.datanode.data.dir</name>
         <value>file:/path/to/hadoop/hdfs/datanode</value>
       </property>
     </configuration>
   </configuration>
   ```

   格式化``hdfs``:

   ```bash
   hdfs namenode -format
   ```

   启动``hadoop``:

   ```bash
   cd {hadoop_home}/sbin
   ./start-all.sh	
   ```

   查看启动是否正常：

   ```bash
   jps
   1986 Jps
   41715 SecondaryNameNode
   41460 DataNode
   41287 NameNode
   39660 ResourceManager
   ```

   出现``NameNode``和``DataNode``表示已经正常启动

   **注意：启动的时候，需要对机器做``ssh``免登入，包括本机也是，否则无法启动。**

## 配置 Flink

Flink的接入，可以参照[官方文档](https://iceberg.apache.org/flink/)来，我这里简单列一下步骤：

1. 下载 Flink

   ```bash
   FLINK_VERSION=1.11.1
   SCALA_VERSION=2.12
   APACHE_FLINK_URL=archive.apache.org/dist/flink/
   wget ${APACHE_FLINK_URL}/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz
   tar xzvf flink-${FLINK_VERSION}-bin-scala_${SCALA_VERSION}.tgz
   ```

2. 在``Hadoop``环境中启动一个独立的``Flink``集群

   ```bash
   # HADOOP_HOME is your hadoop root directory after unpack the binary package.
   export HADOOP_CLASSPATH=`$HADOOP_HOME/bin/hadoop classpath`
   
   # Start the flink standalone cluster
   ./bin/start-cluster.sh
   ```

3. 启动``Flink SQL Client``客户端

   ```bash
   # download Iceberg dependency
   ICEBERG_VERSION=0.11.1
   MAVEN_URL=https://repo1.maven.org/maven2
   ICEBERG_MAVEN_URL=${MAVEN_URL}/org/apache/iceberg
   ICEBERG_PACKAGE=iceberg-flink-runtime
   wget ${ICEBERG_MAVEN_URL}/${ICEBERG_PACKAGE}/${ICEBERG_VERSION}/${ICEBERG_PACKAGE}-${ICEBERG_VERSION}.jar
   
   # download the flink-sql-connector-hive-${HIVE_VERSION}_${SCALA_VERSION}-${FLINK_VERSION}.jar
   HIVE_VERSION=2.3.6
   SCALA_VERSION=2.11
   FLINK_VERSION=1.11.0
   FLINK_CONNECTOR_URL=${MAVEN_URL}/org/apache/flink
   FLINK_CONNECTOR_PACKAGE=flink-sql-connector-hive
   wget ${FLINK_CONNECTOR_URL}/${FLINK_CONNECTOR_PACKAGE}-${HIVE_VERSION}_${SCALA_VERSION}/${FLINK_VERSION}/${FLINK_CONNECTOR_PACKAGE}-${HIVE_VERSION}_${SCALA_VERSION}-${FLINK_VERSION}.jar
   
   # open the SQL client.
   /path/to/bin/sql-client.sh embedded \
       -j ${ICEBERG_PACKAGE}-${ICEBERG_VERSION}.jar \
       -j ${FLINK_CONNECTOR_PACKAGE}-${HIVE_VERSION}_${SCALA_VERSION}-${FLINK_VERSION}.jar \
       shell
   ```

4. 简单使用

   ```sql
   -- 1. 创建 hadoop_catalog
   CREATE CATALOG hadoop_catalog WITH (
     'type'='iceberg',
     'catalog-type'='hadoop',
     'warehouse'='hdfs://localhost:9000/user/hive/warehouse',
     'property-version'='1'
   );
   
   -- 2. 创建 database
   CREATE DATABASE iceberg_db;
   
   use iceberg_db;
   
   -- 3. 创建非分区表和分区表；
   CREATE TABLE `hadoop_catalog`.`iceberg_db`.`sample` (
        id BIGINT COMMENT 'unique id',
        data STRING
    );
    
    CREATE TABLE `hadoop_catalog`.`iceberg_db`.`sample_partition` (
       id BIGINT COMMENT 'unique id',
       data STRING
   ) PARTITIONED BY (data);
   
   -- 4. 插入数据
   insert into `hadoop_catalog`.`iceberg_db`.`sample` values (1,'test1');
   insert into `hadoop_catalog`.`iceberg_db`.`sample` values (2,'test2');
    
   INSERT into `hadoop_catalog`.`iceberg_db`.sample_partition PARTITION(data='city') SELECT 86;
   
   -- 5. 查询数据
   
   select * from `hadoop_catalog`.`iceberg_db`.`sample`;
   select * from `hadoop_catalog`.`iceberg_db`.`sample` where id=1; 
   select * from `hadoop_catalog`.`iceberg_db`.`sample` where data='test1';
   
   ```

5. 

```sql
CREATE CATALOG hive_catalog WITH (
  'type'='iceberg',
  'catalog-type'='hive',
  'uri'='thrift://localhost:9083',
  'clients'='5',
  'property-version'='1',
  'warehouse'='hdfs://localhost:9000/user/hive/warehouse'
);
```

hadoop_catalog

```sql
CREATE CATALOG hadoop_catalog WITH (
  'type'='iceberg',
  'catalog-type'='hadoop',
  'warehouse'='hdfs://localhost:9000/user/hive/warehouse',
  'property-version'='1'
);
```



# 遇到问题

1. hadoop 启动的时候，需要做免登入，本机也一样。
2. ``iceberg``无法用于全文检索，但可以用于标签检索。

# 参考

[基于 Flink+Iceberg 构建企业级实时数据湖](https://xie.infoq.cn/article/e5d0422e873b6f299b104dac6)

[Flink Learning](https://flink-learning.org.cn/article?tab=Iceberg&page=1)

[通俗易懂了解什么是数据仓库](https://xie.infoq.cn/article/0c97e738280ae9d19dca5b90f)

[Flink + Iceberg 全场景实时数仓的建设实践_腾讯](https://zhuanlan.zhihu.com/p/347660549)

[Flink + Iceberg + 对象存储，构建数据湖方案_阿里](https://zhuanlan.zhihu.com/p/389904827)

[基于 Flink+Iceberg 构建企业级实时数据湖](https://cloud.tencent.com/developer/article/1797918)

