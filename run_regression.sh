#!/bin/bash

# Don't set -e because we want to move artifacts and print output whether or not the test fails

cd dv/uvm/core_ibex
export LM_LICENSE_FILE=27020@ec2-18-144-84-105.us-west-1.compute.amazonaws.com


make SIMULATOR=vcs TEST=riscv_jump_stress_test ITERATIONS=1
RETCODE=$?

SIM_LOG_PATH=$(find out/run/tests/**/rtl_sim.log)
if [ $SIM_LOG_PATH != '' ]; then
	echo "Contents of $SIM_LOG_PATH (or last 200 lines):"
	tail -200 $SIM_LOG_PATH
else
	echo "No rtl_sim.log was produced."
fi

mv out/run/tests /tmp/artifacts

exit $RETCODE
