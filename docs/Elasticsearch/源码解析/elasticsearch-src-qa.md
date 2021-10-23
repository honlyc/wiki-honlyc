---
title: "Elasticsearch 源码解析 Q&A"
date: 2021-01-26T17:38:41+08:00
draft: true
tags: ["source","7.4.0"]
categories: ["elasticsearch"]
---

## 1. AccessControlException

在调试``ES``源码时，如果我们需要直接用到``FSDirectory.open(Paths.get(indexPath));``这种的话，通常会碰到权限问题：

```
java.security.AccessControlException: access denied ("java.io.FilePermission" "D:\" "read")
```

其他比如接入``Hadoop``时，会有网络请求权限等，都属于权限问题

### 解决方案

这个时候，就需要修改本地``Java``的权限文件了，在``%JAVA_HOME%/lib/security/``下的``default.policy``或者``java.policy``文件，我们需要在最后加入内容：

```
grant {
    permission java.io.FilePermission "<<ALL FILES>>","read,write,delete";
    // 需要其他权限也加入到这里即可
    ...
};
```

