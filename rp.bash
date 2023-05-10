#!/bin/bash

# Default number of threads
num_threads=10


display_help() {
  echo "IP Range Scanner"
  echo "Usage: rp.sh [OPTIONS] <IP_RANGE>"
  echo ""
  echo "Options:"
  echo "  -t NUM_THREADS     Specify the number of threads (default: 10)"
  echo "  -h                 Display this help menu"
}

# Array to store child process IDs
pids=()

# Function to handle SIGINT signal (Ctrl+C)
function handle_interrupt {
  echo "Script interrupted. Exiting..."

  # Kill child processes (threads)
  for pid in "${pids[@]}"; do
    kill $pid >/dev/null 2>&1
  done

  exit 0
}

# Function to check if an IP is live
check_ip() {
  ip=$1
  ping -c 1 -W 1 $ip >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "$ip"
  fi
}

# Parse command line options
while getopts "t:h" opt; do
  case ${opt} in
      t)
      num_threads=$OPTARG
      ;;
    o)
      output_file=$OPTARG
      ;;
    h)
      display_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Register the signal handler
trap handle_interrupt SIGINT

# Read IP ranges from file or pipeline
if [ -n "$1" ]; then
  # Read IP ranges from file
  if [ ! -f "$1" ]; then
    echo "Error: Input file not found."
    exit 1
  fi
  input_file="$1"
else
  # Read IP ranges from pipeline
  input_file="/dev/stdin"
fi

# Function to process IP ranges in parallel
process_ranges() {
  local start_ip=$1
  local num_ips=$2
  for ((i = 0; i < num_ips; i++)); do
    ip=$((start_ip + i))
    d1=$((ip >> 24 & 255))
    d2=$((ip >> 16 & 255))
    d3=$((ip >> 8 & 255))
    d4=$((ip & 255))
    current_ip="$d1.$d2.$d3.$d4"
    check_ip $current_ip
  done
}

# Read IP ranges and process them in parallel using threads
while read -r ip_range; do
  network=$(echo $ip_range | cut -d'/' -f1)
  prefix=$(echo $ip_range | cut -d'/' -f2)
  num_ips=$((2 ** (32 - prefix)))

  IFS='.' read -r i1 i2 i3 i4 <<< "$network"
  start_ip=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))

  # Split the IP range into chunks based on the number of threads
  chunk_size=$((num_ips / num_threads))
  remainder=$((num_ips % num_threads))

  for ((i = 0; i < num_threads; i++)); do
    start=$((i * chunk_size))
    if [ $i -eq $((num_threads - 1)) ]; then
      chunk_size=$((chunk_size + remainder))
    fi
    process_ranges "$((start_ip + start))" "$chunk_size" &
    pids+=($!)  # Store child process ID (thread)
  done
  wait
done < "$input_file"
