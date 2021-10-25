---
title: "Elasticsearch DirectMemory OOM 分析"
date: 2021-06-07T14:16:00+08:00
draft: true
tags: ["heap","OOM"]
categories: ["elasticsearch","jvm"]
---

[TOC]

# 问题

因为我们的索引集群分为天和历史，在天索引集群中，采用了自研的堆外内存插件，实现堆外的内存索引，减少GC，自主控制内存的使用。但在实际使用时，如果堆外内存大小限制不当，就会导致``OOM``，具体错误如下：

```bash
java.lang.OutOfMemoryError: Cannot reserve 131072 bytes of direct buffer memory (allocated: 17179832357, limit: 17179869184)
        at java.nio.Bits.reserveMemory(Bits.java:178) ~[?:?]
        at java.nio.DirectByteBuffer.<init>(DirectByteBuffer.java:119) ~[?:?]
        at java.nio.ByteBuffer.allocateDirect(ByteBuffer.java:320) ~[?:?]
        at com.antfact.nest.indexer.memory.ByteBufferPool.getBuffer(ByteBufferPool.java:117) ~[?:?]
        at org.apache.lucene.store.offheap.RAMOffHeapFile3.newBuffer(RAMOffHeapFile3.java:82) ~[?:?]
        at org.apache.lucene.store.offheap.RAMOffHeapFile3.addBuffer(RAMOffHeapFile3.java:50) ~[?:?]
        at org.apache.lucene.store.offheap.RAMOffHeapOutputStream3.switchCurrentBuffer(RAMOffHeapOutputStream3.java:124) ~[?:?]
        at org.apache.lucene.store.offheap.RAMOffHeapOutputStream3.writeBytes(RAMOffHeapOutputStream3.java:107) ~[?:?]
        at org.elasticsearch.common.lucene.store.FilterIndexOutput.writeBytes(FilterIndexOutput.java:59) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.index.store.Store$LuceneVerifyingIndexOutput.writeBytes(Store.java:1232) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.indices.recovery.MultiFileWriter.innerWriteFileChunk(MultiFileWriter.java:120) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.indices.recovery.MultiFileWriter.access$000(MultiFileWriter.java:43) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.indices.recovery.MultiFileWriter$FileChunkWriter.writeChunk(MultiFileWriter.java:200) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.indices.recovery.MultiFileWriter.writeFileChunk(MultiFileWriter.java:68) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.indices.recovery.RecoveryTarget.writeFileChunk(RecoveryTarget.java:469) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.indices.recovery.PeerRecoveryTargetService$FileChunkTransportRequestHandler.messageReceived(PeerRecoveryTargetService.java:518) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.indices.recovery.PeerRecoveryTargetService$FileChunkTransportRequestHandler.messageReceived(PeerRecoveryTargetService.java:492) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.transport.RequestHandlerRegistry.processMessageReceived(RequestHandlerRegistry.java:63) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.transport.InboundHandler$RequestHandler.doRun(InboundHandler.java:264) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.common.util.concurrent.ThreadContext$ContextPreservingAbstractRunnable.doRun(ThreadContext.java:773) ~[elasticsearch-7.4.0.jar:7.4.0]
        at org.elasticsearch.common.util.concurrent.AbstractRunnable.run(AbstractRunnable.java:37) ~[elasticsearch-7.4.0.jar:7.4.0]
        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128) ~[?:?]
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628) ~[?:?]
        at java.lang.Thread.run(Thread.java:830) [?:?]
```

# 问题分析

可以很直观地看到，就是在分配堆外内存的时候，无法再进行分配导致的``OOM``，源于对``JVM``的不熟悉，一开始并不知道是有参数可以设置堆外内存使用量的。

 先说``-XX:MaxDirectMemorySize``这个参数，网上资料显示，如果没有主动配置，则默认使用``-Xmx``的值，我们集群的``-Xmx``是``32G``，按道理，日志中的``limit: 17179869184``因该是``32G``才对，但实际只有``16G``，而我们的配置里面，并没有哪里配置了``16G``这个值。

### 1. 确认集群参数

由于是使用``docker``部署的集群，在查看集群参数时，可能会有一些坑，可以看我[这篇文章](http://www.honlyc.com/post/elasticsearch-docker-jvm/)，这里，我们执行命令：

```bash
docker exec -u 1000:0 -it elasticsearch bash
```

进入后，我们执行：

```bash
jdk/bin/jinfo 1
```

可以看到实例启动时的``JVM``参数有哪些，过滤一下，我们就可以看到``MaxDirectMemorySize``了：

```bash
VM Arguments:
jvm_args: -Xms32g -Xmx32g -XX:+UseG1GC -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly -Des.networkaddress.cache.ttl=60 -Des.networkaddress.cache.negative.ttl=10 -XX:+AlwaysPreTouch -Xss1m -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Djna.nosys=true -XX:-OmitStackTraceInFastThrow -Dio.netty.noUnsafe=true -Dio.netty.noKeySetOptimization=true -Dio.netty.recycler.maxCapacityPerThread=0 -Dio.netty.allocator.numDirectArenas=0 -Dlog4j.shutdownHookEnabled=false -Dlog4j2.disable.jmx=true -Djava.io.tmpdir=/tmp/elasticsearch-16662532178385968386 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=data -XX:ErrorFile=logs/hs_err_pid%p.log -Xlog:gc*,gc+age=trace,safepoint:file=logs/gc.log:utctime,pid,tags:filecount=32,filesize=64m -Djava.locale.providers=COMPAT -Djava.security.policy=/usr/share/elasticsearch/plugins/jieba/plugin-security.policy -Des.cgroups.hierarchy.override=/ -Dio.netty.allocator.type=pooled -XX:MaxDirectMemorySize=17179869184 -Des.path.home=/usr/share/elasticsearch -Des.path.conf=/usr/share/elasticsearch/config -Des.distribution.flavor=default -Des.distribution.type=docker -Des.bundled_jdk=true
```

可以看到``-XX:MaxDirectMemorySize=17179869184``这里明确设置了为``16G``，那这个参数是哪来的呢？

### 2. 官方设置的默认值

去``ES``的``Github``查查看，找到这个``Issue``，[Configure a limit on direct memory usage](https://github.com/elastic/elasticsearch/issues/41954)这里明确说明了，由于官方文档建议设置``Heap Size ``为物理内存的``50%``，而``MaxDirectMemorySize``默认又是``-Xmx``的大小，这样，会有可能导致``OOM``，所以官方就给默认设置为了``heapSize / 2 ``作为``MaxDirectMemorySize``的大小。

再看一下具体的``PR``：[Limit max direct memory size to half of heap size](https://github.com/elastic/elasticsearch/pull/42006/files)

```java
final long maxDirectMemorySize = extractMaxDirectMemorySize(finalJvmOptions);
if (maxDirectMemorySize == 0) {
ergonomicChoices.add("-XX:MaxDirectMemorySize=" + heapSize / 2);
}
```

简单直接，如果没有设置，就直接取``heapSize`` 的一半。这里，就可以解释为什么我们集群的是``16G``了，因为``heapSize``是``32G``。

# 结论

由于``ES``本身设置了堆外内存的默认值，导致我们使用自研插件时，尽管机器内存还是有，由于超出默认值，还是一样会``OOM``。

我们只需要针对我们大内存的机器，主动设置``-XX:MaxDirectMemorySize``即可。

通过分析这个问题，暴露出我对``JVM``参数的不熟悉及对``ES``整体的掌握不足，导致走了很多弯路，无法快速定位问题所在。这也更进一步惊醒自己，要多积累、多学习。

以上。

共勉。

