# 背景

在工作中，遇到内存占用太大的问题，本身是从数据库加载数据到内存，作为缓存使用。但这里所有数据都是使用的`Map<String,String>`进行存储，会导致内存空间占用过大。考虑把对应的数据结构都封装成对象进行存储，但由于涉及到的表及结构太多，手动添加肯定不行，得来点科技的；而且手动添加的话，对后期添加也比较麻烦，其中还涉及到尽量小改动原有的使用方式。

经过思考和实际验证，考虑通过解析`java`文件，获取到所有表及结构定义的数据，然后自动生成对应的对象及主要方法。



# 分析



脱敏后的原始代码：

```java
CacheConfig nameInfo = new CacheConfig();
nameInfo.strTable = "info_table";
nameInfo.bMutiRow = true;
nameInfo.strSrcSql = "SELECT Id, Name, Type, Age FROM info_table ";
nameInfo.strKeyCols = "Id, Name";
nameInfo.strValCols = "Name, Type, Age";
cacheConfig.put(nameInfo.strTable, nameInfo);
```

可以看到，实际上这里是有定义返回结果的所有字段的，我们只需要把这里的字段解析出来，然后生成一个对应属性的类即可。

而在生成对应的对象后，也同样需要在原始代码上加上新增的属性：

```java
cache.clazz = NameInfo.class
```

# JavaParser 的使用

在解析`java`文件上，可以直接使用`JavaParser`进行解析，这个工具不仅能生成代码，也可以直接修改原始文件。

## 依赖

```xml
<dependency>
    <groupId>com.github.javaparser</groupId>
    <artifactId>javaparser-core</artifactId>
    <version>3.24.7</version>
</dependency>
<dependency>
    <groupId>com.github.javaparser</groupId>
    <artifactId>javaparser-symbol-solver-core</artifactId>
    <version>3.24.7</version>
</dependency>
<dependency>
    <groupId>com.github.javaparser</groupId>
    <artifactId>javaparser-core-generators</artifactId>
    <version>3.24.7</version>
</dependency>
```



## 注意点

1. 代码生成的项目需要跟原始代码的项目分开，否则在调试和后面重复执行时会因为存在错误而无法编译；

   

2. 在修改源文件时，注意默认的解析是会格式化，需要使用不格式化的解析，因为会导致很多`Git`记录；

   ```java
   sourceRoot.setPrinter(LexicalPreservingPrinter::print);
   ```

3. 在对源文件进行添加行时，需要注意幂等性，多次执行不影响最终结果；

4. 在对源文件指定位置添加行时，需要使用`getStatements()`而不是`getChildNodes()`，不然会导致位置行计算错误；