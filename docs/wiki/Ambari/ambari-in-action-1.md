---
title: "Ambari 的安装"
date: 2020-02-20T14:49:01+08:00
draft: true
tags: ["install"]
categories: ["ambari"]
---

[TOC]

因为各种原因，如果直接用``Ambari``的官方包进行安装时，速度会极慢，而官方本身也是支持离线安装的。所以，本文使用离线安装的方式。

## 一、下载离线包

离线包的地址可以在官网找到：[Ambari](https://docs.cloudera.com/HDPDocuments/Ambari-2.7.4.0/bk_ambari-installation/content/hdp_314_repositories.html)

Ambari 2.7.4：http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.7.4.0/ambari-2.7.4.0-centos7.tar.gz

HDP-3.1.4.0：

HDP：http://public-repo-1.hortonworks.com/HDP/centos7/3.x/updates/3.1.4.0/HDP-3.1.4.0-centos7-rpm.tar.gz

HDP-UTILS：http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.22/repos/centos7/HDP-UTILS-1.1.0.22-centos7.tar.gz

HDP-GPL：http://public-repo-1.hortonworks.com/HDP-GPL/centos7/3.x/updates/3.1.4.0/HDP-GPL-3.1.4.0-centos7-gpl.tar.gz

```bash
http://10.20.1.21/HDP/centos7/3.1.4.0-315/
http://10.20.1.21/HDP-UTILS/centos7/1.1.0.22/
http://10.20.1.21/HDP-GPL/centos7/3.1.4.0-315/
```

## 二、安装 Nginx，并搭建本地源

主要通过``docker``来进行搭建，快捷。

```yml
version: "2"
services:
  nginx:
    image: nginx:${NGINX_VERSION}
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /home/user/ambari/data:/var/www/html/ambari/:rw
      - ${NGINX_CONFD_DIR}:/etc/nginx/conf.d/:rw
      - ${NGINX_CONF_FILE}:/etc/nginx/nginx.conf:ro
      - ${NGINX_LOG_DIR}:/var/log/nginx/:rw
    restart: always
```

配置文件``.env``:

```bash
NGINX_VERSION=latest
NGINX_HTTP_HOST_PORT=80
NGINX_HTTPS_HOST_PORT=443
NGINX_CONFD_DIR=./conf/conf.d
NGINX_CONF_FILE=./conf/nginx.conf
NGINX_LOG_DIR=./log
```

### nginx 配置

在``nginx.conf``中，``http``字段添加：

```c
autoindex on;
autoindex_exact_size on;
 autoindex_localtime on;
```

添加``defaul.conf``文件到``conf.d``文件夹中：

```
server {
    listen       80;
    server_name  p001021.antfact.com;
    root   /var/www/html/ambari;
    index  index.php index.html index.htm index.xml;

    #location / {
    #    root ambari;
    #}
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

}
```

### 解压下载好的离线包

```
tar -zxvf HDP-GPL-3.1.4.0-centos7-gpl.tar.gz -C /home/user/ambari/data/
tar -zxvf HDP-3.1.4.0-centos7-rpm.tar.gz  -C /home/user/ambari/data/
tar -zxvf HDP-UTILS-1.1.0.22-centos7.tar.gz -C /home/user/ambari/data/
tar -zxvf ambari-2.7.4.0-centos7.tar.gz -C /home/user/ambari/data/
```

## 三、配置本地 Repo

1. 下载相关工具

   ```bash
   yum install -y yum-utils
   yum repolist
   yum install -y createrepo wget
   ```

2. 配置 Ambari Repo

   ```bash
   // 下载2.7.4.0版本的ambari.repo
   # wget -O /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.7.4.0/ambari.repo
   ```

3. 修改``ambari.repo``文件

   将``baseurl``替换成我们自己``Nginx``搭建的地址，这里注意，先自己访问一下地址，可能路径名称有些不一样。

   ```bash
   #VERSION_NUMBER=2.7.4.0-118
   [ambari-2.7.4.0]
   #json.url = http://public-repo-1.hortonworks.com/HDP/hdp_urlinfo.json
   name=ambari Version - ambari-2.7.4.0
   baseurl=http://192.168.200.20/ambari/centos7/2.7.4.0-118/
   gpgcheck=1
   gpgkey=http://192.168.200.20/ambari/centos7/2.7.4.0-118/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
   enabled=1
   priority=1
   ```

4. 修改``hdp.repo``文件

   同样的，下载并修改``hdp.repo``文件。

   ```bash
   
   #VERSION_NUMBER=3.1.4.0-315
   [HDP-3.1.4.0-315]
   name=HDP Version - HDP-3.1.4.0-315
   baseurl=http://192.168.200.20/HDP/centos7
   gpgcheck=1
   gpgkey=http://192.168.200.20/HDP/centos7/3.1.4.0-315/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
   enabled=1
   priority=1
    
   [HDP-UTILS-1.1.0.22]
   name=HDP-UTILS Version - HDP-UTILS-1.1.0.22
   baseurl=http://192.168.200.20/HDP-UTILS/
   gpgcheck=1
   gpgkey=http://192.168.200.20/HDP-UTILS/centos7/1.1.0.22/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
   enabled=1
   priority=1
   ```

5. 生成本地源

   ```bash
   createrepo /psth_to_ambari/HDP/centos7/
   createrepo /psth_to_ambari/HDP-UTILS/
   ```

   

# Elasticsearch

https://github.com/steven-dfheinz/dfhz_elk_mpack



# 遇到问题

## 1. getpwuid() Error

> 提示: 如果安装配置用户时，出现如下报错：
> ERROR: Unexpected error 'getpwuid(): uid not found: 1001'
>
> 可以查看ambari.repo文件的权限，修改为默认的root 644权限即可。

## 2. Elasticsearch 

对``ambari-server``执行命令：

```bash
python /var/lib/ambari-server/resources/scripts/configs.py -u admin -p admin -n [CLUSTER_NAME] -l [CLUSTER_FQDN] -t 8080 -a set -c cluster-env -k  ignore_groupsusers_create -v true
```