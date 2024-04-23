#!/bin/bash
set -e

#cd ../../../diamond-types/paper_benchmark_data/
for file in *.dt; do
  filename=$(basename "$file" .dt)
  echo $filename
  dt export-trace "$file" -o "${filename}.json"
done
