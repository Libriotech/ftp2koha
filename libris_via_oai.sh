#!/bin/bash

# This script is based on the example script provided by Libris:
# https://github.com/libris/export/blob/master/examplescripts/export_nix.sh
# See this document for details on how to setup and configure everything:
# https://github.com/libris/librisxl/blob/master/marc_export/marc-export-documentation.md
# ---

# Det här skriptet kan användas som exempel på hur man automatiskt hämtar poster från Libris
# Innan du använder det, se till att du fyllt i filen: etc/export.properties
#
# Lämpligen körs detta skript minut-vis m h a cron.

set -e

# Check we got right number of arguments
if [ "$#" != 1 ]; then
    echo "Usage: $0 <koha-instance>"
    exit;
fi
INSTANCE=$1

# Se till att vi inte kör flera instanser av skriptet samtidigt
[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || :

# Om vi kör för första gången, sätt 'nu' till start-tid
LASTRUNTIMEPATH="lastRun.timestamp"
if [ ! -e $LASTRUNTIMEPATH ]
then
    date -u +%Y-%m-%dT%H:%M:%SZ > $LASTRUNTIMEPATH
fi

# Avgör vilket tidsintervall vi ska hämta
STARTTIME=`cat $LASTRUNTIMEPATH`
STOPTIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
OUTFILE="export-$STOPTIME.marcxml"
LOGFILE="ftp2koha-$INSTANCE-$STOPTIME.log"
CONFIG="/etc/koha/sites/$INSTANCE/ftp2koha-config-$INSTANCE.yaml"

# Hämta data
curl --silent --fail -XPOST "https://libris.kb.se/api/marc_export/?from=$STARTTIME&until=$STOPTIME&deleted=ignore&virtualDelete=false" --data-binary @./export.properties > $OUTFILE

# Om allt gick bra, uppdatera tidsstämpeln
echo $STOPTIME > $LASTRUNTIMEPATH

MAXSIZE=105
ACTUALSIZE=$(wc -c <"$OUTFILE")
if [ $ACTUALSIZE -le $MAXSIZE ]; then
    # Too small, delete it
    rm "$OUTFILE"
    # echo "Deleted $OUTFILE, $ACTUALSIZE bytes"
else
    # Process it 
    echo "Wrote $OUTFILE, $ACTUALSIZE bytes"
    /usr/sbin/koha-shell -c "/usr/bin/perl /srv/ftp2koha/ftp2koha.pl --config $CONFIG --localfile $OUTFILE -v -d" $INSTANCE &> $LOGFILE
fi
