---
title: "Elasticsearch G1 GC"
date: 2021-10-08T11:28:42+08:00
draft: true
---

调整``G1``参数后，``ES``整体的``gc``情况变化：

```options
10-:-XX:-UseConcMarkSweepGC
10-:-XX:-UseCMSInitiatingOccupancyOnly
10-:-XX:+UseG1GC
10-:-XX:G1ReservePercent=25
10-:-XX:InitiatingHeapOccupancyPercent=30
```



![image-20211008112851546](http://img.honlyc.com/image-20211008112851546.png)

