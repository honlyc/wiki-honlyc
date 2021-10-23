---
title: "Custom Elasticsearch Shard Allocation Decider"
date: 2019-11-05T16:08:31+08:00
draft: true
tags: ["plugins","shard"]
categories: ["elk"]
---

[TOC]

# 场景

对于一台机器部署了多个``ES``实例时，在分配``Shard``时，可能会存在热点的情况，如下图：

<img src="http://img.honlyc.com/a.png"  />

在同一台机器上的不同实例上，分配了两个``Primary Shard``，这样会导致这一台机器的负载要比其他的高，会影响整个集群的查询响应。

当前``ES``的配置中，并没有具体的参数可以避免这一情况，类似的参数有：

``cluster.routing.allocation.same_shard.host``：默认值是false，如果设置为true，那么就不允许将一个``primary shard``和``replica shard``分配到同一个物理机上，也许这个物理机上启动了多个es实例。

通过这个参数，我们同样可以自定义一个参数，来控制是否根据同一个机器，来进行``Shard``的分配。

# 分析源码

## 1. ``SameShardAllocationDecider``分析

由``cluster.routing.allocation.same_shard.host``这个参数，我们可以分析源码，来借鉴其中的写法。

通过查看，我们找到``org.elasticsearch.cluster.routing.allocation.decider.SameShardAllocationDecider``这个类，其中继承了抽象类``AllocationDecider``，主要实现了两个方法：

> ``public Decision canAllocate(ShardRouting shardRouting, RoutingNode node, RoutingAllocation allocation) ``
>
> ``public Decision canForceAllocatePrimary(ShardRouting shardRouting, RoutingNode node, RoutingAllocation allocation) ``

具体是代码实现相对简单：


大概逻辑是，判断``checkNode``和``Node``的``HostAddress``是否相同，如果相同，则返回不可分配的决定；如果不同，则返回可以分配的决定。

## 2. 决策器插件的加载

在``org.elasticsearch.cluster.ClusterModule``类中，可以看到``createAllocationDeciders(Settings settings, ClusterSettings clusterSettings,                                                                     List<ClusterPlugin> clusterPlugins)``方法是用来初始化所有决策器的。


我们可以通过编写``ClusterPlugin``来进行自定义决策器的加载及使用。

#  插件编写



