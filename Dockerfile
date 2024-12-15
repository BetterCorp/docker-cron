FROM ubuntu:latest

# Install required packages
RUN apt-get update && apt-get install -y \
  ca-certificates \
  curl \
  cron \
  gosu \
  inotify-tools \
  # Create user if group doesn't exist
  && (getent group dockercron || groupadd -r dockercron) \
  && useradd -r -g dockercron -d /home/dockercron -s /sbin/nologin -c "Cron user" dockercron

# Copy and set up entrypoint
COPY entrypoint.sh /entrypoint.sh
COPY cron.sh /cron.sh
RUN chmod 544 /entrypoint.sh /cron.sh

ENTRYPOINT ["/entrypoint.sh"]
