---
title: "Lucene Pure Negative Booleanquery"
date: 2021-02-24T16:00:05+08:00
draft: true
tags: ["query"]
categories: ["lucene"]
---

# 问题

在开发中遇到一个情况，在直接使用``Lucene``查询时，使用查询语句：

```
hk (-cs)
```

无法查出内容：

```
security in hk
```

但是使用``hk -(cs)``又是可以的。

同时，还存在一个情况，如果使用``ES``集群查询，又是可以的。

# 思路

一开始这个查询很复杂，排除掉了分词问题等其他问题后，简化成上述的这种情况。看起来，就是在``queryParse``时，解析出来的查询有问题。于是开始``Debug``之路：

1. 首先，我们来看下转成的最终 query 是啥：``+content:hk +(-content:cs)``，看起来有点别扭，后面这个``+(-*``应该有问题；
2. 那我们就再看一下``hk -(cs)``会转成什么样：``+content:hk -content:cs``，很明显，少了``+(``那一截，问题应该就在这了；

## 分析 Lucene 的方式

初步确定问题，我们再调试一下：

这一步是构建查询时的``Weight``，会调用一次``rewrite``

![image-20210224171330339](http://img.honlyc.com/image-20210224171330339.png)

调用后，可以看到，后面这个``+(-*``的语法，变成了一个``MatchNoDocsQuery("pure negative BooleanQuery")``，这不就是说，这个查询不匹配任何数据嘛，然后又是``MUST``，所以最后压根就查询不到数据。

![image-20210224171432672](http://img.honlyc.com/image-20210224171432672.png)

问题确定到这里，那怎么解决？这时，我想到再``ES``里面的查询是没问题的，那它又是怎么做的呢？源码翻一翻：

## 分析 ES 的方式

拿到``ES``源码，直奔``QueryStringQueryBuilder``这个类，找到``doToQuery()``方法，可以看到：

![image-20210224171959657](http://img.honlyc.com/image-20210224171959657.png)

这里，再做完``queryParase``后，多了两行转换，看方法名``query = Queries.fixNegativeQueryIfNeeded(query);``就知道，就是专门处理``pure negative BooleanQuery``的，进去再看：

```java
public static Query fixNegativeQueryIfNeeded(Query q) {
        if (isNegativeQuery(q)) {
            BooleanQuery bq = (BooleanQuery) q;
            BooleanQuery.Builder builder = new BooleanQuery.Builder();
            for (BooleanClause clause : bq) {
                builder.add(clause);
            }
            builder.add(newMatchAllQuery(), BooleanClause.Occur.FILTER);
            return builder.build();
        }
        return q;
    }
```

可以看到，当遇到``NegativeQuery``时，会增加一个``MatchAllQuery``，具体长啥样，请看：

![image-20210224172405480](http://img.honlyc.com/image-20210224172405480.png)

在原有的``+(-*``语法后，直接加了一个``#*:*``，有没有一点粗暴的感觉？它认为，你这个``纯否定语法``有问题，直接给你加个``filter all``，结果当然可以查出来数据了。

咦~，细心的你可能已经发现了，在这一步的时候，压根还没经过后面这个

```java
query = Queries.fixNegativeQueryIfNeeded(query);
```

方法，就已经转换好了，那是哪里做的呢？

这时，我们就得看这个``queryParser``具体类``QueryStringQueryParser``的内部代码了，因为这个类继承了``QueryParser``，那我们可以先看一下它覆写了哪些方法吧：

![image-20210224173128093](http://img.honlyc.com/image-20210224173128093.png)

可以看到这里有很多``getXXX()``的方法，那我们就看一下``getBooleanQuery()``：

```java
@Override
protected Query getBooleanQuery(List<BooleanClause> clauses) throws ParseException {
    Query q = super.getBooleanQuery(clauses);
    if (q == null) {
        return null;
    }
    return fixNegativeQueryIfNeeded(q);
}
```

有没有一目了然？在这里也调用了刚刚那个方法，也就是在这里就会被转换了。

到这里，我们解决方案也就有了，直接``Copy``嘛。

# 总结

在实际使用中，``ES``其实做了很多的处理，如果直接使用``Lucene``，就会碰到很多意外情况。当然，因为业务需要，我们在某些模块是直接使用的``Lucene``，而通过不断填坑，也能够让我的技术有所提升。

相对于直接一头扎进源码，我可能更喜欢带着问题去看源码，理解得更为透彻，印象也更深。

最重要的，还是要自己记录下来，如果有机会，给别人去详细地讲解一番就更能够加深理解了。

以上。