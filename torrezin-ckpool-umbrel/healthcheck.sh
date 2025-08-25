#!/bin/bash
# Health check script for CKPool

# Check if CKPool process is running
if ! pgrep -x "ckpool" > /dev/null; then
    echo "CKPool process not running"
    exit 1
fi

# Check if stratum port is responding
if ! timeout 5 bash -c "</dev/tcp/localhost/3333" 2>/dev/null; then
    echo "Stratum port 3333 not responding"
    exit 1
fi

# Check if web interface port is responding
if ! timeout 5 bash -c "</dev/tcp/localhost/3334" 2>/dev/null; then
    echo "Web interface port 3334 not responding"
    exit 1
fi

# Check database connectivity
if ! pg_isready -h db -p 5432 -U ckpool -d ckpool >/dev/null 2>&1; then
    echo "Database not accessible"
    exit 1
fi

echo "CKPool is healthy"
exit 0