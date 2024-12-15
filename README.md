# docker-cron
Dead simple crontab container for running scheduled commands in Docker.

## Features
- Simple and lightweight cron job runner
- Immediate execution option
- Package installation support
- Real-time log viewing
- Secure by default
- Human-readable cron schedule explanations

## Usage

### Docker Compose
```yaml
version: '3.9'

services:
  cron:
    image: betterweb/crontab:latest
    command: "curl https://example.com/cron.txt"
    environment:
      - CRON_SCHEDULE="*/5 * * * *" # Run every 5 minutes
      - CRON_APTS="curl"
      - CRON_IMMEDIATE="false"
```  

Docker run:  
```sh
sudo docker run -e "CRON_SCHEDULE=* * * * *" -e "CRON_APTS=curl" -e "CRON_IMMEDIATE=false" betterweb/crontab:latest "curl https://example.com/cron.txt"
```

## Security Features

- Runs cron jobs as non-root user 'crontab'
- Minimal base image with only required packages
- Proper file permissions for cron jobs
- Uses gosu for proper privilege dropping

## Environment Variables

- `CRON_SCHEDULE`: Cron schedule expression (required)
- `CRON_APTS`: Space-separated list of additional packages to install (optional)

## Cron Schedule Format Guide

The CRON_SCHEDULE must contain all 5 components:

    ┌───────────── minute (0 - 59)
    │ ┌───────────── hour (0 - 23)
    │ │ ┌───────────── day of month (1 - 31)
    │ │ │ ┌───────────── month (1 - 12)
    │ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
    │ │ │ │ │
    * * * * *

Common Examples:
- Every minute: `* * * * *`
- Every 5 minutes: `*/5 * * * *`
- Every hour: `0 * * * *`
- Every day at midnight: `0 0 * * *`
- Every Monday at 3am: `0 3 * * 1`

Special Characters:
- `*` : any value
- `*/n`: every n intervals
- `n-m`: range from n to m
- `n,m`: specific values n and m

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## License
MIT 