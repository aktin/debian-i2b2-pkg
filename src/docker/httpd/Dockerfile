# --------------------------------------
# Dockerfile for Apache2 with PHP and i2b2 Web Client
# Version:      1.0
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Builds a Docker image for Apache2 with PHP, configured for
#               the i2b2 web client deployment.
# --------------------------------------

FROM php:__APACHE_VERSION__

LABEL maintainer="AKTIN IT <it-support@aktin.org>"

# Enable the recommended production PHP settings
RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# Copy the i2b2 web client files into the Apache web directory
COPY ./i2b2webclient /var/www/html/webclient
