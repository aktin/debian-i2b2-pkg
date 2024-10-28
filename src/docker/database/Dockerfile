# --------------------------------------
# Dockerfile for PostgreSQL with i2b2 Database Initialization
# Version:      1.0
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Dockerfile to build a PostgreSQL image that initializes the i2b2 database.
# --------------------------------------

FROM postgres:__POSTGRESQL_VERSION__

LABEL maintainer="AKTIN IT <it-support@aktin.org>"

# Set the default PostgreSQL password
ENV POSTGRES_PASSWORD=postgres

# Create a directory for custom SQL scripts
RUN mkdir -p /sql.d

# Copy SQL scripts into directory for custom SQL scripts
COPY ./sql/*sql /sql.d/

# Concatenate custom SQL scripts into a single initialization script
RUN cat /sql.d/i2b2_init.sql /sql.d/i2b2_db.sql /sql.d/update_wildfly_host.sql > /docker-entrypoint-initdb.d/init.sql && \
    rm /sql.d/i2b2_init.sql /sql.d/i2b2_db.sql /sql.d/update_wildfly_host.sql
