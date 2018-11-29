#!/bin/bash
#
# Wrapper script to mp4-stitch.pl
#
# Finds all smil files in SMIL_DIR and uses them as input
# to mp4-stitch.pl perl script.

# Directory where to find SMIL files to parse
SMIL_DIR=$HOME/smil

# current date/time, e.g. 2010-07-13-20-14-59
NOW=$(date +"%Y-%m-%d-%H-%M-%S")

# log both stdout/stderr to this file
LOGFILE=stitch-$NOW.log

exec 1> >(tee -a $LOGFILE) 2>&1

# Iterate over each SMIL file
for smil in `find $SMIL_DIR -name '*.smil'`
do
	short_name=`basename $smil`
	if grep -q $short_name results.txt; then
		echo "Skipping $short_name, already processed."
		continue
	else
		./mp4-stitch.pl $smil
		RETVAL=$?
		if [ $RETVAL -eq 0 ]; then
			STATUS=PASS
		else
			STATUS=FAIL
		fi
		echo "$short_name: $STATUS" >> results.txt
	fi
done

