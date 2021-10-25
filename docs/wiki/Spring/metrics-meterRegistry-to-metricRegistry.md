---
title: "MeterRegistry out to MetricRegistry"
date: 2021-03-01T17:21:12+08:00
draft: true
tags: ["meter","metrics","metric"]
categories: ["java","spring"]
---

# 前言

在使用``SpringBoot``时，没有用默认的``Tomcat``容器，而是用的``Undertow``容器。

在线上使用时，发现没有对容器的线程池做监控，无法判断容器当前线程的工作状态及发生问题时，不知道具体的原因。

索引，需要对``Undertow``的线程池、请求数、请求错误数做度量监控。

本文旨在记录一下如何把``MetricRegistry``转成``MeterRegistry``来使用，为什么要这么做？其实就是我们当前系统是使用的``MetricRegistry``进行度量输出，但在``SpringBoot``中，有些度量是使用的``MeterRegistry``来进行收集的，所以需要把``MeterRegistry``收集到的数据，通过``MetricRegistry``进行输出。

# 方案

直接上代码吧：

```java
    @Bean
	public MetricRegistry dropwizardRegistry() {
		return new MetricRegistry();
	}

	@Bean
	public MeterRegistry consoleLoggingRegistry(MetricRegistry dropwizardRegistry) {
		DropwizardConfig consoleConfig = new DropwizardConfig() {

			@Override
			public String prefix() {
				return "console";
			}

			@Override
			public String get(String key) {
				return null;
			}

		};

		return new DropwizardMeterRegistry(consoleConfig, dropwizardRegistry, HierarchicalNameMapper.DEFAULT, Clock.SYSTEM) {
			@Override
			protected Double nullGaugeValue() {
				return null;
			}
		};
	}
```

这样，我们就得到了一个``MeterRegistry``，可以直接拿来用啦

```java
class MyComponent {
    private final MeterRegistry registry;

    public MyComponent(MeterRegistry registry) {
        this.registry = registry;
    }

    public void doSomeWork(String lowCardinalityInput) {
        registry.timer("my.metrics", "input", lowCardinalityInput).record(() -> {
            // do work
        });
    }
}
```

# 参考

https://micrometer.io/docs/guide/consoleReporter

https://frandorado.github.io/spring/2020/03/31/spring-actuator-undertow.html

https://github.com/micrometer-metrics/micrometer/issues/1227

https://github.com/undertow-io/undertow/blob/master/core/src/main/java/io/undertow/server/handlers/MetricsHandler.java#L117