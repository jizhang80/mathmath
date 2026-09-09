#!/bin/sh
# I11: no time estimates anywhere in docs. Flags durations of work ("2 weeks", "3 days of", "hours to").
# Instrument (C3): a grep over the staged doc files passed by pre-commit; empty input = PASS.
status=0
for f in "$@"; do
  if grep -nE '\b[0-9]+(\.[0-9]+)? ?(weeks?|months?|sprints?)\b|\b(takes|take|within|about|roughly) [0-9]+ ?(hours?|days?)\b' "$f" \
     | grep -vE 'day-N|days\]|\[ESTIMATE|\[SOURCED|spaced|ladder|retention|next_due|bucket|3 days$|7 days$' ; then
    echo "time estimate found in $f (I11)"; status=1
  fi
done
exit $status
