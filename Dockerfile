FROM tomcat
MAINTAINER GCIO DevOps "fosinowo@governmentcio.com"

#ADD src/ /src
#WORKDIR /src
RUN mkdir /usr/local/tomcat/webapps/slashdot
#RUN wget http://www.slashdot.org -P /usr/local/tomcat/webapps/slashdot

RUN wget http://www.paosin.com -P /usr/local/tomcat/webapps/slashdot

#RUN wget https://tomcat.apache.org/tomcat-6.0-doc/appdev/sample/sample.war -P /usr/local/tomcat/webapps/slashdot
#RUN wget https://gwt-examples.googlecode.com/files/Calendar.war -P /usr/local/tomcat/webapps/slashdot

EXPOSE 8080
#CMD service tomcat7 start && tail -f /var/lib/tomcat7/logs/catalina.out
