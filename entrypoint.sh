#!/bin/bash
set -e

validate_cron() {
  local schedule="$1"
  local min hour dom month dow

  # Check if we have exactly 5 components
  if [[ ! "$schedule" =~ ^[[:space:]]*[0-9*-,/]+[[:space:]]+[0-9*-,/]+[[:space:]]+[0-9*-,/]+[[:space:]]+[0-9*-,/]+[[:space:]]+[0-9*-,/]+[[:space:]]*$ ]]; then
    echo "Error: Invalid cron format. Must have exactly 5 components: minute hour day-of-month month day-of-week" >&2
    return 1
  fi

  read -r min hour dom month dow <<<"$schedule"

  # Validate minutes (0-59)
  if [[ ! "$min" =~ ^(\*|[0-9]|[1-5][0-9]|(\*/|[0-9]+-)[0-9]+)(,[0-9]|,[1-5][0-9])*$ ]]; then
    echo "Error: Invalid minute field ($min). Must be 0-59, *, */n, or n-m" >&2
    return 1
  fi

  # Validate hours (0-23)
  if [[ ! "$hour" =~ ^(\*|[0-9]|1[0-9]|2[0-3]|(\*/|[0-9]+-)[0-9]+)(,[0-9]|,1[0-9]|,2[0-3])*$ ]]; then
    echo "Error: Invalid hour field ($hour). Must be 0-23, *, */n, or n-m" >&2
    return 1
  fi

  # Validate day of month (1-31)
  if [[ ! "$dom" =~ ^(\*|[1-9]|[12][0-9]|3[01]|(\*/|[0-9]+-)[0-9]+)(,[1-9]|,[12][0-9]|,3[01])*$ ]]; then
    echo "Error: Invalid day of month field ($dom). Must be 1-31, *, */n, or n-m" >&2
    return 1
  fi

  # Validate month (1-12)
  if [[ ! "$month" =~ ^(\*|[1-9]|1[0-2]|(\*/|[0-9]+-)[0-9]+)(,[1-9]|,1[0-2])*$ ]]; then
    echo "Error: Invalid month field ($month). Must be 1-12, *, */n, or n-m" >&2
    return 1
  fi

  # Validate day of week (0-7, where both 0 and 7 represent Sunday)
  if [[ ! "$dow" =~ ^(\*|[0-7]|(\*/|[0-7]+-)[0-7]+)(,[0-7])*$ ]]; then
    echo "Error: Invalid day of week field ($dow). Must be 0-7, *, */n, or n-m" >&2
    return 1
  fi

  return 0
}

# Validate CRON_SCHEDULE
if ! validate_cron "$CRON_SCHEDULE"; then
  echo "Error: Invalid CRON_SCHEDULE: $CRON_SCHEDULE" >&2
  exit 2
fi

validate_packages() {
  local packages="$1"
  if [[ ! "$packages" =~ ^[[:alnum:][:space:]._-]*$ ]]; then
    echo "Invalid Package: '$packages' - ($1) should be space separated package names" >&2
    return 1
  fi
  return 0
}

# Validate CRON_APTS before using
if [ -n "$CRON_APTS" ]; then
  echo "CRON_APTS: $CRON_APTS"
  if ! validate_packages "$CRON_APTS"; then
    exit 1
  fi
  echo "Checking additional packages required: $CRON_APTS"
  apt-get install -y $CRON_APTS
fi

# Helper function to translate numeric day of week to name
translate_dow() {
  case "$1" in
  0 | 7) echo "Sunday" ;;
  1) echo "Monday" ;;
  2) echo "Tuesday" ;;
  3) echo "Wednesday" ;;
  4) echo "Thursday" ;;
  5) echo "Friday" ;;
  6) echo "Saturday" ;;
  esac
}

explain_cron() {
  local schedule="$1"
  local min hour dom month dow

  # Split the schedule into components
  read -r min hour dom month dow <<<"$schedule"

  local explanation=""

  # Minutes
  case "$min" in
    "*") explanation="every minute" ;;
    "*/5") explanation="every 5 minutes" ;;
    "*/10") explanation="every 10 minutes" ;;
    "*/15") explanation="every 15 minutes" ;;
    "*/30") explanation="every 30 minutes" ;;
    [0-9]*) explanation="at minute $min" ;;
  esac

  # Hours
  case "$hour" in
    "*") ;;
    "*/2") explanation="$explanation, every 2 hours" ;;
    "*/3") explanation="$explanation, every 3 hours" ;;
    "*/4") explanation="$explanation, every 4 hours" ;;
    "*/6") explanation="$explanation, every 6 hours" ;;
    "*/12") explanation="$explanation, every 12 hours" ;;
    [0-9]*) explanation="$explanation, at $hour:00" ;;
  esac

  # Day of month
  case "$dom" in
    "*") ;;
    "*/2") explanation="$explanation, every 2 days" ;;
    "*/7") explanation="$explanation, every 7 days" ;;
    [0-9]*) explanation="$explanation, on day $dom" ;;
  esac

  # Month
  case "$month" in
    "*") ;;
    "*/3") explanation="$explanation, every 3 months" ;;
    "*/6") explanation="$explanation, every 6 months" ;;
    [0-9]*) explanation="$explanation, in month $month" ;;
  esac

  # Day of week
  case "$dow" in
    "*") ;;
    [0-7]) explanation="$explanation, on $(translate_dow $dow)" ;;
  esac

  echo "$explanation"
}

echo "CRON_SCHEDULE: $CRON_SCHEDULE -  $(explain_cron "$CRON_SCHEDULE")"
COMMAND_FILE="/tmp/cron_command"
echo "$*" >"$COMMAND_FILE"
echo "CRON_COMMAND: $(cat $COMMAND_FILE)"

# Create cron job file with proper permissions
mkdir -p /etc/crond.d /var/log
# Escape the command properly for cron
echo "$CRON_SCHEDULE /cron.sh '$COMMAND_FILE' >> /var/log/cron.log 2>&1 || true && touch /var/log/crontab.log" >/etc/crond.d/dockercron
chmod 0644 /etc/crond.d/dockercron
touch /var/log/cron.log
touch /var/log/crontab.log
chmod 0444 /var/log/cron.log /var/log/crontab.log
chmod 0544 $COMMAND_FILE

crontab /etc/crond.d/dockercron

echo "************"
echo "Start crontab"
echo "************"
echo ""

# Start cron in foreground
cleanup() {
  echo "Shutting down..."
  kill $CRON_PID $WATCH_PID 2>/dev/null || true
  exit 0
}

trap cleanup SIGINT SIGTERM

# Start cron in foreground
cron -f &
CRON_PID=$!

if [ "${CRON_IMMEDIATE}" = "true" ]; then
  echo ""
  echo "************"
  echo "Running command immediately due to CRON_IMMEDIATE=true"
  echo "Initial immediate command"
  /cron.sh "$COMMAND_FILE" 2>&1 || true
  echo ""
  echo "************"
  echo ""
fi

while inotifywait -e attrib -q /var/log/crontab.log; do
  if [ -s /var/log/cron.log ]; then
    cat /var/log/cron.log
    truncate -s 0 /var/log/cron.log
    echo ""
    echo "************"
    echo ""
  fi
done &
WATCH_PID=$!

# Wait for signals while keeping both processes running
wait $CRON_PID $WATCH_PID

exit 0
