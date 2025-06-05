#!/bin/bash

set -euo pipefail

for i in $(seq 1 50)
do
	echo $i
	sleep 1
done
