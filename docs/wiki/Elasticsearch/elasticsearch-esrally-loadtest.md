---
title: "Elasticsearch esrally 基准测试"
date: 2020-06-02T14:00:47+08:00
draft: true
tags: ["esrally"]
categories: ["elasticsearch","loadtest"]
---

# 前言

``esrally``是``Elasticsearch``官方出的集群基准测试框架，使用``Python``编写的。它的工作原理是：先下载需要测试的数据集，然后在本地执行测试。但因为网络原因，国内下载异常的慢，这里主要介绍如何离线使用``esrally``进行测试。

同时，因为它本身是支持``Docker``使用的，为了方便使用，我这里就主要使用``docker-compose``来进行演示。

# 准备工作

为了方便离线使用，我们需要做一些前期的准备：

## 1. 手动下载数据集

框架的默认数据集是使用的``geonames``，我们可以通过``http://benchmarks.elasticsearch.org.s3.amazonaws.com/corpora/geonames/documents-2.json.b2``这个链接先手动下载，可以使用下载工具进行下载，速度回更快，我是使用的``aria2 + uget``，几分钟就下完了。

如果在框架内下载会很慢。

其他的数据集都可以通过该方法进行下载，具体的文件名可以通过[这个项目](https://github.com/elastic/rally-tracks)中每个目录下的``files.txt``进行查看。

其中，带有``*-1k.*``的文件是``--test-mode``模式下使用的，只有少量数据，可以用来进行简单的测试检查。

## 2. 拉取``Docker``镜像

官方的镜像名为：``elastic/rally``，我这里的最新版本是``2.0.0``，所以使用

```bash
docker pull elastic/rally:2.0.0
```

进行拉取镜像。

## 3. 调整``entrypoint.sh``文件

在官方的``Dockerfile``中，使用的默认执行用户为``1000``，这里可能存在一些权限问题。同时，官方建议是把``/rally/.rally``文件夹在本地进行映射，因为一些配置，以及数据集都是在该文件夹下的，如果不进行本地映射的话，不便于结果的保存及数据集的使用。

而在映射了``/rally/.rally``文件夹后，又需要手动进行``esrally configure``，所以，我就直接调整了``entrypoint.sh``文件：

```bash
#!/usr/bin/env bash
set -Eeo pipefail

esrally configure

exec "$@"
```

## 4. 拉取``rally-tracks``项目

因为在读取数据集时，需要额外一些配置，所以我们需要将这个项目拉取到本地。

```bash
git clone https://github.com/elastic/rally-tracks.git
```

## 5. 编写``docker-compose.yml``文件

直接使用``docker run``的话，也是可以的。但为了直观和便于使用和修改，使用``docker-compose``更为友好：

```yaml
version: "2"
services:
  esrally:
    container_name: esrally
    image: elastic/rally:2.0.0
    volumes:
      - ./myrally:/rally/.rally
      - ./entrypoint.sh:/entrypoint.sh
    command: "esrally race --track=geonames --challenge=append-no-conflicts --offline --pipeline=benchmark-only --target-hosts={{es.host}}:9200"
```

简单说明一下这个文件：

1. ``- ./myrally:/rally/.rally``主要是把配置映射到本地；

2. ``- ./entrypoint.sh:/entrypoint.sh``主要是替换原有的``entrypoint.sh``文件；

3. 

   ```bash
   esrally race --track=geonames --challenge=append-no-conflicts --offline --pipeline=benchmark-only --target-hosts={{es.host}}:9200
   ```

   ``--track=geonames``，表示使用``geonames``数据集进行测试；

   ``--offline``，表示离线使用，不去下载数据集；

   ``--target-hosts={{es.host}}:9200``，表示需要测试的``ES``集群地址，端口为``Http``端口。如果不设置，``esrally``默认会自己启动一个``ES``来进行测试；

# 使用

首先，我们手动创建一个文件夹``myrally``，对应上面``docker-compose.yml``文件中的映射名称。

启动一下镜像，使之初始化：``docker-compose up``，报错不用管。这时，我们的目录结构：

```bash
.
├── docker-compose.yml
├── entrypoint.sh
├── geonames
│   └── documents-2.json.bz2
├── myrally
│   ├── benchmarks
│   ├── logging.json
│   ├── logs
│   └── rally.ini
└── rally-tracks
    ├── download.sh
    ├── eventdata
    ├── geonames
    ├── geopoint
    ├── geopointshape
    ├── http_logs
    ├── nested
    ├── noaa
    ├── nyc_taxis
    ├── percolator
    ├── pmc
    ├── README.md
    └── so
```

可以看到在``myrally``文件夹下，已经初始化了一些配置和文件。接下来，我们就可以开始正式使用了（虽然还是各种需要调整）：

1. ``Expected a git repository at [/root/.rally/benchmarks/tracks/default] but the directory does not exist``

   这个错误很明显，我们只需要手动创建对应的文件夹就好了。

2. ``[/rally/.rally/benchmarks/tracks/default] must be a git repository.\n\nPlease run:\ngit -C /rally/.rally/benchmarks/tracks/default init``

   这个错误是因为需要是``Git``目录，也已经给出了解决方案，不同的是，我们是在``myrally``文件夹下进行操作：

   ```bash
   cd myrally/benchmarks/tracks/default
   git init
   touch .gitignore
   git add .
   git commit -m "init default"
   ```

3. ``Could not load '/rally/.rally/benchmarks/tracks/default/geonames/track.json'. The complete track has been written to '/tmp/tmpyadq1aqi.json' for diagnos
   is.", '("Could not load track from \'track.json\'``

   这个错误就需要用到我们拉取下来的``rally-tracks``项目了：

   ```bash
   cp rally-tracks/geonames/ myrally/benchmarks/tracks/default/ -r
   ```

4. ``Cannot find /rally/.rally/benchmarks/data/geonames/documents-2.json.bz2. Please disable offline mode and retry again.``

   这个错误也比较明显，这时，我们就可以直接使用手动下载的数据集啦：

   ```bash
   mkdir myrally/benchmarks/data/geonames/ -P
   cp geonames/documents-2.json.bz2 myrally/benchmarks/data/geonames/
   ```

到这里，我们终于可以愉快地进行测试了。

直接运行：

```bash
docker-compose up
```

等待执行完毕就可以啦。

## 小技巧

查看日志：

```bash
less myrally/logs/rally.log
```

# 总结

``esrally``的使用还是非常方便的，只是因为网络原因，我们需要先手动下载数据集，并且修改一些配置。

从一开始的查询``docker``镜像，到自己优化镜像、再到直接使用官方提供的镜像、并调整一些参数。还是花了我半天的时间，但收获还是满满的。

有了这个基准测试，在优化集群参数，调整集群大小方面，就更有底气，也更有说服力了。

# 参考

1. [rally](https://github.com/elastic/rally)
2. [rally-trakcs](https://github.com/elastic/rally-tracks)
3. [Elasticsearch 压测方案](https://www.jianshu.com/p/c89975b50447)

