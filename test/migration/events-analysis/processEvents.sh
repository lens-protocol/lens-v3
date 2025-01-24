#!/bin/bash

rm -fr events_processed.txt

# Read input file line by line and process
while IFS= read -r line; do
  # Check if line contains "data:"
  if [[ $line == *"data:"* ]]; then
    # Skip lines until we find "logIndex:"
    while IFS= read -r line && [[ $line != *"logIndex:"* ]]; do
      continue
    done
  fi
  echo "$line" >> events_processed.txt
done < events.txt
