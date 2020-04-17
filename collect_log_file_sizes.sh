#!/bin/bash

# Used to collect log file names and sizes from a Check Point management server
# to determine logging rate from a previous period of days from the day the script was run
# Script assumes you have regular log file rotation, and is looking for a specific name format: YEAR-MON-DAY*.log
# Output format will be a CSV file which is intended to be opened with a spreadsheet program for analysis
#
# Author: Joe Audet
#
# v1 - 2020APR14
# v2 - 2020APR15

# get CP environment
. /etc/profile.d/CP.sh

# check if script is running with root privileges
if [ ${EUID} -ne 0 ];then
  echo "Please run as admin";
  exit 1
fi

#Define misc variables
DAYS_BACK=7;                                                                #Amount of days to go back in collecting log file sizes
TODAY=$(date +"%Y-%m-%d_%H%M");                                             #Creates a date and time stamp for the output file
OUTPUT_DIR="/home/admin";                                                   #Directory to create output file in
OUTPUT_FILE_NAME="$OUTPUT_DIR/$HOSTNAME-log_sizing_output-$TODAY.csv";      #Output file name

#Define a function to generate and record the output of file sizes we want
#looking for a specific name format: YEAR-MON-DAY*.log
collect_log_file_data()
{
    LOG_FILE_SIZE="";
    LOG_FILE_NAME="";
    LOG_FILE_CUSTOMER="";
    LOG_FILE_DATE=$(date --date="-$x days" +"%Y-%m-%d");
    
    #Check if file pattern match exists, if not put an error message in the log instead of empty commas
    if [ -e "$FWDIR/log/$LOG_FILE_DATE*.log" ];
    then
        LOG_FILE_SIZE="$(ls -l $FWDIR/log/$LOG_FILE_DATE*.log | awk '{print $5}')";
        LOG_FILE_NAME="$(ls -l $FWDIR/log/$LOG_FILE_DATE*.log | awk '{print $9}')";
        
        # Process differently for an SMS versus an MDS server
        if [ -z ${MDSVERUTIL+x} ];
        then
            echo "$LOG_FILE_SIZE,$(basename $LOG_FILE_NAME)" >> $OUTPUT_FILE_NAME;
        else
            LOG_FILE_CUSTOMER="$(dirname $LOG_FILE_NAME | cut -d '/' -f5)";
            echo "$LOG_FILE_SIZE,$LOG_FILE_CUSTOMER,$(basename $LOG_FILE_NAME)" >> $OUTPUT_FILE_NAME;
        fi
    else
        # Process differently for an SMS versus an MDS server
        if [ -z ${MDSVERUTIL+x} ];
        then
            echo "$LOG_FILE_DATE*.log entries do not exist in $FWDIR/log" >> $OUTPUT_FILE_NAME;
        else
            LOG_FILE_CUSTOMER="$(dirname $LOG_FILE_NAME | cut -d '/' -f5)";
			echo "Domain: $LOG_FILE_CUSTOMER $LOG_FILE_DATE*.log entries do not exist in $FWDIR/log" >> $OUTPUT_FILE_NAME;
        fi
    fi
}

# Process differently for an SMS versus an MDS server
if [ -z ${MDSVERUTIL+x} ];
then
    #Go back specified amount of days and collect log data
    echo "File_Size,File_Name" >> $OUTPUT_FILE_NAME;
    for (( x=DAYS_BACK; x>=1; --x ))
    do
        collect_log_file_data
    done
else
    #Loop through each MDS domain on the server
    echo "File_Size,Domain,File_Name" >> $OUTPUT_FILE_NAME
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
