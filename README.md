# debian-i2b2-pkg

This Debian package installs and configures i2b2 (Informatics for Integrating Biology and the Bedside) customized for the AKTIN Emergency Department Data Warehouse. It includes WildFly application server, PostgreSQL database setup, and the i2b2 web client.

## Requirements
- Debian-based Linux distribution
- Required packages:
    - apache2
    - postgresql
    - openjdk-11-jre-headless
    - php with curl extension
    - Additional dependencies listed in control file

## Installation
```bash
sudo dpkg -i aktin-notaufnahme-i2b2_<version>.deb
sudo apt-get install -f  # Install missing dependencies if any
```

## Components
- I2B2 Web Client (v1.8.1.0001)
- WildFly Server (v22.0.1.Final)
- PostgreSQL JDBC Driver (v42.7.4)
- Apache Web Server configuration
- Database initialization scripts

## Default Configuration
- WildFly runs on port 9090
- Web client accessible via Apache
- PostgreSQL database named 'i2b2'
- Preconfigured database schemas and users

## Building
```bash
./build.sh [--cleanup] [--skip-deb-build]
```
Options:
- `--cleanup`: Remove build directory after package creation
- `--skip-deb-build`: Skip the Debian package build step

## Maintenance Scripts
- `postinst`: Configures services after installation
- `prerm`: Prepares system for package removal
- `postrm`: Cleans up after package removal
- `helper.sh`: Common utilities for maintenance tasks

## Support
For support, contact: [it-support@aktin.org](mailto:it-support@aktin.org)

Homepage: https://www.aktin.org/
