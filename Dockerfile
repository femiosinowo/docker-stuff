FROM tomcat
MAINTAINER GCIO DevOps "fosinowo@governmentcio.com"

#ADD src/ /src
#WORKDIR /src
RUN mkdir /usr/local/tomcat/webapps/app


#RUN wget http://www.paosin.com -P /usr/local/tomcat/webapps/app

#RUN wget https://tomcat.apache.org/tomcat-6.0-doc/appdev/sample/sample.war -P /usr/local/tomcat/webapps/app
ADD  https://tomcat.apache.org/tomcat-6.0-doc/appdev/sample/sample.war  /usr/local/tomcat/webapps


# Import tomcat-users.xml file
ADD tomcat-users.xml /usr/local/tomcat/conf/
#ADD https://jdbc.postgresql.org/download/postgresql-9.4-1201.jdbc41.jar /usr/local/tomcat/lib/postgresql.jar

EXPOSE 8080
#CMD service tomcat7 start && tail -f /var/lib/tomcat7/logs/catalina.out
~

