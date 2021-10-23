---
title: "Ambari 支持多集群管理"
date: 2020-04-14T16:34:08+08:00
draft: true
tags: ["custom","cluster"]
categories: ["ambari"]

---

**注意： 本文使用的版本是``Ambari 2.7.4`` **

# 场景

在使用``Ambari``的时候，它本身默认是只能管理一个集群的。这在实际使用的时候，会比较不方便，尤其是如果用来管理``ElasticSearch``，``Redis``一类的集群时，因为集群数量多，就更加捉襟见肘了。

而如果想要管理多个集群，要么就付费使用``Clouder Manager``企业版，这个是支持多集群管理的；或者就一个集群对应一个``Ambari``，分别访问；另外就只能自己进行二次开发了，其实``Ambari``本身是可以通过``Rest API``创建多个集群的，只是在``Ambari-Web``项目中，只能看到一个。

# 代码分析

前面也说了，实际``Ambari``是支持多集群管理的，只是``ambari-web``项目只能看到一个。而``ambari-web``项目就是用``ember.js``写的前端项目，实际都是使用``Rest API``调用``ambari-server``的。

因为我不是很会前端代码，而且也没有使用过``ember``框架，所以看在分析代码时，还是比较费劲，让我们一起来进行分析吧。

首先，我们可以在``app/app.js``文件中，找到一个``clusterName``的属性定义，然后全局搜索这个属性，寻找看哪个地方进行了赋值。

一个一个排除中......

最后，我们可以看到在这个文件中``app/controllers/global/cluster_controller.js``，有这样的代码：

```javascript
  /**
   * load cluster name
   */
  loadClusterName: function (reload, deferred) {
    var dfd = deferred || $.Deferred();

    if (App.get('clusterName') && !reload) {
      App.set('clusterName', this.get('clusterName'));
      this.set('isClusterNameLoaded', true);
      dfd.resolve();
    } else {
      App.ajax.send({
        name: 'cluster.load_cluster_name',
        sender: this,
        data: {
          reloadPopupText: Em.I18n.t('app.reloadPopup.noClusterName.text'),
          errorLogMessage: 'failed on loading cluster name',
          callback: this.loadClusterName,
          args: [reload, dfd],
          shouldUseDefaultHandler: true
        },
        success: 'reloadSuccessCallback',
        error: 'reloadErrorCallback',
        callback: function () {
          if (!App.get('currentStackVersion')) {
            App.set('currentStackVersion', App.defaultStackVersion);
          }
        }
      }).then(
        function () {
          dfd.resolve();
        },
        null
      );
    }
    return dfd.promise();
  },
```

可以看到，这个就是用来加载集群名称的，然后可以看到回调方法为：

```javascript
reloadSuccessCallback: function (data) {
    this._super();
    if (data.items && data.items.length > 0) {
        App.setProperties({
        clusterId: data.items[0].Clusters.cluster_id,
        clusterName: data.items[0].Clusters.cluster_name,
        currentStackVersion: data.items[0].Clusters.version,
        isKerberosEnabled: data.items[0].Clusters.security_type === 'KERBEROS'
      });
      this.set('isClusterNameLoaded', true);
    }
  },
```

哈哈～～，请允许我嘚瑟一下，这部分代码相当的一目了然：如果集群的数量大于``0``时，只取第一个集群，并设置给``App``。

貌似找到了关键代码，那就得先验证是否可行了。

# 验证

因为是纯前端框架，我们修改这部分代码时，可以不用进行打包，直接修改服务端的文件即可。

在服务端，编辑``/usr/lib/ambari-server/web/javascript/app.js``这个文件，找到前面所说的代码，并做修改：

```javascript
reloadSuccessCallback: function (data) {
    this._super();
    if (data.items && data.items.length > 0) {
        App.setProperties({
        clusterId: data.items[1].Clusters.cluster_id,
        clusterName: data.items[1].Clusters.cluster_name,
        currentStackVersion: data.items[1].Clusters.version,
        isKerberosEnabled: data.items[1].Clusters.security_type === 'KERBEROS'
      });
      this.set('isClusterNameLoaded', true);
    }
  },
```

> 注意：在进行这个修改之前，需要通过``Rest Api``再创建一个集群，保证当前``Ambari``中，有两个集群存在，否则会报错的。

这里可以看到，我把集群的获取下标改为了``1``，因为当前``Ambari``拥有两个集群，所以这个就会是取第二个集群，而不是默认的第一个。

保存文件，直接刷新``Ambari``的管理页面。

搞定！可以看到，集群变为了第二个，证明这个方法是可行的。当然，我们不可能每次切换集群时，都去手动修改下标吧。让我们再来优化一下。Comn On～ 

# 优化

这里的优化思路就是把集群名字加到页面的``Url``中去，比如：``?cluster=cluster1``，因为页面是纯前端项目，所有请求都是通过异步加载的，没有改变本身页面的``url``，所以这个方法也是可行的。

还是修改上面的文件：``/usr/lib/ambari-server/web/javascript/app.js``，上代码：

```javascript
reloadSuccessCallback: function (data) {
    this._super();
    if (data.items && data.items.length > 0) {
        var cluster = window.location.search.match(/cluster=([^&]+)/);
        if (cluster && cluster.length > 1) {
            cluster = cluster[1];
        }
        console.log("cluster: ",cluster)

        let clusterInfo = data.items[0];

        for(let i in data.items){
            if(data.items[i].Clusters.cluster_name === cluster){
                clusterInfo = data.items[i]
                break;
            }
        }

        App.setProperties({
        clusterId: clusterInfo.Clusters.cluster_id,
        clusterName: clusterInfo.Clusters.cluster_name,
        currentStackVersion: clusterInfo.Clusters.version,
        isKerberosEnabled: clusterInfo.Clusters.security_type === 'KERBEROS'
      });
      this.set('isClusterNameLoaded', true);
    }
  },
```

不怎么会写前端，就将就着看吧，基本功能还是实现了。

保存，现在我们访问``ambari``页面时，就可以加集群的参数了。

分别访问``http://localhost:8001/?cluster=cluster1`` 和``http://localhost:8001/?cluster=cluster2``，就可以看到两个不同的集群啦。

到这里，基本的多集群方案就可用了。但有人就要问了，每次我都要手动输入，而且也看不到当前拥有的集群列表，咋办？

那我们再来优化一下：

# 再优化

我们通过``http://localhost:8001/clusters?fields=Clusters/security_type,Clusters/version,Clusters/cluster_id``这个接口，可以获取集群列表：

```json
{
  "href" : "http://localhost:8001/api/v1/clusters?fields=Clusters/provisioning_state,Clusters/security_type,Clusters/version,Clusters/cluster_id&_=1586855363652",
  "items" : [
    {
      "href" : "http://localhost:8001/api/v1/clusters/cluster",
      "Clusters" : {
        "cluster_id" : 2,
        "cluster_name" : "cluster",
        "provisioning_state" : "INSTALLED",
        "security_type" : "NONE",
        "version" : "HDP-3.0"
      }
    },
    {
      "href" : "http://localhost:8001/api/v1/clusters/cluster2",
      "Clusters" : {
        "cluster_id" : 52,
        "cluster_name" : "cluster2",
        "provisioning_state" : "INSTALLED",
        "security_type" : "NONE",
        "version" : "HDP-3.0"
      }
    }
  ]
}
```

然后用``Vuejs``或者其他的作为一个列表显示，然后把连接分别指向``http://localhost:8001/?cluster={clusterName}``，这样就可以看到当前所有集群，并直接进行跳转了。

![](http://img.honlyc.com/20200414195750.png)

# 总结

从最终效果来看，其实修改的地方本身不多，但其中的思路还是比较重要，如何分析现有系统、找到需要修改的地方，这里其实用得最多的就是全局搜索了，搜索到对应的属性或方法，然后依次排除。

不得不说，搞定一个这样的``技巧``还是非常有成就感的，不仅自身的思路得到了提升，同时也节省了很多多余的工作。因为不这样解决的话，就要自己去做二次开发了。

其实对于``Ambari``支持多集群管理，在网上搜索到的都没有类似的处理方式，算是有一点成就感吧。