FROM quay.io/wildfly/wildfly:__VWILDFLY__

ENV DBHOST=db
ENV DBPORT=5432

USER jboss

RUN sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" /opt/jboss/wildfly/bin/appclient.conf
RUN sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" /opt/jboss/wildfly/bin/standalone.conf
RUN echo "JAVA_OPTS=\"\$JAVA_OPTS -Dlog4j2.formatMsgNoLookups=true\"" >> /opt/jboss/wildfly/bin/standalone.conf

COPY ./i2b2.war /opt/jboss/wildfly/standalone/deployments/
COPY ./postgresql-*.jar /opt/jboss/wildfly/standalone/deployments/

COPY ./*.cli /opt/jboss/wildfly
RUN /opt/jboss/wildfly/bin/jboss-cli.sh --file=/opt/jboss/wildfly/config.cli
RUN rm /opt/jboss/wildfly/*.cli

USER root
RUN chown -R jboss:jboss /opt/jboss/wildfly/standalone/configuration
RUN chown -R jboss:jboss /opt/jboss/wildfly/standalone/deployments
USER jboss

COPY ./entrypoint.sh /
CMD ["/entrypoint.sh"]
