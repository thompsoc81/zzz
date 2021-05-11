#!/bin/bash
#
# this script is meant as an alternative to running `sleep` for
# situations in which the user would want to monitor the progress
# of the waiting period.  normally `sleep` is completely silent.
# for automated scripts this is perfectly fine and desirable.
# sometimes, though, a user may want to run a long sleep in an
# interactive shell to delay a particular command and would like
# to know how much time remains until their next command executes.
#
# this script simply runs sleep for a much shorter time period
# for the number of iterations required to reach the total span of
# the user's delay so it can update a progress bar and a countdown 
# timer on stdout between each iteration.  the start/stop nature of 
# this process and the writing to terminal will introduce a small
# amount of overhead.  an attempt is made to correct for this drift
# periodically but with the disclaimer: use as at your own risk.
#
# October 2020
#


# the amount of time (in seconds) for each loop iteration
FREQ=1

# the number of characters wide the progress bar is drawn.
# the output of this script is based on an 80 column term.
BARLEN=40

# the number of seconds between performing a clock drift correction
SKEWCHECK=900

# it's probably not necessary to specify the path to `sleep`, but for
# some reason the first system where this script was written had two
# separate copies installed (and not one being a symlink to the other)
SLEEP="/bin/sleep"
#SLEEP="/usr/bin/sleep"


# some extra output for debugging can be enabled by setting this var
#DEBUG=1
function debug_echo {
  if [ -z ${DEBUG:+true} ]; then
    :
  else
    echo "$1"
  fi
}


# the block of instructions text describing all the available modes
function arg_help {
  echo
  echo "    Time can be specified as one total value or as any combination"
  echo "    across several arguments that will be summed.  (Examples below.)"
  echo
  echo "    Allowable units for each argument are any one of these with any"
  echo "    combination of upper or lower-case letters and with no space "
  echo "    between the number and the string:"
  echo
  echo "           s, sec, second, seconds"
  echo "           m, min, minute, minutes"
  echo "           h, hr, hour, hours"
  echo
  echo "    Alternately, if the first argument begins with '@', all arguments"
  echo "    will be treated the same as the -d option of the \`date\` command."
  echo "    (See: \"DATE STRING\" section of \`date\` man page for details)"
  echo
  echo "    A range can be defined to sleep a random number of seconds.  Use"
  echo "    only two arguments.  One must begin with a minus (-) to set the"
  echo "    minimum value, and the other must start with plus (+) to set the"
  echo ".   maximum value.  This mode does not support parsing units and the"
  echo "    arguments must be specified in seconds.  Order does not matter."
  echo
  echo "    Examples:  ${0##*/} 60"
  echo "               ${0##*/} 1h 2m 3s"
  echo "               ${0##*/} 4min 5 6HOURS 7s 8MiNuTe 9sec"
  echo "               ${0##*/} @4:37pm tomorrow"
  echo "               ${0##*/} -60 +120"
  echo
  
  # a dumb little easter egg for the cool people who load 
  # their system down with lots of stupid extra packages...
  if type "cowsay" &> /dev/null; then
    if type "lolcat" &> /dev/null; then
      cowsay -d "ZzzZzZzZZzz...." | sed 's/^/                    /' | lolcat -a
    else
      cowsay -d "ZzzZzZzZZzz...." | sed 's/^/                    /'
    fi
    echo
  fi
}


# check we've actually been given a time to sleep
if [ $# -eq 0 ]; then
  echo
  echo " ERROR: Must specify a period of time to sleep!"

  arg_help

  exit 1
fi


# check if the user needs a hint about what to do
if [[ "${1}" =~ ^(-h|--help) ]]; then
  arg_help

  exit
fi


# check to see if the first argument starts with '@' which is our shortcut
# to instead pass the full list of args to `date` to get a fixed time
# against which the elapsed seconds from now are calculated for the delay
if [[  "${1}" =~ ^@.* ]]; then
  # join all the args together as one string
  FUTURE="$*"

  # chop off the lead @
  FUTURE="${FUTURE:1}"

  # use `date` to convert this readable string into a timestamp
  FUTURE="$(date -d "${FUTURE}" +%s)"

  # calculate the elapsed time between now and then
  NOW="$(date +%s)"
  DIFF_SEC="$(( ${FUTURE} - ${NOW} ))"

  # make sure this is not an expired time
  if [[ "${DIFF_SEC}" -lt 0 ]]; then
    TOM_CMD="${0##*/} ${1} tomorrow"
    echo "WARNING: The given time (\"${1}\") is in the past.  Not sleeping."
    echo "  If you meant tomorrow, use this:  ex: ${TOM_CMD}"
    DIFF_SEC=0
  fi

  # change the arguments to be this number of elapsed seconds
  set -- "${DIFF_SEC}"
fi


# if there are exactly two numeric arguments where one starts with a plus
# and the other a minus, this will be taken to mean a range within which
# a rnadom number of seconds will be used.  the minus is the minimum bounds, 
# the plus is the maximum bounds, the order does not matter, and the range
# will be inclusive to these bounds. (ex: "+60 -45" would denote [45,60] ).
if [[ $# -eq 2 ]]; then

  LOWER=-1
  UPPER=-1
  
  # process the first argument
  if [[ ${1} = -* ]]; then
    LOWER="${1:1}"
  elif [[ ${1} = +* ]]; then
    UPPER="${1:1}"
  fi

  # process the second argument
  if [[ ${2} = -* ]]; then
    LOWER="${2:1}"
  elif [[ ${2} = +* ]]; then
    UPPER="${2:1}"
  fi

  # if we found one of each, pocess the random range request
  if [ ${LOWER} -eq -1 ] || [ ${UPPER} -eq -1 ]; then
    # while we were given two arguments, we were not given a random range
    :
  elif [ ${LOWER} -eq ${UPPER} ]; then
    # we found both values for the range, but they are identical...
    set -- "${LOWER}"
  else
    # we were given both an upper and lower bounds for a range!
    debug_echo "RANDOM LOWER BOUND: ${LOWER}"
    debug_echo "RANDOM UPPER BOUND: ${UPPER}"

    # make sure they are in the correct min/max order
    if [ ${UPPER} -lt ${LOWER} ]; then
      # whoops.  let's just swap them for the user.
      TEMP="${LOWER}"
      LOWER="${UPPER}"
      UPPER="${TEMP}"
    fi

    # figure out the range
    let "RANGE = ${UPPER} - ${LOWER}"

    # add a random amount within the scale of the range to the minimum
    let "RND_SEC = ${LOWER} + ( $RANDOM % ${RANGE} )"
    # TODO: find a way to handle ranges wider than 32k, the max $RANDOM

    # repalce the argument list with our newly calculated random value
    set -- "${RND_SEC}"

    debug_echo "RANDOM SLEEP TIME: ${RND_SEC}"
  fi
fi


# some newer versions of `sleep` allow you to specify minutes or hours
# by feeding in arguments like '30m' or '2h'.  we will support this by
# looping through all arguments, determinging if they are one of these,
# converting them into seconds, and summing them all together so that
# a user could do something like '1h 23m 45s' which becomes 5025 seconds.
# (there's probably a much better way to handle all these possible cases.)
HOURS=0
MINUTES=0
SECONDS=0
for ARG in "$@"; do
  # lowercase all the letters to save ourselves half the test cases
  ARG="${ARG,,}"

  # hour arguments
  if [[ "${ARG}" == *hours ]]; then
    let "HOURS = ${HOURS} + ${ARG%hours}"
  elif [[ "${ARG}" == *hour ]]; then
    let "HOURS = ${HOURS} + ${ARG%hour}"
  elif [[ "${ARG}" == *hr ]]; then
    let "HOURS = ${HOURS} + ${ARG%hr}"
  elif [[ "${ARG}" == *h ]]; then
    let "HOURS = ${HOURS} + ${ARG%h}"

  # minute arguments
  elif [[ "${ARG}" == *minutes ]]; then
    let "MINUTES = ${MINUTES} + ${ARG%minutes}"
  elif [[ "${ARG}" == *minute ]]; then
    let "MINUTES = ${MINUTES} + ${ARG%minute}"
  elif [[ "${ARG}" == *min ]]; then
    let "MINUTES = ${MINUTES} + ${ARG%min}"
  elif [[ "${ARG}" == *m ]]; then
    let "MINUTES = ${MINUTES} + ${ARG%m}"

  # seconds arguments
  elif [[ "${ARG}" == *seconds ]]; then
    let "SECONDS = ${SECONDS} + ${ARG%seconds}"
  elif [[ "${ARG}" == *second ]]; then
    let "SECONDS = ${SECONDS} + ${ARG%second}"
  elif [[ "${ARG}" == *sec ]]; then
    let "SECONDS = ${SECONDS} + ${ARG%sec}"
  elif [[ "${ARG}" == *s ]]; then
    let "SECONDS = ${SECONDS} + ${ARG%s}"

  # we'll treat no specified units as just plain seconds
  elif [[ "${ARG}" =~ [^[:digit:]] ]]; then
    # error situation: a non-numeric arg with no units
    # TODO: properly deal with this instead of just ignoring it
    echo
    echo "ERROR: The arguments could not be parsed.  Please check formatting."

    arg_help

    exit 2
  else
    let "SECONDS = ${SECONDS} + ${ARG}"
  fi
done

let "DELAY = ( ${HOURS} * 3600 ) + ( ${MINUTES} * 60 ) + ${SECONDS}"
#DELAY=${1}

let "STOP = $(date +%s) + ${DELAY}"


# check if this is being run interactively and if colors are supported.
# this whole section was stolen from an example answer on stackoverflow.
if test -t 1; then
  COLORS=$(tput colors)

  if test -n "$COLORS" && test $COLORS -ge 8; then
    NORMAL="$(tput sgr0)"
    BOLD="$(tput bold)"
    BLACK="$(tput setaf 0)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)"
    CYAN="$(tput setaf 6)"
    WHITE="$(tput setaf 7)"
  fi
fi


# vars we will need to calculate each loop iteration
BLIPS=0
PERCENT=0
PERCENTSTR="0.0"
ELAPSED=0
REMAINING=${DELAY}
UNTILCHECK=${SKEWCHECK}
TOTALSKEW=0


# loop and call sleep for ${FREQ} seconds as many times as needed
while [ "${REMAINING}" -ge "${FREQ}" ]; do
  # print the progress bar and countdown line to stdout
  PROGRESS="${BOLD}${YELLOW}[${NORMAL}${YELLOW}"
  for i in $(seq 1 ${BARLEN}); do
    if [ "${i}" -le "${BLIPS}" ]; then
      PROGRESS="${PROGRESS}#"
    else
      PROGRESS="${PROGRESS} "
    fi
  done
  PROGRESS="${PROGRESS}${BOLD}]${NORMAL}"
  PROGRESS="${PROGRESS}${BOLD}${YELLOW} <${NORMAL}${YELLOW}"
  PROGRESS="${PROGRESS}${PERCENTSTR}%${BOLD}>${NORMAL}"

  CLOCK="${CYAN}`date -d@${REMAINING} -u +%H:%M:%S`${NORMAL}"

  REMAINFMT="${REMAINING}"
  if [ "${REMAINING}" -gt 9999 ]; then
    if type "numfmt" &> /dev/null; then
      # if the system has `numfmt`, we can easily add separators if >10k
      REMAINFMT="$( numfmt --grouping ${REMAINING} )"
    fi
  fi

  INDENT="  "
  if [ "${REMAINING}" -gt 9999 ]; then
    # our status line is very close to the standard 80 char terminal width.
    # if the countdown is over 10k seconds, the added comma will push it
    # over that limit and cause a line wrap.  we'll attempt to prevent this
    # by cutting out some of the extra whitespace.
    INDENT=""
  fi

  TAB="\t"
  if [ "${REMAINING}" -gt 999999 ]; then
    # similarly, if the remaining time is insanely over a million seconds,
    # we will forgo having the tab between the countdown and the progress
    # bar as it will cause a spillover to the next tab point and line wrap
    TAB=""
  elif [ "${REMAINING}" -eq 999999 ]; then
    # at the very specific case we are switching from not having a tab to
    # having a tab, we need to clear out the line the first time because
    # the newly included tab will ridiculously skip over redrawing the
    # column where the old ")" of the countdown was, leaving it on the
    # screen like this:  " (999,999 sec) ) [####"
    echo -en "                                 \r"
  fi
  
  COUNTDOWN="${BOLD}${GREEN}(${NORMAL}${GREEN}${REMAINFMT}sec${BOLD})${NORMAL}"

  echo -ne "${INDENT}${CLOCK}  ${COUNTDOWN} ${TAB}${PROGRESS}  \r"
  # note: -n does not append a newline, which is important for this script.
  #       -e tells echo to process escaped characters like the \r and \t.
  #       the \r will return us back to the first column.  without also
  #       having the newline, it means we will keep going back to the start 
  #       of the same line of stdout, overwriting the previous progress.


  # do the next chunk of sleeping
  ${SLEEP} ${FREQ}


  # update the variables for the next iteration
  let "REMAINING = ${REMAINING} - ${FREQ}"
  let "ELAPSED = ${DELAY} - ${REMAINING}"
  let "PERCENT = ${ELAPSED} * 100 / ${DELAY}"
  let "BLIPS = ${PERCENT} * ${BARLEN} / 100"


  # the percentage calculated above is an integer value for calculating
  # the number of "blips" to draw in the progress bar.  we also want
  # to do some string trickery to create a floating version that is a 
  # little more precise with one decimal place for the readable number.
  # rather than involve some sort of a fancy string formatter, we will
  # just scale the number an extra digit longer, chop the last char off
  # the string, and slap it back on with a '.' in the middle.
  let "PERCENTSTR = ${ELAPSED} * 1000 / ${DELAY}"
  if [ "${#PERCENTSTR}" -lt 2 ]; then
    # pad a leading zero for before decimal if under 1.0% complete
    PERCENTSTR="0${PERCENTSTR}"
  fi
  PERCENTSTR="${PERCENTSTR: 0: $((${#PERCENTSTR}-1))}.${PERCENTSTR: -1}"

  
  # the way this script works will add a tiny bit of overhead on each
  # loop.  while it's probably negligable for short periods, a few ms
  # each loop for thousands of iterations can really add up over time.
  # anecdotally, the system where this script was developed tends to add
  # 2-3 seconds for every 15 minutes of countdown under normal, day-to-day 
  # cpu loads for a workstation.  on a raspberry pi where this script was
  # tested, it added 20 seconds every 15 minutes!  therefore, we will 
  # periodically perform adjustments to correct skew that has accumulated.
  let "UNTILCHECK = ${UNTILCHECK} - ${FREQ}"
  if [ ${UNTILCHECK} -le 0 ]; then
    # our countdown within a countdown has expired...

    # get the current time in seconds since the epoch
    NOW="$(date +%s)"

    # calculate the true remaining time from new now-now, not old now-then
    let "NEWREMAIN = ${STOP} - ${NOW}"

    # report on the discovered offset and record it for debugging
    let "CORRECTION = ${REMAINING} - ${NEWREMAIN}"
    let "TOTALSKEW = ${TOTALSKEW} + ${CORRECTION}"
    if [ ${CORRECTION} -gt 0 ]; then
      debug_echo "SKEW CHECK @ `date` CORRECTED ${CORRECTION} SECONDS"
    fi

    # update the remaining time with newly calculated true remaining time
    REMAINING=${NEWREMAIN}

    # make sure we haven't corrected into a negative remaining time if we
    # were nearly at the end and have just shifted ourselves into the past
    if [ ${REMAINING} -lt 0 ]; then
      REMAINING=0
    fi

    # reset the countdown-in-a-countdown until the next skew check is needed
    UNTILCHECK=${SKEWCHECK}
  fi
done


# take care of any remaining few seconds less than one whole ${FREQ}
${SLEEP} ${REMAINING}


# the last progress update should have ended with an \r, but at 75+ chars,
# that status line is almost certainly going to be longer than most users'
# $PS1 prompts.  one final output of a whole bunch of spaces (and \r) should 
# clean it up so user doesn't see half a letover progress bar remaining on
# the tail end of the same terminal line where their next prompt is drawn.
CLEANUP="\r"
for j in {1..78}; do
  CLEANUP=" ${CLEANUP}"
done
echo -ne "${CLEANUP}\r"


# print a final report (if debugging requested) about total corrections taken
# and compare the expected finish time to the actual finish time
debug_echo "CORRECTED ${TOTALSKEW} SKEW SECONDS ACROSS ${DELAY} TOTAL SECONDS"
debug_echo " EXPECTED FINISH TIME:  `date -d@${STOP}`"
debug_echo "   ACTUAL FINISH TIME:  `date`"

