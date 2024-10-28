# --------------------------------------
# Dockerfile for WildFly Application Server with i2b2 Deployment
# Version:      1.0
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Dockerfile to build a pre-configured WildFly application server image.
# --------------------------------------

FROM ubuntu:__UBUNTU_VERSION__

LABEL maintainer="AKTIN IT <it-support@aktin.org>"

# Update package lists, install OpenJDK 11, and clean up APT cache
RUN apt update && \
    apt install -y openjdk-11-jdk && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/wildfly

# Copy WildFly distribution
COPY ./wildfly /opt/wildfly

# Create a 'wildfly' system user with no login shell
RUN adduser --system --group --disabled-login --home /var/lib/wildfly wildfly

# Change ownership of WildFly directories to 'wildfly' user
RUN chown -R wildfly:wildfly /opt/wildfly

# Switch to 'wildfly' user for security
USER wildfly

# Remove WildFly configuration history to reduce image size
RUN rm -rf ./standalone/configuration/standalone_xml_history/current/*

# Set the default command to start WildFly in standalone mode, binding to all interfaces
CMD ["/opt/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
