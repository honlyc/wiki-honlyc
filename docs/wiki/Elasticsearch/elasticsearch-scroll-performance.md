---
title: "Elasticsearch Scroll Performance"
date: 2021-02-09T13:12:46+08:00
draft: true
tags: ["scroll","7.4.0"]
categories: ["elasticsearch"]
---

# 前言

因为业务关系，我们需要从 ES 中查询出超大量的数据。其中又分为天索引及历史索引，天索引使用堆外内存进行优化，查询和索引都先走内存索引，提高效率。但是在进行``scroll``全部数据时，速度上还是很慢。

# 详细分析

因为不能直接对生产数据进行测试及调整，所以我们临时搭建一个对等的集群，并接入实时数据的索引，来进行详细的测试及分析。

集群信息如下：

elasticsearch version: 7.4.0；机器：4台；数据量：2000万；存储大小：120GB；索引个数：按天构建，一共存了两天的数据，就是两个。

在这里，我们的需求是要拿到对应查询的所有数据，就需要使用``scroll``来进行获取。``scroll``其实就是游标查询，在第一次查询时，返回一个``scrollId``，后面直接通过``scrollId``进行查询。

一开始，我们是按天进行分别查询，代码差不多就是这样，[参考官方示例](https://www.elastic.co/guide/en/elasticsearch/client/java-rest/current/java-rest-high-search-scroll.html)：

```java
final Scroll scroll = new Scroll(TimeValue.timeValueMinutes(1L));
SearchRequest searchRequest = new SearchRequest("posts");
searchRequest.scroll(scroll);
SearchSourceBuilder searchSourceBuilder = new SearchSourceBuilder();
searchSourceBuilder.query(matchQuery("title", "Elasticsearch"));
searchRequest.source(searchSourceBuilder);

SearchResponse searchResponse = client.search(searchRequest, RequestOptions.DEFAULT); 
String scrollId = searchResponse.getScrollId();
SearchHit[] searchHits = searchResponse.getHits().getHits();

while (searchHits != null && searchHits.length > 0) { 
    
    SearchScrollRequest scrollRequest = new SearchScrollRequest(scrollId); 
    scrollRequest.scroll(scroll);
    searchResponse = client.scroll(scrollRequest, RequestOptions.DEFAULT);
    scrollId = searchResponse.getScrollId();
    searchHits = searchResponse.getHits().getHits();
}

ClearScrollRequest clearScrollRequest = new ClearScrollRequest(); 
clearScrollRequest.addScrollId(scrollId);
ClearScrollResponse clearScrollResponse = client.clearScroll(clearScrollRequest, RequestOptions.DEFAULT);
boolean succeeded = clearScrollResponse.isSucceeded();
```

但是，当我们查询的数据量达百万以上时，这个整体的查询就很慢了。我们设置的每次的``size``为 5000，加入一共有 100万 数据，就相当于要遍历 200次，而每次的查询时间大概在 100ms，也就是整个 100万数据，得花 20s 才能拿到结果，这个速度完全不能接受。

于是我们就看一下查询时，热线程到底是哪些，通过``GET _nodes/hot_threads``我们可以看到：

```java
::: {node_p005063_2}{EEQPzbEvSKO3n4ip8w_u6A}{wU_AI_a5QQCecvn-K8Pb4Q}{10.20.5.63}{10.20.5.63:9501}{dl}{rack_id=rack_id_p005063, ml.machine_memory=270187814912, rack=rack_p005063, ml.max_open_jobs=20, xpack.installed=true}
   Hot threads at 2021-02-09T05:38:24.207Z, interval=500ms, busiestThreads=3, ignoreIdleThreads=true:
   
   38.7% (193.6ms out of 500ms) cpu usage by thread 'elasticsearch[node_p005063_2][search][T#188]'
     3/10 snapshots sharing following 23 elements
       app//org.apache.lucene.codecs.compressing.LZ4.decompress(LZ4.java:108)
       app//org.apache.lucene.codecs.compressing.CompressionMode$4.decompress(CompressionMode.java:138)
       app//org.apache.lucene.codecs.compressing.CompressingStoredFieldsReader$BlockState.document(CompressingStoredFieldsReader.java:555)
       app//org.apache.lucene.codecs.compressing.CompressingStoredFieldsReader.document(CompressingStoredFieldsReader.java:571)
       app//org.apache.lucene.codecs.compressing.CompressingStoredFieldsReader.visitDocument(CompressingStoredFieldsReader.java:578)
       app//org.apache.lucene.index.CodecReader.document(CodecReader.java:84)
       app//org.apache.lucene.index.FilterLeafReader.document(FilterLeafReader.java:355)
       app//org.elasticsearch.search.fetch.FetchPhase.loadStoredFields(FetchPhase.java:425)
       app//org.elasticsearch.search.fetch.FetchPhase.getSearchFields(FetchPhase.java:232)
       app//org.elasticsearch.search.fetch.FetchPhase.createSearchHit(FetchPhase.java:214)
       app//org.elasticsearch.search.fetch.FetchPhase.execute(FetchPhase.java:162)
       app//org.elasticsearch.search.SearchService.lambda$executeFetchPhase$6(SearchService.java:502)
       app//org.elasticsearch.search.SearchService$$Lambda$4350/0x0000000801904440.get(Unknown Source)
       app//org.elasticsearch.search.SearchService.lambda$runAsync$2(SearchService.java:344)
       app//org.elasticsearch.search.SearchService$$Lambda$4352/0x0000000801904c40.accept(Unknown Source)
       app//org.elasticsearch.action.ActionRunnable$1.doRun(ActionRunnable.java:45)
       app//org.elasticsearch.common.util.concurrent.AbstractRunnable.run(AbstractRunnable.java:37)
       app//org.elasticsearch.common.util.concurrent.TimedRunnable.doRun(TimedRunnable.java:44)
       app//org.elasticsearch.common.util.concurrent.ThreadContext$ContextPreservingAbstractRunnable.doRun(ThreadContext.java:773)
       app//org.elasticsearch.common.util.concurrent.AbstractRunnable.run(AbstractRunnable.java:37)
       java.base@13/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128)
       java.base@13/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628)
       java.base@13/java.lang.Thread.run(Thread.java:830)
       ...
       //日志太长，我就只放一部分了
```

我们能够通过这个结果，获取很多信息，我们一一来解析：

```
::: {node_p005063_2}{EEQPzbEvSKO3n4ip8w_u6A}{wU_AI_a5QQCecvn-K8Pb4Q}{10.20.5.63}{10.20.5.63:9501}{dl}{rack_id=rack_id_p005063, ml.machine_memory=270187814912, rack=rack_p005063, ml.max_open_jobs=20, xpack.installed=true}
```

结果第一行，包括了节点的身份，因为集群中有很多个节点，这里说明了该线程属于哪个节点、哪个索引以及一些属性。

```
38.7% (193.6ms out of 500ms) cpu usage by thread 'elasticsearch[node_p005063_2][search][T#188]'
```

而这里可以看到 38.7% 的 CPU 处理花费在 ``search``（搜索）线程上，这里很关键，因为可以调优导致 CPU 高峰的搜索查询，而且，这里最好是不要总是出现搜索。还有其他如：merge、index等类型。

```
     3/10 snapshots sharing following 23 elements
```

在堆栈轨迹（stackTrace)之前的一行说明，Elasticsearch 在几毫秒中进行了 10次快照，然后发现拥有如下同样堆栈轨迹的线程在这 3 次中都出现了。

```
       app//org.apache.lucene.codecs.compressing.LZ4.decompress(LZ4.java:108)
       app//org.apache.lucene.codecs.compressing.CompressionMode$4.decompress(CompressionMode.java:138)
       app//org.apache.lucene.codecs.compressing.CompressingStoredFieldsReader$BlockState.document(CompressingStoredFieldsReader.java:555)
       app//org.apache.lucene.codecs.compressing.CompressingStoredFieldsReader.document(CompressingStoredFieldsReader.java:571)
       app//org.apache.lucene.codecs.compressing.CompressingStoredFieldsReader.visitDocument(CompressingStoredFieldsReader.java:578)
       app//org.apache.lucene.index.CodecReader.document(CodecReader.java:84)
       app//org.apache.lucene.index.FilterLeafReader.document(FilterLeafReader.java:355)
       app//org.elasticsearch.search.fetch.FetchPhase.loadStoredFields(FetchPhase.java:425)
       app//org.elasticsearch.search.fetch.FetchPhase.getSearchFields(FetchPhase.java:232)
       app//org.elasticsearch.search.fetch.FetchPhase.createSearchHit(FetchPhase.java:214)
       app//org.elasticsearch.search.fetch.FetchPhase.execute(FetchPhase.java:162)
```

通过堆栈轨迹，我们可以看到，大部分都是在执行``LZ4.decompress()``这个方法，而这个主要从``FetchPhase``来的，``Fetch``是查询的第二个阶段，对应``ES``的``QUERY_THEN_FETCH``，这里我们后面可以再展开讲。

这里正好可以对应到我们的查询中去，因为我们使用``scroll``，第一阶段的``Query``是很快的，但在第二阶段时，因为我们需要拿到 100万 的数据，所以就一直在做``Fetch``操作，而``Fetch``就是通过``lucene``的``docId``（注意：这个``docId``是``int``类型的那个``lucene内部id``）去获取实际我们存的``_id``，这也是我们最终拿到的数据（我们的``_source:false``，查询只返回所有的``_id``)。

# 优化方案

既然问题已经确认了，就得想解决方案，找了一圈，定了几个备用方案：

1. 使用``QUERY_AND_FETCH``，这是``ES``的另一种``searchType``，是一把查出来，不存在两阶段查询，可惜，在新版本已经被废弃掉了，连代码都删了。
2. 修改不用``LZ4``压缩，是不是可以降低在解压缩时的耗时，提升``Fetch``阶段的效率？
3. 现在查询 100万 完全是串行的，下一个查询得等待上一个查询的结果，有没有办法做到并发查，比如：100万 数据分 10个线程一起查。

