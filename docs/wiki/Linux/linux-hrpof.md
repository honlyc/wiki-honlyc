---
title: "Linux 中分析超大 JVM dump 文件"
date: 2019-06-13T17:24:05+08:00
draft: true
tags: ["linux"]
categories: ["jvm"]
---

## 1. 场景

在使用``Elasticsearch``时，碰到内存溢出的情况，因为配置了``-XX:+HeapDumpOnOutOfMemoryError``索引会直接把``Dump``自动存为文件。

但是对于这类生成的文件，往往会很大：

```bash
-rw-------  1 ant ant  26G May 29 21:08 java_pid7446.hprof
```

``26G`` 的文件在服务器上该怎么分析堆栈？就算是拉取到本地，也没有这么大的内存去分析。

所以更好的办法就是直接在服务器上利用``MAT``进行分析。

对于``Dump``的生成，也可以手动导出

```bas
jmap -dump:live,format=b,file=m.hprof PID
```

## 2. 下载``Linux``下的``MAT``

下载地址：<https://www.eclipse.org/mat/downloads.php> 

下载对应的版本：



最后解压即可。

## 3. 执行分析命令

```bash
nohup ./ParseHeapDump.sh ./java_pid7446.hprof org.eclipse.mat.api:suspects org.eclipse.mat.api:overview org.eclipse.mat.api:top_components &
echo $! > pid
```

> 注意这里使用了``nohup`` ，因为对于大文件的分析，并不能保证``shell``窗口的活动时间，所以使用``nohup``，并保存了``pid``，以便于查看是否执行完毕。

等待执行完毕后，就能看到结果了：



## 4. 打开并分析报告

在拿到结果后，只需要吧三个``.zip``包传到本地，解压后，用浏览器打开网页即可。


通过这个就可以来愉快地分析啦。

## 5. 总结

这里主要是介绍如何利用服务器来分析超大的``Dump``文件，而不用担心在本地内存不够或者机器受限的问题。

而对于报告具体的分析，后续我也会分享出来，期待你的持续关注。