#!/bin/bash

# Quick and dirty script to import backlogs with ftp2koha

SITE=FIXME
SIGEL=FIXME

SCRIPT="/opt/ftp2koha/ftp2koha.pl"
CONFIG="/etc/koha/sites/$SITE/ftp2koha-config-$SITE.yaml"
LOGDIR="/etc/koha/sites/$SITE/ftp2koha/"

for DATE in 2022-06-08 2022-06-09 2022-06-10 2022-06-11 2022-06-12 2022-06-13 ; do

    LOGFILE="ftp2koha-$SITE-$DATE-backlog.txt"
    LOGFILEPATH="$LOGDIR/$LOGFILE"
    echo "Logging to $LOGFILEPATH"

    # Remove dashes from the date
    FILEDATE="${DATE//-}"
    FILE="$SIGEL.$FILEDATE.marc"
    echo "Working on $FILE"

    sudo /usr/sbin/koha-shell -c "perl $SCRIPT -c $CONFIG --debug --verbose --filename $FILE" $SITE &> $LOGFILEPATH

    # MSG=""
    # if [ $( tail -1 "$LOGFILEPATH" ) == 'DONE' ]; then
    #     MSG="Subject:ftp2koha backlog $FILE OK"
    # else
    #     MSG="Subject:ftp2koha backlog $FILE FAIL"
    # fi
    # echo $MSG | sendmail magnus@libriotech.no

done
