---
title: "Docker 部署 Elasticsearch 7.4.0 集群并添加安全认证"
date: 2020-03-16T20:48:13+08:00
draft: true
tags: ["auth","7.4.0"]
categories: ["elasticsearch"]
---

本文主要介绍基于``Docker``部署时，``Elasticsearch``如何添加认证。

# 主要步骤

## 1. 生成认证秘钥

使用一个镜像，专门生成一个秘钥，使用``p12``模式的秘钥。

```yml
version: '2'
services:
  create_certs:
    container_name: create_certs
    image: docker.elastic.co/elasticsearch/elasticsearch:7.4.0
    command: >
      bash -c '
        if [[ ! -f /certs/elastic.p12 ]]; then
          bin/elasticsearch-certutil cert -out /certs/elastic.p12 -pass "";
        fi;
        chown -R 1000:0 /certs
      '
    user: "0"
    working_dir: /usr/share/elasticsearch
    volumes: ['./certs:/certs', '.:/usr/share/elasticsearch/config/certificates']

volumes: {"certs"}
```

## 2. 映射秘钥文件

映射秘钥文件时要注意，要映射到``config``文件夹下去，否则会有权限问题。

```yml
version: '2'
services:
 {name}_1:
    image: docker.antfact.com/platform/elasticsearch:7.4.0
    container_name: {name}_1
    network_mode: "host"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./data:/usr/share/elasticsearch/data
      - ./config:/usr/share/elasticsearch/config
      - ./logs:/usr/share/elasticsearch/logs
      - ./certs:/usr/share/elasticsearch/config/certs:rw
#      - ./plugins:/usr/share/elasticsearch/plugins
    ports:
      - 9200:9200
      - 9201:9201
```

## 3. 配置``elasticsearch.yml``文件

```yml
  xpack.security.enabled: true
  xpack.license.self_generated.type: basic
  xpack.security.transport.ssl.enabled: true
  xpack.security.transport.ssl.verification_mode: certificate
  xpack.security.transport.ssl.keystore.path: /usr/share/elasticsearch/config/certs/elastic.p12
  xpack.security.transport.ssl.truststore.path: /usr/share/elasticsearch/config/certs/elastic.p12
```

## 4. 生成账号和密码

主要是生成默认的账号和密码，这里选择的是随机生成密码，这个密码就需要保存好。

```yml
docker exec {es_docker_name} /bin/bash -c "bin/elasticsearch-setup-passwords \
auto --batch"
```

执行后的结果是这样的：

```bash
Changed password for user apm_system
PASSWORD apm_system = {pwd}

Changed password for user kibana
PASSWORD kibana = {pwd}

Changed password for user logstash_system
PASSWORD logstash_system = {pwd}

Changed password for user beats_system
PASSWORD beats_system = {pwd}

Changed password for user remote_monitoring_user
PASSWORD remote_monitoring_user = {pwd}

Changed password for user elastic
PASSWORD elastic = {pwd}
```

## 5. 配置``Kibana``

``Kibana``配置比较简单的方法就是直接明文写上账号和密码：

```yml
version: '2'
services:
  {name}_kibana:
    image: docker.antfact.com/platform/kibana:7.4.0
    container_name: {name}_kibana
    network_mode: "host"
    ports:
      - 5601:5601
    environment:
      SERVER_NAME: {name}_kibana
      SERVER_HOST: {host}
      ELASTICSEARCH_HOSTS: http://{host}:9200
      ELASTICSEARCH_USERNAME: "kibana"
      ELASTICSEARCH_PASSWORD: "{pwd}"
```

# 自动化部署

基于这种认证集群时，如果是自动化部署，就需要提前生成好一个秘钥，然后把秘钥分发到所有机器上去。

1. 这里就有一个问题，如果是不同集群，是否可以用同一个秘钥？
2. 在运维界面，账号和密码该如何保存？
3. 不同集群间的账号如果快捷管理和维护？

# 问题解决

## 1. ``certs``文件映射时的路径

一开始，我映射的``certs``路径为``/usr/share/elasticsearch/certs``,启动就报了``elasticsearch ssl access denied ("java.io.FilePermission）``的错误；

以为是权限问题，就把权限改为了``0666``，还是不行。

这其实是因为``ES``本身对文件目录做了权限的控制，在重新映射为``/usr/share/elasticsearch/config/certs``之后，就可以使用了。

## 2. ``java.io.IOException: toDerInputStream rejects tag type 80``问题

这个问题是生成的方式不对，如果想直接用``p12``方式的话，直接

```bash
bin/elasticsearch-certutil cert -out /certs/elastic.p12 -pass ""
```

即可，不需要加类似``--pem``的参数。

