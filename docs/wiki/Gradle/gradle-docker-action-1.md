---
title: "Gradle Docker Action 1"
date: 2021-05-14T21:49:24+08:00
draft: true
tags: ["docker"]
categories: ["gradle"]
---

# 场景

因为最近在转用``Gradle``进行项目的编译，所以很多以前用``maven``的地方，还是有非常多的不同。这里主要针对``Docker``的使用，来进行记录。

# 方案



# 坑

## 1. Windows 下的``entrypoint.sh``无法执行

假如你是使用``windows``，创建一个``entrypoint.sh``文件后，会发现``build``出来的镜像无法执行，会报错：

```bash
standard_init_linux.go:211: exec user process caused "no such file or directory"
```

恭喜你，又踩到了一个``windows``下编码的坑。因为是在``windows``下创建的文件，所以编码会是``dos``，而并非``unix``，这会导致在``docker``内执行时，会无法正常解析该文件，所以报错。

解决方案也相对简单，不过首先你得有``git bash``这种``unix``编辑环境，就可以修改编码了：

```bash
# 打开文件
vi entrypoint.sh
# 设置编码
:set ff=unix
# 保存
:wq
```

再重新``build``镜像，就可以正常执行啦。

