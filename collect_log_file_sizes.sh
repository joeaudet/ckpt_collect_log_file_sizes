#!/bin/bash

#Used to collect log file names and sizes from a Check Point management server
#to determine logging rate from a previous period of days from the day the script was run
#Script assumes you have regular log file rotation
#v1 - 2020APR14

# get CP environment
. /etc/profile.d/CP.sh

# check if script is running with root privileges
if [ ${EUID} -ne 0 ];then
  echo "Please run as admin";
  exit 1
fi

# remove lock
echo "Removing lock";
clish -c 'lock database override' > /dev/null

#Define misc variables
MDS=false;
DAYS_BACK=7;
TODAY=$(date +"%Y-%m-%d");
OUTPUT_DIR="/home/admin";
OUTPUT_FILE_NAME="$OUTPUT_DIR/$HOSTNAME-log_sizing_output-$TODAY.csv";

#Define a function to generate the output of file sizes we want
collect_log_file_data()
{
    LOG_FILE_SIZE="";
    LOG_FILE_NAME="";
    LOG_FILE_CUSTOMER="";
    LOG_FILE_SIZE="$(ls -l $FWDIR/log/$(date --date="-$x days" +"%Y-%m-%d")*.log | awk '{print $5}')";
    LOG_FILE_NAME="$(ls -l $FWDIR/log/$(date --date="-$x days" +"%Y-%m-%d")*.log | awk '{print $9}')";
    LOG_FILE_CUSTOMER="$(dirname $LOG_FILE_NAME | cut -d '/' -f5)";
    echo "$LOG_FILE_SIZE,$LOG_FILE_CUSTOMER,$(basename $LOG_FILE_NAME)" >> $OUTPUT_FILE_NAME;
}

# Process differently for an SMS versus an MDS server
if [ -z ${MDSVERUTIL+x} ];
then
    #Go back specified amount of days and collect log data
    for (( x=DAYS_BACK; x>=1; --x ))
    do
        collect_log_file_data
    done
else
    #Loop through each MDS domain on the server
    for CMA_NAME in $($MDSVERUTIL AllCMAs)
    do
        echo "Currently processing domain: $CMA_NAME";
		#Switch to domain environment
        mdsenv $CMA_NAME
        #Go back specified amount of days and collect log data
        for (( x=DAYS_BACK; x>=1; --x ))
        do
                collect_log_file_data
        done
    done
fi

echo "Logged output stored in the following file: $OUTPUT_FILE_NAME"