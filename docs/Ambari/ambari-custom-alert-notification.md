---

title: "Ambari 自定义告警通知"
date: 2020-03-13T19:52:02+08:00
draft: true
tags: ["alert","custom"]
categories: ["ambari"]
---

# Ambari 自定义告警通知

1. 创建一个自定义告警通知项：

```bash
curl -i -u admin:admin -H 'X-Requested-By: ambari' -X POST  "http://ambari-server:8080/api/v1/alert_targets"  -d '
  {
    "AlertTarget": 
      {
        "name": "test_dispatcher", 
        "description": "Custom Notification Dispatcher", 
        "notification_type": "ALERT_SCRIPT", 
        "global": true, 
        "alert_states": ["CRITICAL","WARNING","UNKNOWN","OK"], 
        "properties": { 
          "ambari.dispatch-property.script": "notification.dispatch.alert.script"
        }
      }
  }
```

2. 编辑``ambari.properties``文件，添加一行：

```properties
notification.dispatch.alert.script=/var/lib/ambari-alerts/scripts/scaler-notification.py
```

3. 编写``scaler-notification.py``文件：

```python
#!/usr/bin/env python
from datetime import datetime
import sys
def test_notification():
  definitionName = sys.argv[1]
  definitionLabel = sys.argv[2]
  serviceName = sys.argv[3]
  alertState = sys.argv[4]
  alertText = sys.argv[5]
  timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
  notification_data = str(timestamp + ' ************* My Alert Dispatcher Logic Here ************' + " -- " + definitionName + " -- " + definitionLabel + " -- " + serviceName + " -- " + alertState + " -- " + alertText + " -- ")

  ## Writing notification to a file. Use your own logic here.
  file = open("/var/log/ambari-server/custom_notification.log", "a+")
  file.write(notification_data)
  file.close()

if __name__ == '__main__':
  test_notification()
```

4. 修改``scaler-notification.py``文件的权限为可执行文件：

```bash
chmod +x /var/lib/ambari-alerts/scripts/scaler-notification.py
```

5. 重启``ambari``服务

```bash
ambari-server restart
```

6. 停掉一个``Service/Component``来触发告警条件

6. 查看自定义告警通知所写入的日志文件：

```bash
tail -f /var/log/ambari-server/custom_notification.log
```

可以看到实际的告警日志了。

# 问题排查

1. 如果在配置后，没有生成告警的日志文件，则需要查看``/var/log/ambari-server/ambari-server.log``，应该有类似错误日志：

![](http://img.honlyc.com/20200716145504.png)

此时，只需要按照路径，把对应文件拷贝过去，然后修改一下权限``chmod +x filename``即可。