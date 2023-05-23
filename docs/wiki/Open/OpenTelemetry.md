

Tracing：提供了一个请求从接收到处理完毕整个生命周期的跟踪路径，通常请求都是在分布式的系统中处理，所以也叫做分布式链路追踪。
Metrics：提供量化的系统内/外部各个维度的指标，一般包括Counter、Gauge、Histogram等。
Logging：提供系统/进程最精细化的信息，例如某个关键变量、事件、访问记录等。

这三者在可观察性上缺一不可：基于Metrics的告警发现异常，通过Tracing定位问题（可疑）模块，根据模块具体的日志详情定位到错误根源，最后再基于这次问题调查经验调整Metrics（增加或者调整报警阈值等）以便下次可以更早发现/预防此类问题。

[TOC]

# 大纲

1. 提出问题：如何让线上程序不再是「黑盒」。
2. 引出应用可观测性概念，并进行介绍说明。
3. 可观测性主要分为Tracing、Metrics、Logging；这三者在可观察性上缺一不可：基于Metrics的告警发现异常，通过Tracing定位问题（可疑）模块，根据模块具体的日志详情定位到错误根源，最后再基于这次问题调查经验调整Metrics（增加或者调整报警阈值等）以便下次可以更早发现/预防此类问题。
4. 结合智妍、报表服务，讲解实操及具体案例。
5. 总结应用可观测性的易接入、效果好、可实操的优势。

# 预告

你还在苦苦思考如何定位线上问题吗？你还在万千日志中翻来覆去寻找错误日志吗？你还在一个一个排查具体是哪个环节报错吗？

敬请锁定我的分享，让你线上问题一秒定位、错误日志自动关联、错误环节自动展示；让程序分分钟由「黑盒」变成让人放心的「白盒」。

# 场景

## 场景一

业务发现公司表数据对不上，这个时候应该怎么处理这个问题？

1. 依次查看五台机器是否有报错
2. 对应请求，找到实际的异常堆栈（请求多、日志多）
3. 根据异常找到具体问题

那接入可观测之后可以怎么处理呢？

1. 查看是否有错误的请求，点击对应的详情即可看到具体的异常堆栈。

有没有更好的方案？

1. 监控错误请求，进行告警；
2. 走在业务前面，提前把错误修复好；

## 参考

https://www.dynatrace.cn/resources/blog/what-is-opentelemetry-2/

https://lib.jimmysong.io/tag/opentelemetry/

[OpenTelemetry For Developers](https://www.slideshare.net/kbrockhoff/opentelemetry-for-developers)

[可观测性 — Overview](https://blog.csdn.net/Jmilk/article/details/126337586)

[直播回顾｜携手 Opentelemetry 中国社区，走进可观测性](http://blog.daocloud.io/8225.html)

[关于OpenTelementry一些思考](https://developer.aliyun.com/article/741307)

[OpenTelemetry 快速入门](https://github.com/open-telemetry/docs-cn/blob/main/QUICKSTART.md#%E4%B8%8A%E4%B8%8B%E6%96%87%E4%BC%A0%E6%92%AD)