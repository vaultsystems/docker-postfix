#!/bin/sh

# Localize these. The -G option does nothing before Postfix 2.3.
INSPECT_DIR=/var/spool/mail
SENDMAIL="/usr/sbin/sendmail -G -i" # NEVER NEVER NEVER use "-t" here.

# Exit codes from <sysexits.h>
EX_TEMPFAIL=75
EX_UNAVAILABLE=69

# Clean up when done or when aborting.
trap "rm -f in.$$" 0 1 2 3 15

# Start processing.
cd $INSPECT_DIR || {
  echo $INSPECT_DIR does not exist; exit $EX_TEMPFAIL; }

cat >in.$$ || { 
  echo Cannot save mail to file; exit $EX_TEMPFAIL; }

curl -f -X POST -F file=@in.$$ http://swiftmail:5000/ || {
  echo Message could not be uploaded; exit $EX_TEMPFAIL; }

exit $?