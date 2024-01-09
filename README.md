# Kartaca System Configuration with SaltStack

This repository contains Salt states and pillars to configure Ubuntu 22.04 and CentOS Stream 9 servers according to the specified requirements.

## Task Overview

The task involves preparing a Salt state that performs various operations on both Ubuntu and CentOS servers, including user creation, sudo privileges, timezone settings, IP forwarding, package installations, repository addition, host record addition, Nginx configuration, WordPress setup, MySQL configuration, and more.

## Directory Structure

- **states:** Contains Salt state files.
  - `kartaca-state.sls`: Main Salt state file for system configuration.
- **pillars:** Contains pillar data.
  - `kartaca-pillar.sls`: Pillar file containing user password and database information.
- **files:** Contains additional files.
  - `nginx.conf`: Nginx configuration file.
  - `nginx.logrotate`: configuration that will rotate nginx logs
- **README.md:** This file providing information about the repository.
- **Kartaca-task-documentation:** This is the whole documentation of my work & practicals I did on my local environment.

## Usage

1. **Clone the repository:**

   ```bash
   git clone https://github.com/smTadeeb/kartaca-gorev.git
