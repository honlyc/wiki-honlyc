---
sidebar_position: 1
title: '七牛云使用 https'
---

> 利用``Nginx``使用反向代理，实现``https``访问七牛云``http``图片

由于个人网站使用了``https``，所以七牛云的图片如果是``http``的话，就无法进行访问了。

但是七牛云的``https``不是免费的。所以... 直接上方案

## 实现步骤

1. 新建一个网站，域名为``img.xx.com``，并添加``ssl``证书，实现``https``访问；
2. 创建七牛云空间，域名指定为：``image.xx.com``；
3. 将``img.xx.com``整站配置反向代理，指向``image.xx.com``即可；
4. 就可以直接通过``https://img.xx.com/xx.png``访问七牛云的图片了；

## Nginx 配置

```
location /{
    proxy_pass http://image.xx.cn;
    proxy_set_header Host image.xx.cn;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header REMOTE-HOST $remote_addr;
	expires 12h;
}
```

