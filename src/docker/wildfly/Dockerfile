FROM ubuntu:24.04

RUN apt update
RUN apt install openjdk-11-jdk -y

COPY ./wildfly-* /opt/wildfly

WORKDIR /opt/wildfly

RUN adduser --system --group --disabled-login --home /var/lib/wildfly wildfly
RUN chown -R wildfly:wildfly ./standalone/configuration
RUN chown -R wildfly:wildfly ./standalone/deployments
RUN chown -R wildfly:wildfly .

USER wildfly
RUN sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" ./bin/appclient.conf
RUN sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" ./bin/standalone.conf
RUN echo "JAVA_OPTS=\"\$JAVA_OPTS -Dlog4j2.formatMsgNoLookups=true\"" >> ./bin/standalone.conf

COPY ./i2b2.war standalone/deployments/
COPY ./postgresql-*.jar standalone/deployments/

COPY ./*.cli .
RUN ./bin/jboss-cli.sh --file=./config.cli
RUN rm ./*.cli

CMD ["/opt/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
