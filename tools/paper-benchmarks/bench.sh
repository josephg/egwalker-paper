#!/usr/bin/env bash
set -e
#set -o xtrace

# shellcheck disable=SC2034
#RUSTFLAGS='-C target-cpu=native'

start_time=$(date +%s)   # Capture start time in seconds

cargo build --profile bench

end_time=$(date +%s)     # Capture end time in seconds

# Calculate duration
duration=$((end_time - start_time))

# Check if duration is less than 1 second
if [ $duration -gt 1 ]; then
  echo "Waiting 5s for CPU to cool down"
  sleep 5
fi

#taskset 0x1 nice -10 cargo run --profile bench -- --bench "$@"
taskset 0x1 nice -10 target/release/paper-benchmarks --bench "$@"
