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
