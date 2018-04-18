# 基于docker, docker-compose创建mycat mysql主从服务器（binary logging）, 测试mycat分库分表

## 创建mycat容器
### mycat Dockerfile
```
FROM java:8-jre
MAINTAINER marcus.li@qq.com
LABEL Description="基于docker，使用mycat做mysql数据库的读写分离"
USER root
RUN cd /usr/local && \
    wget http://dl.mycat.io/1.6.5/Mycat-server-1.6.5-release-20180122220033-linux.tar.gz && \
    tar -zxf Mycat-server-1.6.5-release-20180122220033-linux.tar.gz
ENV MYCAT_HOME=/usr/local/mycat
ENV PATH=$PATH:$MYCAT_HOME/bin
WORKDIR $MYCAT_HOME/bin
RUN chmod u+x ./mycat
EXPOSE 8066 9066
CMD ["./mycat","console"]
```
### mycat配置详情- [Mycat权威指南](http://songwie.com/attached/file/mycat_1.5.2.pdf)
#### server.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- - - Licensed under the Apache License, Version 2.0 (the "License");
	- you may not use this file except in compliance with the License. - You
	may obtain a copy of the License at - - http://www.apache.org/licenses/LICENSE-2.0
	- - Unless required by applicable law or agreed to in writing, software -
	distributed under the License is distributed on an "AS IS" BASIS, - WITHOUT
	WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. - See the
	License for the specific language governing permissions and - limitations
	under the License. -->
<!DOCTYPE mycat:server SYSTEM "server.dtd">
<mycat:server xmlns:mycat="http://io.mycat/">
    <system>
        <property name="nonePasswordLogin">0</property> <!-- 0为需要密码登陆、1为不需要密码登陆 ,默认为0，设置为1则需要指定默认账户-->
        <property name="useHandshakeV10">1</property>
        <property name="useSqlStat">1</property>  <!-- 1为开启实时统计、0为关闭 -->
        <property name="useGlobleTableCheck">0</property>  <!-- 1为开启全加班一致性检测、0为关闭 -->

        <property name="subqueryRelationshipCheck">false</property> <!-- 子查询中存在关联查询的情况下,检查关联字段中是否有分片字段 .默认 false -->
        <!--  <property name="useCompression">1</property>--> <!--1为开启mysql压缩协议-->
        <!--  <property name="fakeMySQLVersion">5.6.20</property>--> <!--设置模拟的MySQL版本号-->
        <!-- <property name="processorBufferChunk">40960</property> -->
        <!--
        <property name="processors">1</property>
        <property name="processorExecutor">32</property>
         -->
        <!--默认为type 0: DirectByteBufferPool | type 1 ByteBufferArena | type 2 NettyBufferPool -->
        <property name="processorBufferPoolType">0</property>
        <!--默认是65535 64K 用于sql解析时最大文本长度 -->
        <!--<property name="maxStringLiteralLength">65535</property>-->
        <property name="sequnceHandlerType">1</property> <!--0 为本地文件方式，1为数据库方式，2位时间序列方式-->
        <!--<property name="backSocketNoDelay">1</property>-->
        <!--<property name="frontSocketNoDelay">1</property>-->
        <!--<property name="processorExecutor">16</property>-->
        <!--
            <property name="serverPort">8066</property> <property name="managerPort">9066</property>
            <property name="idleTimeout">300000</property> <property name="bindIp">0.0.0.0</property>
            <property name="frontWriteQueueSize">4096</property> <property name="processors">32</property> -->
        <property name="bindIp">0.0.0.0</property>
        <!--分布式事务开关，0为不过滤分布式事务，1为过滤分布式事务（如果分布式事务内只涉及全局表，则不过滤），2为不过滤分布式事务,但是记录分布式事务日志-->
        <property name="handleDistributedTransactions">0</property>

        <!--
        off heap for merge/order/group/limit      1开启   0关闭
    -->
        <property name="useOffHeapForMerge">1</property>

        <!--
            单位为m
        -->
        <property name="memoryPageSize">64k</property>

        <!--
            单位为k
        -->
        <property name="spillsFileBufferSize">1k</property>

        <property name="useStreamOutput">0</property>

        <!--
            单位为m
        -->
        <property name="systemReserveMemorySize">384m</property>


        <!--是否采用zookeeper协调切换  -->
        <property name="useZKSwitch">false</property>

        <!-- XA Recovery Log日志路径 -->
        <!--<property name="XARecoveryLogBaseDir">./</property>-->

        <!-- XA Recovery Log日志名称 -->
        <!--<property name="XARecoveryLogBaseName">tmlog</property>-->

    </system>

    <!-- 全局SQL防火墙设置 -->
    <!--白名单可以使用通配符%或着*-->
    <!--例如<host host="127.0.0.*" user="root"/>-->
    <!--例如<host host="127.0.*" user="root"/>-->
    <!--例如<host host="127.*" user="root"/>-->
    <!--例如<host host="1*7.*" user="root"/>-->
    <!--这些配置情况下对于127.0.0.1都能以root账户登录-->
    <!--
    <firewall>
       <whitehost>
          <host host="1*7.0.0.*" user="root"/>
       </whitehost>
       <blacklist check="false">
       </blacklist>
    </firewall>
    -->

    <user name="root" defaultAccount="true">
        <property name="password">root</property>
        <property name="schemas">test</property>

        <!-- 表级 DML 权限设置 -->
        <!--
        <privileges check="false">
            <schema name="TESTDB" dml="0110" >
                <table name="tb01" dml="0000"></table>
                <table name="tb02" dml="1111"></table>
            </schema>
        </privileges>
         -->
    </user>
</mycat:server>
```
#### schema.xml
```xml
<?xml version="1.0"?>
<!DOCTYPE mycat:schema SYSTEM "schema.dtd">
<mycat:schema xmlns:mycat="http://io.mycat/">
	<schema name="test" checkSQLschema="false" sqlMaxLimit="100">
		<!-- auto sharding by id (long) -->
		<table name="user" primaryKey="id" dataNode="dn1,dn2" rule="mod-long" autoIncrement="true">
			<childTable name="orders" primaryKey="id" joinKey="user_id" autoIncrement="true"
						parentKey="id">
			</childTable>
		</table>

		<!-- global table is auto cloned to all defined data nodes ,so can join
			with any table whose sharding node is in the same data node -->
		<table name="country" primaryKey="id" type="global" dataNode="dn1,dn2" />
		<table name="mycat_sequence" primaryKey="name" dataNode="dn1"/>
	</schema>
	<dataNode name="dn1" dataHost="mysql1" database="db1" />
	<dataNode name="dn2" dataHost="mysql2" database="db2" />
	<dataHost name="mysql1" maxCon="1000" minCon="10" balance="3"
			  writeType="0" dbType="mysql" dbDriver="native" switchType="1"  slaveThreshold="100">
		<heartbeat>select user()</heartbeat>
		<!-- can have multi write hosts -->
		<writeHost host="mysql-1-master" url="mysql-1-master:3306" user="root"
				   password="root">
			<!-- can have multi read hosts -->
			<readHost host="mysql-1-slave" url="mysql-1-slave:3306" user="root" password="root" />
		</writeHost>
	</dataHost>
	<dataHost name="mysql2" maxCon="1000" minCon="10" balance="3"
			  writeType="0" dbType="mysql" dbDriver="native" switchType="1"  slaveThreshold="100">
		<heartbeat>select user()</heartbeat>
		<!-- can have multi write hosts -->
		<writeHost host="mysql-2-master" url="mysql-2-master:3306" user="root"
				   password="root">
			<!-- can have multi read hosts -->
			<readHost host="mysql-2-slave" url="mysql-2-slave:3306" user="root" password="root" />
		</writeHost>
	</dataHost>
</mycat:schema>
```
#### rule.xml
```xml
...
<function name="mod-long" class="io.mycat.route.function.PartitionByMod">
	<!-- how many data nodes -->
	<property name="count">2</property> <!--注意修改这里-->
</function>
...
```

## 启动所有容器
docker-compose.yml

```yml
version: '3'
services:
  mysql-1-master:
    image: mysql:5.7
    volumes:
      - ./mysql/conf/master.cnf:/etc/mysql/my.cnf
    environment:
      - MYSQL_ROOT_PASSWORD=root
  mysql-1-slave:
    image: mysql:5.7
    volumes:
      - ./mysql/conf/slave.cnf:/etc/mysql/my.cnf
    environment:
      - MYSQL_ROOT_PASSWORD=root
  mysql-2-master:
    image: mysql:5.7
    volumes:
      - ./mysql/conf/master.cnf:/etc/mysql/my.cnf
    environment:
      - MYSQL_ROOT_PASSWORD=root
  mysql-2-slave:
    image: mysql:5.7
    volumes:
      - ./mysql/conf/slave.cnf:/etc/mysql/my.cnf
    environment:
      - MYSQL_ROOT_PASSWORD=root
  mycat:
    build:
      context: ./mycat
    volumes:
      - ./mycat/conf:/usr/local/mycat/conf
      - ./mycat/logs:/usr/local/mycat/logs
    ports:
      - 8066:8066
      - 9066:9066
    depends_on:
      - mysql-1-master
      - mysql-1-slave
      - mysql-2-master
      - mysql-2-slave
    restart: always
```


```shell
docker-compose up -d  # 启动所有容器
docker-compose ps     # 查看容器运行状态
```

## MySQL Master-Slave配置
### 分别进入master容器创建数据同步用户
```shell
docker exec -it mycatdockerdemo_mysql-1-master_1 mysql -uroot -proot
CREATE USER 'repl'@'%' IDENTIFIED BY '123456';         # '%'意味着所有的终端都可以用这个用户登录
GRANT SELECT,REPLICATION SLAVE ON *.* TO 'repl'@'%';   # SELECT权限是为了让repl可以读取到数据，生产环境建议创建另一个用户
```
### 分别进入slave容器创建数据同步用户
```shell
docker exec -it mycatdockerdemo_mysql-1-slave_1 mysql -uroot -proot
CHANGE MASTER TO MASTER_HOST='mysql-1-master', MASTER_USER='repl', MASTER_PASSWORD='123456'; # 配置master服务器
START SLAVE; # 启动slave
SHOW SLAVE STATUS\G      #\G用来代替";"，能把查询结果按键值的方式显示: 
可以看到下面内容，表示slave配置成功
************************ 1. row ***************************
           Slave_IO_State: Waiting for master to send event
              Master_Host: mysql-1-master
              Master_User: repl
              Master_Port: 3306
              ...
  Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
```
### 验证主从复制情况
在mysql-1-master上创建数据库db1，然后在mysql-1-slave上查看db1是否复制过来。

```shell
docker exec -it mycatdockerdemo_mysql-1-master_1 mysql -uroot -proot # 进入到mysql-1-master
CREATE DATABASE db1 CHARACTER SET utf8 COLLATE utf8_general_ci; # 在mysql-1-master上创建db1库, mysql-2-master常见db2
SHOW DATABASES; 
+--------------------+
| Database           |
+--------------------+
| information_schema |
| db1                |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
```

此时我们就已经配置好了MySQL的主从复制。

### 验证mycat分库分表

使用mysql客户端连接mycat server（可以使用上面mysql容器里面的客户端连接）

```
docker exec -it mycatdockerdemo_mysql-1-slave_1 mysql -uroot -proot -P 8066 -hmycat
```
![](https://kekekeke.sh1a.qingstor.com/WX20180417-164620.png)
可以看到我们已经连接到mycat提供的mysql server，并且可以看到我们在schema.xml定义的table，其中country是glabel表（存在于所有的datanode）,mycat_sequence是全局序列表存在于dn1, user分片表，order是user子表。
#### 准备序列表+function
需要在dn1上执行

```
CREATE TABLE mycat_sequence (
	name varchar(50) NOT NULL,
	current_value int(11) NOT NULL,
	increment int(11) NOT NULL DEFAULT 1,
	PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO mycat_sequence (name, current_value, increment) VALUES ('USER', 0, 1);
INSERT INTO mycat_sequence (name, current_value, increment) VALUES ('ORDERS', 0, 1);

-- ----------------------------
-- Function structure for `mycat_seq_currval`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_currval`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_currval`(seq_name VARCHAR(64)) RETURNS varchar(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    SET retval="-1,0";
    SELECT concat(CAST(current_value AS CHAR),",",CAST(increment AS CHAR) ) INTO retval FROM mycat_sequence  WHERE name = seq_name;
    RETURN retval ;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for `mycat_seq_nextval`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_nextval`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_nextval`(seq_name VARCHAR(64)) RETURNS varchar(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    DECLARE val BIGINT;
    DECLARE inc INT;
    DECLARE seq_lock INT;
    set val = -1;
    set inc = 0;
    SET seq_lock = -1;
    SELECT GET_LOCK(seq_name, 15) into seq_lock;
    if seq_lock = 1 then
      SELECT current_value + increment, increment INTO val, inc FROM mycat_sequence WHERE name = seq_name for update;
      if val != -1 then
          UPDATE mycat_sequence SET current_value = val WHERE name = seq_name;
      end if;
      SELECT RELEASE_LOCK(seq_name) into seq_lock;
    end if;
    SELECT concat(CAST((val - inc + 1) as CHAR),",",CAST(inc as CHAR)) INTO retval;
    RETURN retval;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for `mycat_seq_setvals`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_nextvals`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_nextvals`(seq_name VARCHAR(64), count INT) RETURNS VARCHAR(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    DECLARE val BIGINT;
    DECLARE seq_lock INT;
    SET val = -1;
    SET seq_lock = -1;
    SELECT GET_LOCK(seq_name, 15) into seq_lock;
    if seq_lock = 1 then
        SELECT current_value + count INTO val FROM mycat_sequence WHERE name = seq_name for update;
        IF val != -1 THEN
            UPDATE mycat_sequence SET current_value = val WHERE name = seq_name;
        END IF;
        SELECT RELEASE_LOCK(seq_name) into seq_lock;
    end if;
    SELECT CONCAT(CAST((val - count + 1) as CHAR), ",", CAST(val as CHAR)) INTO retval;
    RETURN retval;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for `mycat_seq_setval`
-- ----------------------------
DROP FUNCTION IF EXISTS `mycat_seq_setval`;
DELIMITER ;;
CREATE FUNCTION `mycat_seq_setval`(seq_name VARCHAR(64), value BIGINT) RETURNS varchar(64) CHARSET latin1
    DETERMINISTIC
BEGIN
    DECLARE retval VARCHAR(64);
    DECLARE inc INT;
    SET inc = 0;
    SELECT increment INTO inc FROM mycat_sequence WHERE name = seq_name;
    UPDATE mycat_sequence SET current_value = value WHERE name = seq_name;
    SELECT concat(CAST(value as CHAR),",",CAST(inc as CHAR)) INTO retval;
    RETURN retval;
END
;;
DELIMITER ;

```
#### 创建country,user,orders表
连接mycat server创建

```
CREATE TABLE orders (
	id int(11) NOT NULL AUTO_INCREMENT,
	user_id int(11) NOT NULL,
	product varchar(10) DEFAULT NULL,
	PRIMARY KEY(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE user (
	id int(11) NOT NULL AUTO_INCREMENT,
	name varchar(10) DEFAULT NULL,
	age int(11) DEFAULT NULL,
	country_id int(11) DEFAULT NULL,
	credit int(11) DEFAULT NULL,
	PRIMARY KEY(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE country (
	id int(11) NOT NULL,
	name varchar(20) DEFAULT NULL
)ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

#### 验证全局表 country 
全局表，会在每一个datanode上都存储

```
INSERT INTO country(id, name) values (1, 'China'), (2, 'USA'), (3, 'Russia');
```
![](https://kekekeke.sh1a.qingstor.com/WX20180417-173259.png)

#### 验证user表分片 
根据配置的分片规则进行数据存储

```
INSERT INTO user(name, age, country_id, credit) values ('Marcus', 28, 1, 100);
INSERT INTO user(name, age, country_id, credit) values ('James', 31, 1, 180);
INSERT INTO user(name, age, country_id, credit) values ('Pual', 27, 2, 190);
INSERT INTO user(name, age, country_id, credit) values ('Frank', 21, 2, 130);
INSERT INTO user(name, age, country_id, credit) values ('Mack', 40, 3, 200);
```
数据根据分片算法分布在dn1,dn2
![](https://kekekeke.sh1a.qingstor.com/WX20180417-180830.png)

mycat server的路由转发
![](https://kekekeke.sh1a.qingstor.com/WX20180418-140008.png)

#### 验证orders子表跟随父表分片
orders表会根据user_id所在的库进行分片,避免了垮库的join

```
INSERT INTO orders(user_id, product) values (2, 'book');
INSERT INTO orders(user_id, product) values (2, 'phone');
INSERT INTO orders(user_id, product) values (3, 'shoes');
INSERT INTO orders(user_id, product) values (3, 'computer');
INSERT INTO orders(user_id, product) values (4, 'cherry');
INSERT INTO orders(user_id, product) values (5, 'ticket');
INSERT INTO orders(user_id, product) values (6, 'bag');
```
![](https://kekekeke.sh1a.qingstor.com/WX20180418-140927.png)

#### mycat跨分片join实现方式
mycat跨分片join的四种方式：全局表、ER分片、calletT(人工智能)、ShareJoin。
##### 全局表
适合字典表（变动频繁、数据量总体变化不大、数据规模不大，很少有超过数十万条记录），country表就是全局表

配置

```xml
...
<table name="country" pr，imaryKey="id" type="global" dataNode="dn1,dn2" />
...
```
```
mysql> select u.*, c.name from user u join country c on u.country_id=c.id;
+----+--------+------+------------+--------+--------+
| id | name   | age  | country_id | credit | name   |
+----+--------+------+------------+--------+--------+
|  2 | Marcus |   28 |          1 |    100 | China  |
|  4 | Pual   |   27 |          2 |    190 | USA    |
|  6 | Mack   |   40 |          3 |    200 | Russia |
|  3 | James  |   31 |          1 |    180 | China  |
|  5 | Frank  |   21 |          2 |    130 | USA    |
+----+--------+------+------------+--------+--------+
```
##### ER join
Table Group概念，将子表的存储位置依赖于主表，并且物理上紧邻存放。
user表采用mod-long分片规则，orders表依赖附表进行分片，两个表的关联挂你想是orders.user_id=user.id。

分片配置

```
...
<table name="user" primaryKey="id" dataNode="dn1,dn2" rule="mod-long" autoIncrement="true">
	<childTable name="orders" primaryKey="id" joinKey="user_id" autoIncrement="true"
				parentKey="id">
	</childTable>
</table>
...
```
![](https://kekekeke.sh1a.qingstor.com/WX20180418-140927.png)
##### Share join
Share join是一个简单的跨分片join，基于HBT的方式实现（目前支持2个表的join，解析SQL语句，拆分成单边SQL执行，汇总各节点数据）
支持任意配置的A,B表：

A,B的dataNode相同

```
<table name="A" dataNode="dn1,dn2" rule="auto-sharding-long" /> 
<table name="B" dataNode="dn1,dn2" rule="auto-sharding-long" />
```
A,B的dataNode不同

```
<table name="A" dataNode="dn1" rule="auto-sharding-long" /> 
<table name="B" dataNode="dn1,dn2" rule="auto-sharding-long" />
```

或

```
<table name="A" dataNode="dn1" rule="auto-sharding-long" /> 
<table name="B" dataNode="dn2" rule="auto-sharding-long" />
```
代码测试下
先创建address表，修改user表，新增address_id字段

```
#schema.xml新增address定义
<table name="address" primaryKey="id" dataNode="dn1" />

CREATE TABLE address (
    id int(11) NOT NULL ,
    location varchar(50) DEFAULT NULL,
    PRIMARY KEY(id)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

#创建初始数据
INSERT INTO address(id, location) values (1, 'Beijing'),(2, 'Xian'),(3, 'Shanghai');

#更新user表
ALTER TABLE user ADD column address_id int(11) DEFAULT NULL;

#分别更新 dn1,dn2,上 user表的address_id字段

```
查询user和address表，join, share join的区别，

join

```
mysql> select u.*, a.* from user u join address a on u.address_id=a.id;
+----+--------+------+------------+--------+------------+----+----------+
| id | name   | age  | country_id | credit | address_id | id | location |
+----+--------+------+------------+--------+------------+----+----------+
|  2 | Marcus |   28 |          1 |    100 |          1 |  1 | Beijing  |
|  4 | Pual   |   27 |          2 |    190 |          2 |  2 | Xian     |
|  6 | Mack   |   40 |          3 |    200 |          2 |  2 | Xian     |
+----+--------+------+------------+--------+------------+----+----------+

```

share join

```
mysql> /*!mycat:catlet=io.mycat.catlets.ShareJoin */select u.*, a.* from user u join address a on u.address_id=a.id;
+----+--------+------+------------+--------+------------+------------+----------+
| id | name   | age  | country_id | credit | address_id | address_id | location |
+----+--------+------+------------+--------+------------+------------+----------+
|  2 | Marcus |   28 |          1 |    100 |          1 |          1 | Beijing  |
|  4 | Pual   |   27 |          2 |    190 |          2 |          2 | Xian     |
|  6 | Mack   |   40 |          3 |    200 |          2 |          2 | Xian     |
|  3 | James  |   31 |          1 |    180 |          3 |          3 | Shanghai | *
|  5 | Frank  |   21 |          2 |    130 |          3 |          3 | Shanghai | *
+----+--------+------+------------+--------+------------+------------+----------+
```

