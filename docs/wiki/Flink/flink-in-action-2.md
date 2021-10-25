---
title: "Flink in Action (2)-Flink 使用 Hadoop 进行存储"
date: 2020-10-10T11:25:18+08:00
draft: true
tags: ["gradle","flink","hadoop"]
categories: ["flink"]
---

**本文基于 Hadoop-2.8.3 和 Flink-1.11.2-scala-2.11**



# 问题

### Hadoop classpath/dependencies

这个问题主要是在 flink 中，没有hadoop 的 jar 包，需要手动下载并拷贝到``${FLINK_HOME}/lib``目录下。

可以在[https://repo1.maven.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/](https://repo1.maven.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/)这个地址，选择下载对应版本的``jar``包，然后拷贝到``{$FLINK_HOME}/lib/``目录下，重启即可。

