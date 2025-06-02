#!/usr/bin/env bash
# Wrap a podman-compose function to report status back to systemd for watchdog service.
#
# Usage:
#   ./podman-compose-sysd-notify podman-compose up -d

SLEEP_SEC=10
POD_NAME="pod_$(basename $PWD)"

is_pod_running () {
    # Check if a pod is running.
    #
    # Usage:
    #   is_pod_running "pod_jellyfun"

    # grep returns 0 if string is found.
    (podman pod ps --filter name=$1 --format "{{.Status}}" | grep -i running) &> /dev/null
    POD_RUNNING=$?

    (podman pod ps --filter name=$1 --format "{{.Status}}" | grep -i degraded) &> /dev/null
    POD_DEGRADED=$?

    # For debugging
    # echo ${POD_RUNNING} 
    # echo ${POD_DEGRADED}

    if [ ${POD_RUNNING} -ne 0 ]; then
        # Pod is NOT running.
        return 1
    fi

    if [ ${POD_DEGRADED} -eq 0 ]; then
        # Pod is running in DEGRADED state.
        return 1
    fi

    # Pod is running normally.
    return 0
}

# Call user command
bash -c "$*"

# 
systemd-notify --ready --status "${POD_NAME} started"
sleep $SLEEP_SEC

while true
do 
    if (is_pod_running ${POD_NAME}); then
        systemd-notify WATCHDOG=1 --status "${POD_NAME} is normal"
    fi
    sleep $SLEEP_SEC
done

