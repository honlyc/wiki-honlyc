---
title: "Elasticsearch Docker Jvm Crash"
date: 2021-08-04T09:21:43+08:00
draft: true
tags: ["crash"]
categories: ["elasticsearch","jvm"] 
---

# 前言

今天上班日常巡检，发现一个``ES``集群报``Red``了，一看状态，应该是有一台机器挂了。赶紧查看问题

# 问题确认

登录到指定机器后，发现是磁盘满了，但问题是我使用的是``/data1``盘，为啥``/``目录会满掉？由于是部署到``Docker``的，大概率是这里有问题。

找运维确认一下，发现是镜像内有一个``/usr/share/elasticsearch/core.1``这个文件超级大，``193G``直接把根目录占满了。

我们先确认一下这个是啥文件，看起来不是``ES``正常产生的文件，因为没有做映射，导致直接写到了根目录，没有写到映射目录。

通过搜索，发现也有其他人遇到过这个问题，[看这里](https://discuss.elastic.co/t/es-6-4-3-docker-container-keep-crash-with-error-code-139/164684/6)说的是，在``Docker``内使用``Java 10``的话，有一些实验性的功能不稳定，需要设置``JVM``参数：

```bash
-XX:UseAVX=2
```

具体的``Issue``可以看这里：https://github.com/elastic/elasticsearch/issues/31425#issuecomment-402522285

# 暴露的问题

1. 通过``Docker``部署后，有些没映射的目录和文件，会直接写到根目录，极有可能导致磁盘被写满；
2. 因为前期的集群调整，导致有部分索引没有``replica``，所以在一台机器挂掉后，会直接导致集群状态变为``Red``，需要及时检查和告警集群内索引的复制数，防止机器挂掉后的集群不可用；
