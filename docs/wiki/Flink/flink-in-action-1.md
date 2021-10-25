---
title: "Flink in Action (1)-使用 Gradle 开发 Flink 程序"
date: 2020-09-18T15:01:21+08:00
draft: true
tags: ["gradle","flink"]
categories: ["flink"]
---

**本文基于 Gradle-6.3 和 Flink-1.11.2-scala-2.11**

[TOC]

# 环境要求

1. gradle 3.0 以上
2. java 8.* 以上

# 创建项目

## 创建目录

```shell
mkdir flink-quickstart
cd flink-quickstart
```

## 初始化 gradle 文件

1. 编辑 ``build.gradle``

```groovy
buildscript {
    repositories {
        jcenter() // this applies only to the Gradle 'Shadow' plugin
    }
    dependencies {
        // 注意这里的版本为 6.0.0，否则，在 gradle-6.3 中，会报 No value has been specified for property 'mainClassName'. 的错误
        classpath 'com.github.jengelman.gradle.plugins:shadow:6.0.0'
    }
}

plugins {
    id 'java'
    id 'application'
    // shadow plugin to produce fat JARs
    id 'com.github.johnrengelman.shadow' version '6.0.0'
}

// artifact properties
group = 'com.demo.flink-quickstart'
version = '0.1-SNAPSHOT'
// 根目录的 这个配置必须有，可以不写正确的类
mainClassName = 'com.demo.flink.WordCountJob'
description = """Flink Quickstart Job"""

ext {
    javaVersion = '1.8'
    flinkVersion = '1.11.2'
    scalaBinaryVersion = '2.11'
    slf4jVersion = '1.7.7'
    log4jVersion = '1.2.17'
}

sourceCompatibility = javaVersion
targetCompatibility = javaVersion
tasks.withType(JavaCompile) {
    options.encoding = 'UTF-8'
}

applicationDefaultJvmArgs = ["-Dlog4j.configuration=log4j.properties"]

// declare where to find the dependencies of your project
repositories {
    mavenCentral()
    maven { url "https://repository.apache.org/content/repositories/snapshots/" }
}

// 注意：我们不能使用 "compileOnly" 或者 "shadow" 配置，这会使我们无法在 IDE 中或通过使用 "gradle run" 命令运行代码。
// 我们也不能从 shadowJar 中排除传递依赖（请查看 https://github.com/johnrengelman/shadow/issues/159)。
// -> 显式定义我们想要包含在 "flinkShadowJar" 配置中的类库!
configurations {
    flinkShadowJar // dependencies which go into the shadowJar

    // 总是排除这些依赖（也来自传递依赖），因为 Flink 会提供这些依赖。
    flinkShadowJar.exclude group: 'org.apache.flink', module: 'force-shading'
    flinkShadowJar.exclude group: 'com.google.code.findbugs', module: 'jsr305'
    flinkShadowJar.exclude group: 'org.slf4j'
    flinkShadowJar.exclude group: 'log4j'
}

// declare the dependencies for your production and test code
dependencies {
    // --------------------------------------------------------------
    // 编译时依赖不应该包含在 shadow jar 中，
    // 这些依赖会在 Flink 的 lib 目录中提供。
    // --------------------------------------------------------------
    compile "org.apache.flink:flink-java:${flinkVersion}"
    compile "org.apache.flink:flink-streaming-java_${scalaBinaryVersion}:${flinkVersion}"
    compile "org.apache.flink:flink-clients_${scalaBinaryVersion}:${flinkVersion}"

    // --------------------------------------------------------------
    // 应该包含在 shadow jar 中的依赖，例如：连接器。
    // 它们必须在 flinkShadowJar 的配置中！
    // --------------------------------------------------------------
    //flinkShadowJar "org.apache.flink:flink-connector-kafka-0.11_${scalaBinaryVersion}:${flinkVersion}"

    compile "log4j:log4j:${log4jVersion}"
    compile "org.slf4j:slf4j-log4j12:${slf4jVersion}"
}

// make compileOnly dependencies available for tests:
sourceSets {
    main.compileClasspath += configurations.flinkShadowJar
    main.runtimeClasspath += configurations.flinkShadowJar

    test.compileClasspath += configurations.flinkShadowJar
    test.runtimeClasspath += configurations.flinkShadowJar

    javadoc.classpath += configurations.flinkShadowJar
}

run.classpath = sourceSets.main.runtimeClasspath

jar {
    manifest {
        attributes 'Built-By': System.getProperty('user.name'),
                'Build-Jdk': System.getProperty('java.version')
    }
}

shadowJar {
    configurations = [project.configurations.flinkShadowJar]
}
```

2. 编辑 ``settings.gradle`` 文件

```groovy
rootProject.name = 'flink-quickstart'
```

## 添加一个子模块``word-count``

```shell
mkdir word-count
cd word-count
```

## 初始化子模块的``build.gradle``文件

```groovy
plugins {
    id 'java'
    id 'application'
    // 这里只需要引用，不需要有版本号
    id 'com.github.johnrengelman.shadow'
}

group 'com.demo.flink-quickstart'
version '0.1-SNAPSHOT'
// 这里需要指向正确的类
mainClassName = 'com.honlyc.flink.WordCountJob'

repositories {
    mavenCentral()
}

dependencies {
    testCompile group: 'junit', name: 'junit', version: '4.12'
    // --------------------------------------------------------------
    // 编译时依赖不应该包含在 shadow jar 中，
    // 这些依赖会在 Flink 的 lib 目录中提供。
    // --------------------------------------------------------------
    compile "org.apache.flink:flink-java:${flinkVersion}"
    compile "org.apache.flink:flink-streaming-java_${scalaBinaryVersion}:${flinkVersion}"
    compile "org.apache.flink:flink-clients_${scalaBinaryVersion}:${flinkVersion}"

    // --------------------------------------------------------------
    // 应该包含在 shadow jar 中的依赖，例如：连接器。
    // 它们必须在 flinkShadowJar 的配置中！
    // --------------------------------------------------------------
    //flinkShadowJar "org.apache.flink:flink-connector-kafka-0.11_${scalaBinaryVersion}:${flinkVersion}"

    compile "log4j:log4j:${log4jVersion}"
    compile "org.slf4j:slf4j-log4j12:${slf4jVersion}"
}
```

# 检查项目

```shell
.
├── build.gradle
├── gradle
│   └── wrapper
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── gradlew
├── gradlew.bat
├── README.md
├── settings.gradle
└── word-count
    ├── build.gradle
    └── src
        ├── main
        │   ├── java
        │   │   └── com
        │   │       └── honlyc
        │   │           └── flink
        │   │               └── WordCountJob.java
        │   └── resources
        └── test
            ├── java
            └── resources

13 directories, 9 files
```

到这里，我们就搭建了一个基本的项目结构，并且添加了我们的第一个模块``word-count``.

# 项目打包

在这个项目中，我们只需要在根目录执行``gradle clean shadowJar``，即可打包。在执行完成后，可以在各个子模块的``build/libs/``目录下找到对应的``jar``包。

最后，附上[源码地址](https://github.com/honlyc/flink-learning)

# 参考

https://ci.apache.org/projects/flink/flink-docs-release-1.10/zh/dev/projectsetup/java_api_quickstart.html#%E7%8E%AF%E5%A2%83%E8%A6%81%E6%B1%82-1