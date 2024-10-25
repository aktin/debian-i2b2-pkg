# --------------------------------------
# Dockerfile for PostgreSQL with i2b2 Database Initialization
# Version:      1.0
# Author:       skurka@ukaachen.de, shuening@ukaachen.de, akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Builds a Docker image for PostgreSQL that initializes
#               the i2b2 database using provided SQL scripts.
# --------------------------------------

FROM postgres:16

# Set the default PostgreSQL password
ENV POSTGRES_PASSWORD=postgres

# Create a directory for custom SQL scripts
RUN mkdir -p /sql.d

# Copy SQL scripts into the image
COPY ./sql/i2b2_postgres_init.sql           /sql.d/00_i2b2_init.sql
COPY ./sql/i2b2_db.sql                      /sql.d/01_i2b2_data.sql
COPY ./sql/i2b2_update_wildfly_host.sql     /sql.d/02_i2b2_update_wildfly_host.sql
COPY ./sql/i2b2_postgres_drop.sql           /sql.d/i2b2_drop.sql

# Concatenate the SQL scripts into a single initialization script
RUN cat /sql.d/00_i2b2_init.sql /sql.d/01_i2b2_data.sql /sql.d/02_i2b2_update_wildfly_host.sql > /docker-entrypoint-initdb.d/init.sql
