---
title: "在 Elasticsearch Docker 容器中，导出堆栈信息"
date: 2020-03-31T11:23:47+08:00
draft: true
tags: ["heap analysis"]
categories: ["elasticsearch","jvm"]
---

[TOC]

# 场景

因为在集群中，``GC``频繁：

![](http://img.honlyc.com/20200331112900.png)

# 初步排查

该集群的``Heap``是分配了 32G，从图中可以看到，每次都达到了 28G。

## 查看集群数据总量

```
GET /_cat/allocation?v&h=shards,disk.indices,disk.used,disk.avail
```

## 查看各节点的``segement memory``和``cache``占用量

```
GET /_cat/nodes?v&h=id,port,v,m,fdp,mc,mcs,sc,sm,qcm,fm,im,siwm,svmm
```

# Heap Dump 分析

因为通常集群的``Dump``文件都非常大，本地开发机器无法进行分析。具体如何分析超大的``Dump``文件，可以参考我之前的文章[Linux 中分析超大 JVM dump 文件](http://honlyc.com/post/linux-hrpof/)，这里我就不赘述了。

这里主要说另一个问题：``Docker``部署的集群，如何导出堆栈信息。

**注意：我这里使用的是``7.4.0``自带``jdk``的集群版本。**

## ``Docker``内进行``jmap``

当我们使用``docker exec -it es01 /bin/bash``进入到``es``的镜像内后，直接使用``jmap``是找不到的命令的。

![](http://img.honlyc.com/20200331114216.png)

不过，我们可以在这个图中发现，因为使用的是自带的``jdk``，所以我们需要使用``jdk/bin/jmap``这样来使用。

我们先尝试使用``jps``查看：

```bash
jdk/bin/jps -lv
```

可以看到，当前``es`` 的进程``PID``了（在``Docker``内，通常都是``1``）。

再使用``jstack``，尝试查看当前堆栈：

```bash
jdk/bin/jstack 1
```

却得到一个错误：

```bash
# jdk/bin/jstack 1
1: Unable to open socket file /proc/1/root/tmp/.java_pid1: target process 1 doesn't respond within 10500ms or HotSpot VM not loaded
```

通过搜索响应的解决方案，这是因为镜像内执行用户不同导致的。在[这里](https://github.com/elastic/elasticsearch/issues/50727)详细说明了如何解决，可以在``exec``时，指定用户和用户组，进入后，就可以正常执行了。

```bash
docker exec -u 1000:0 -it es01 /bin/bash
```

## Eclipse MAT

从这里下载[MAT Download](https://www.eclipse.org/mat/downloads.php)，因为集群的``Dump``文件通常有几十G了，所以在解析时，需要找一台内存大机器以及配置``MAT``的最大内存设置：

- 解压缩``MAT``后，修改``MemoryAnalyzer.ini``文件，将内存设置为``20GB``左右：

```ini
-startup
plugins/org.eclipse.equinox.launcher_1.5.0.v20180512-1130.jar
--launcher.library
plugins/org.eclipse.equinox.launcher.gtk.linux.x86_64_1.1.700.v20180518-1200
-vmargs
-Xmx20240m
```

- 将``dump``文件拷贝过来，并执行分析：

```bash
nohup ./ParseHeapDump.sh ./es_heap.bin org.eclipse.mat.api:suspects org.eclipse.mat.api:overview org.eclipse.mat.api:top_components &
echo $! > pid
```

> 这里，我使用了``nohup``，主要是因为大文件的分析比较耗时，无法保证服务端的``shell``活动时间。

等待执行完毕......

## 具体分析

