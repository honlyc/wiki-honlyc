---
title: "Elasticsearch 7.4.0 使用 Snapshot 做数据迁移"
date: 2021-07-16T20:48:13+08:00
draft: true
tags: ["auth","7.4.0"]
categories: ["elasticsearch"]#
---



## Elasticsearch Snapshot and Restore

1. ``、elasticsearch.yml``配置``path.repo``，**注意：这个目录必须是共享文件目录或者其他共享的，否则无法备份**

   ```
   path.repo: data
   ```

2. 创建``Repository``

   ```
   PUT /_snapshot/my_repository
   {
     "type": "fs",
     "settings": {
       "location": "snapshot"
     }
   }
   ```

3. Create Snapshot

   ```
   PUT /_snapshot/my_repository/mblog
   {
     "indices": "data_stream_1,index_1,index_2", // 索引
     "ignore_unavailable": true, // 是否忽略不可用的索引
     "include_global_state": false // 包含全局状态
   }
   ```

4. Snapshot Restore

   ```
   POST /_snapshot/my_repository/mblog-2/_restore
   {
     "indices": "{indexName}-*",
     "ignore_unavailable": true,
     "index_settings": {
       "index.number_of_replicas": 0
     },
     "ignore_index_settings": [
       "index.refresh_interval"
     ]
   }
   ```

## 通过 Snapshot 和 Restore 来迁移数据

迁移数据主要场景是从老集群迁移数据到新集群，因为没有存``source``就无法使用``reindex``。

主要步骤：

1. 在新集群和老集群的``path.repo``指向同一个目录；
2. 分别创建一个相同名称的``repository``;
3. 在老集群中创建一个``snapshot``;
4. 在新集群使用``restore``进行数据恢复;

