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

# Copy scripts into the initialization directory
COPY ./sql/*.sql /docker-entrypoint-initdb.d/

# Copy SQL scripts into the image
COPY ./sql/i2b2_postgres_drop.sql           /sql.d/i2b2_drop.sql

# Concatenate the SQL scripts into a single initialization script
RUN cat /docker-entrypoint-initdb.d/00_i2b2_init.sql \
         /docker-entrypoint-initdb.d/01_i2b2_data.sql \
         /docker-entrypoint-initdb.d/02_i2b2_update_wildfly_host.sql \
         > /docker-entrypoint-initdb.d/init.sql && \
    rm /docker-entrypoint-initdb.d/00_i2b2_init.sql \
       /docker-entrypoint-initdb.d/01_i2b2_data.sql \
       /docker-entrypoint-initdb.d/02_i2b2_update_wildfly_host.sql

# Move database deinstall script into folder for custom scripts
RUN mv /docker-entrypoint-initdb.d/i2b2_postgres_drop.sql /sql.d/i2b2_drop.sql
