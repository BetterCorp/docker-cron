#!/bin/bash
set -e

echo ""
echo "************"
echo "TIME: $(date)"
echo "COMMAND: $(cat $1)"
echo "************"
exec /usr/sbin/gosu dockercron sh -c "$(cat $1)"
echo ""
exit 0
