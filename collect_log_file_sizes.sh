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
# v3 - 2020APR23

# get CP environment
. /etc/profile.d/CP.sh

# check if script is running with root privileges
if [ ${EUID} -ne 0 ];then
  echo "Please run as admin";
  exit 1
fi

shopt -s nullglob

#Define misc variables
DAYS_BACK=7;                                                                #Amount of days to go back in collecting log file sizes
TODAY=$(date +"%Y-%m-%d_%H%M");                                             #Creates a date and time stamp for the output file
OUTPUT_DIR="/home/admin";                                                   #Directory to create output file in
OUTPUT_FILE_NAME="$OUTPUT_DIR/$HOSTNAME-log_sizing_output-$TODAY.csv";      #Output file name, in CSV format
ERROR_FILE_NAME="$OUTPUT_DIR/$HOSTNAME-log_sizing_errors-$TODAY.txt";       #File to store errors separately to not make CSV harder to use
ERRORS_EXIST=false;                                                         #Used to indicate errors encountered

#Define a function to generate and record the output of file sizes we want
#looking for a specific name format: YEAR-MON-DAY*.log
collect_log_file_data()
{
    LOG_FILE_SIZE="";
    LOG_FILE_NAME="";
    LOG_FILE_CUSTOMER="";                                                               #Will be used to store the Domain name extracted from the file path
    LOG_FILE_DATE=$(date --date="-$1 days" +"%Y-%m-%d");                                #Format the date we will use to search for files based on amount of days back
    CURRENT_LOG_FILE_COUNT=$(find -L $FWDIR/log -name "$LOG_FILE_DATE*.log" | wc -l)    #Find if any files exist that match the parameter, and store the count (note $FWDIR/log is a symbolic link)

    #Check if file pattern match exists, if not put an error message in the log instead of empty commas
    echo "Checking if the following file(s) exist to collect sizes: $FWDIR/log/$LOG_FILE_DATE*.log";

    #Check if the CURRENT_LOG_FILE_COUNT is greater than 0, which means files exist
    if [[ $CURRENT_LOG_FILE_COUNT -ne 0 ]];
    then
        #If files exist that match the pattern, loop through them and catalog the info
        for f in $FWDIR/log/$LOG_FILE_DATE*.log; do
            #Trim out the file size in bytes from the output and store it
            LOG_FILE_SIZE="$(ls -l $f | awk '{print $5}')";
            #Trim out the file name from the output and store it
            LOG_FILE_NAME="$(ls -l $f | awk '{print $9}')";

            # Process differently for an SMS versus an MDS server
            if [ -z ${MDSVERUTIL+x} ]
            then
                #If not MDS send file info to output file
                echo "$LOG_FILE_SIZE,$(basename $LOG_FILE_NAME)" >> $OUTPUT_FILE_NAME;
            else
                #If an MDS, trim the DOMAIN NAME from the file path and store it
                LOG_FILE_CUSTOMER="$(dirname $LOG_FILE_NAME | cut -d '/' -f5)";
                #Send file info to output file
                echo "$LOG_FILE_SIZE,$LOG_FILE_CUSTOMER,$(basename $LOG_FILE_NAME)" >> $OUTPUT_FILE_NAME;
            fi
        done
    else
        #Files not found, display output on screen and set ERRORS_EXIST to true for later display purposes
        echo "$FWDIR/log/$LOG_FILE_DATE*.log does NOT exist";
        ERRORS_EXIST=true;
        # Process differently for an SMS versus an MDS server
        if [ -z ${MDSVERUTIL+x} ]
        then
            echo "$LOG_FILE_DATE*.log entries do not exist in $FWDIR/log" >> $ERROR_FILE_NAME;
        else
            LOG_FILE_CUSTOMER="$(dirname $FWDIR/log | cut -d '/' -f5)";
            echo "Domain: $LOG_FILE_CUSTOMER $LOG_FILE_DATE*.log entries do not exist in $FWDIR/log" >> $ERROR_FILE_NAME;
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
                collect_log_file_data $x
        done
    done
fi

#Let the user know where to find their output file
echo -e "\n\nLogged output stored in the following file: $OUTPUT_FILE_NAME";

#If errors encountered let user know where to find the logs
if [ "$ERRORS_EXIST" = true ]; then
    echo -e "\nErrors were encountered and stored in the following file: $ERROR_FILE_NAME";
fi
