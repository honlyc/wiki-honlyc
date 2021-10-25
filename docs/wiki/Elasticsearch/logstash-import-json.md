---
title: "Logstash 导入 Json 文件到 Elasticsearch"
date: 2021-06-25T16:39:36+08:00
draft: true
tags: ["import"]
categories: ["elasticsearch","logstash"]
---

# 前言

因为有个临时需求，需要搭建一个``ES``集群，并导入数据。所以需要从头开始，这里主要是记录一下集群搭建、数据导入的过程。

# 部署

## Elasticsearch

因为是新集群，考虑到数据安全性，所以需要``SSL``认证，这里还是使用``docker-compose``进行部署：

参考：https://www.elastic.co/guide/en/elastic-stack-get-started/7.13/get-started-docker.html#get-started-docker-tls

```yaml
version: '2.2'

services:
  es01:
    image: docker.elastic.co/elasticsearch/elasticsearch:${VERSION}
    container_name: es01
    environment:
      - node.name=es01
      - cluster.name=es-cluster
      - discovery.seed_hosts=es01
      - cluster.initial_master_nodes=es01
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - xpack.license.self_generated.type=trial
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.key=$CERTS_DIR/es01/es01.key
      - xpack.security.http.ssl.certificate_authorities=$CERTS_DIR/ca/ca.crt
      - xpack.security.http.ssl.certificate=$CERTS_DIR/es01/es01.crt
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.security.transport.ssl.certificate_authorities=$CERTS_DIR/ca/ca.crt
      - xpack.security.transport.ssl.certificate=$CERTS_DIR/es01/es01.crt
      - xpack.security.transport.ssl.key=$CERTS_DIR/es01/es01.key
    user: "1004"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./data:/usr/share/elasticsearch/data
      - ./plugins:/usr/share/elasticsearch/plugins
      - ./logs:/usr/share/elasticsearch/logs
      - ./config:/usr/share/elasticsearch/config
      - ./certs:${CERTS_DIR}
    ports:
      - 9200:9200
    networks:
      - elastic

    healthcheck:
      test: curl --cacert $CERTS_DIR/ca/ca.crt -s https://localhost:9200 >/dev/null; if [[ $$? == 52 ]]; then echo 0; else echo 1; fi
      interval: 30s
      timeout: 10s
      retries: 5
  kib01:
    image: docker.elastic.co/kibana/kibana:${VERSION}
    container_name: kib01
    depends_on: {"es01": {"condition": "service_healthy"}}
    ports:
      - 5601:5601
    environment:
      SERVERNAME: localhost
      ELASTICSEARCH_URL: https://es01:9200
      ELASTICSEARCH_HOSTS: https://es01:9200
      ELASTICSEARCH_USERNAME: kibana
      ELASTICSEARCH_PASSWORD: Pfdx2HSSW4bWmOzHOtIH
      ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES: $CERTS_DIR/ca/ca.crt
      SERVER_SSL_ENABLED: "true"
      SERVER_SSL_KEY: $CERTS_DIR/kib01/kib01.key
      SERVER_SSL_CERTIFICATE: $CERTS_DIR/kib01/kib01.crt
    volumes:
      - ./certs:${CERTS_DIR}
    networks:
      - elastic
networks:
  elastic:
    driver: bridge
```

## Logstash

logstash 配置``config/logstash-sample.conf``：

```conf
input {
 file {
   type => "json"
   path => "/path/to/file*"
   start_position => beginning
 }
}

filter {
 json {
   source => "message"
 }

  mutate {
    remove_field => ["message", "path", "host", "@version"]
  }
}

output {
  elasticsearch {
    hosts => ["https://localhost:9200"]
    index => "index_name"
    ssl => true
    cacert => '/path/to/certs/ca/ca.crt'
    user => "changeme"
    password => "changeme"
  }
}
```

运行``logstash``:

```bash
nohup ./bin/logstash -f config/logstash-sample.conf
```