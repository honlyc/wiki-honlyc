---
title: "Elasticsearch Unassigned Process"
date: 2019-08-02T14:18:00+08:00
draft: true
---

# 问题

在使用``ES``时，有时候在服务器突然挂掉后重启时，会导致有``Shard``的状态变成 了``UNASSIGEND``,此时，本身集群的数据是不准确的，因为这一个``Shard``的数据丢失了。这个时候，就需要手动去处理了。

# 解决方法

## 1. 直接强制分配一个空的``shard``

``ES``可以直接强制分配一个空的主``shard``，此时原本的数据就会丢失了。

请求：

```json
POST _cluster/reroute
{
  "commands": [
    {
      "allocate_empty_primary": {
        "index": "{{index_name}}",
        "shard": {{shard_num}},
        "node": "{{target_node}}",
        "accept_data_loss" : true
      }
    }
  ]
}
```

这种适合于不需要保留数据的情况。

## 2.  从旧数据强制分配一个``shard``

当某一个``shard``状态为``unassigned``时，并不一定表示它的数据丢失了，我们可以通过索引的``uuid``来进行查找，看是否还有保留在某一台机器上。

```bash
find data -name {{uuid}} | xargs ls
```

通过这个命令，就可以找到对应的目录下是否有响应``shard``的数据。

**注意： 这个命令需要在当前集群的所有机器上执行，才能确保能够找到**

当我们找到数据之后，只需要调用响应的``API``即可强制分配到当前机器，使得数据得以恢复过来：

```json
POST _cluster/reroute
{
  "commands": [
    {
      "allocate_stale_primary": {
        "index": "{{index_name}}",
        "shard": {{shard_num}},
        "node": "{{target_node}}",
        "accept_data_loss" : true
      }
    }
  ]
}
```

