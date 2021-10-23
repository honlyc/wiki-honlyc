---
title: "Spring Webflux 获取请求 IP 的方法"
date: 2019-04-04T15:39:44+08:00
draft: true
tags: ["spring"]
categories: ["spring"]
---

## 问题描述

在使用``WebFlux``时，因为业务需要，要获取请求 IP 并作为日志输出。我使用的是``RouterFunction``方式的路由：

```java
@Override
@NotNull
public Mono<ServerResponse> search(ServerRequest request) {
    Mono<Query> query = request.bodyToMono(Query.class);
    Mono<SearchResult> result = query.map(processQuery(request))
        .map(indexerService::search);
    return resultOk(result, SearchResult.class);
}
```

可以看到，这里接收一个``ServerRequest``，但是并没有获取请求 IP 的 API，搜索一番，结果是``Spring``的一个 BUG，详情见[SPR-16681](<https://github.com/spring-projects/spring-framework/issues/21222>)，已经在``5.1``版本中修复。但生产的版本没法随意升级，所以只能另寻他法了。

## 解决方案

其实，在``WebFlux``中的``Filter``的方法中，``ServerWebExchange``对象是可以通过 API 获取请求 IP 的：

```java
@Component
public static class RetrieveClientIpWebFilter implements WebFilter {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        InetSocketAddress remoteAddress = exchange.getRequest().getRemoteAddress();
        String clientIp = Objects.requireNonNull(remoteAddress).getAddress().getHostAddress();
        IpThreadLocal.setIp(clientIp);
        ServerHttpRequest mutatedServerHttpRequest = exchange.getRequest().mutate().header("X-CLIENT-IP", clientIp).build();
        ServerWebExchange mutatedServerWebExchange = exchange.mutate().request(mutatedServerHttpRequest).build();
        return chain.filter(mutatedServerWebExchange);
    }
}
```

可以把 IP 放到``Header``中，通过``ServerRequest``来获取，也可以放到全局的线程变量中。

## 写在最后

不得不感叹，往往很多时候我都是**面向搜索编程**，碰到问题，就到处搜索，到处翻文章，找到方案了，就直接``CV``，这其实很难有所进步。问题是解决了，但下次再碰到，同样没记住，因为只是做了一次``CV``而已。那如何才能有效提高每一次的问题解决呢？我的方法就是记录下来，做一次输出，加深自己的印象，同时也能够在以后随时复盘，逐渐掌握。



### 参考

[曲线救国，解决spring-boot2.0.6中webflux无法获得请求IP的问题](<https://juejin.im/post/5bcdba2ce51d457a7a0381fe>)

