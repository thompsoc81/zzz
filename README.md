# zzz
## _`sleep`, but with a countdown_

This script provides an alternative to `sleep` for when the user would like to monitor the time remaining in the delay.  This is provided in both countdown (human-readable clock and total seconds) and countup (a progress bar and a percentage) on a single shell line.

![screenshot](zzz_screenshot.png?raw=true)


This was a fun little project that was born to solve two issues:  (1) the minor annoyance of running `sleep` for long periods with no idea how much time is remaining, and (2) wanting to learn how to rewrite the same line of stdout to produce things like progress bars.  This was created in an evening and a little tinkering after a few days of use.  It has not been optimized or made free of errors.  Use with caution, etc.

---

### Usage

```
$ zzz --help

    Time can be specified as one total value or as any combination
    across several arguments that will be summed.  (Examples below.)

    Allowable units for each argument are any one of these with any
    combination of upper or lower-case letters and with no space 
    between the number and the string:

           s, sec, second, seconds
           m, min, minute, minutes
           h, hr, hour, hours

    Alternately, if the first argument begins with '@', all arguments
    will be treated the same as the -d option of the `date` command.
    (See: "DATE STRING" section of `date` man page for details)

    A range can be defined to sleep a random number of seconds.  Use
    only two arguments.  One must begin with a minus (-) to set the
    minimum value, and the other must start with plus (+) to set the
    maximum value.  This mode does not support parsing units and the
    arguments must be specified in seconds.  Order does not matter.

    Examples:  zzz.sh 60
               zzz.sh 1h 2m 3s
               zzz.sh 4min 5 6HOURS 7s 8MiNuTe 9sec
               zzz.sh @4:37pm tomorrow
               zzz.sh -60 +120


```

---

### Installation

The entire code is contained within the `zzz.sh` script.  Simply copy it into a member of `${PATH}` or create a symlink to it somewhere within `${PATH}`:

```
ln -s zzz.sh /usr/local/bin/zzz
```

---

### Maintaining Accuracy (Sort Of)

After parsing all the arguments and converting them into one total number of seconds, it simply loops and calls the regular `sleep` at a set frequency&mdash;decrementing the total counter appropriately&mdash;until it reaches the end of the delay.  Regardless of what input format is used to specify the delay, they are all processed into a UNIX epoch timestamp which can have the current system clock timestamp subtracted to get the delay.

_Doesn't calling `sleep` hundreds or thousands of times introduce a lot of inefficiency and overhead?_  **Yes!**

As `sleep` itself doesn't guarantee exact timing, this script multiples each of those small margins of error by several magnitudes and introduces its own overhead to keep track of the total counter.  To make things worse, each iteration of the main loop calls numerous subshells.  This script was not written to be a minimal use of resources.

```
$ strace -c -e trace=fork,vfork,clone,execve ./zzz.sh 60

% time     seconds  usecs/call     calls    errors syscall                    
------ ----------- ----------- --------- --------- ----------------
100.00    0.011168          57       195           clone
  0.00    0.000000           0         1           execve
------ ----------- ----------- --------- --------- ----------------
100.00    0.011168                   196           total
```

With long delay periods, this _will_ introduce a growing skew to the time remaining.  On a reasonably modern workstation, testing showed this to be a few seconds for each hour of the delay period.  For a Raspberry Pi 3 where it has also been tested, this was a much less acceptable 15-20 seconds for every fifteen minutes of the delay period.

The script attempts to correct for this drifting issue by resychronizing periodically to the system clock.  When the script starts, it calculates from the inputs what the expected end time should be and stores it for later use separately from the remaining countdown variable.  Periodically (the default is five minutes) it will recalculate from this known end time and the current system clock a new remaining countdown value.  This means that regardless of how long the total delay period is, the skew should never get more than a few seconds (i.e., only however much overhead drift occurs since the last recalibration).

---

### Alternate Delay Formats

#### Date Strings
An idea for a feature that emerged early from initial use would be to support allowing the user to specify a specific end time instead of the length of the delay.  Luckily, modern verisons of the standard `date` command provide a good engine for processing a very wide spectrum of ways to specify specific dates and times via its `-d` argument.  To make use of this feature, the first argument to `zzz` should start with `@`.  All the arguments (minus the `@`) are then concatenated into one string, fed into `date`, and returned to this script as a UNIX epoch timestamp.

Details of what is allowed in the `date -d` format for a specific installation can be found with `man date` and `info date`.  The manpage for `date` is intentionally vague with its description of what can be parsed:

```

DATE STRING
       The --date=STRING is a mostly free format human  readable  date  string
       such  as  "Sun, 29 Feb 2004 16:21:42 -0800" or "2004-02-29 16:21:42" or
       even "next Thursday".  A date string may contain items indicating  cal‐
       endar  date,  time of day, time zone, day of week, relative time, rela‐
       tive date, and numbers.  An empty string indicates the beginning of the
       day.   The date string format is more complex than is easily documented
       here but is fully described in the info documentation.
```

#### Randomization
The initial use case for this script was to replace calls to `sleep` in a suite of testing scripts that simulate a user's interactions with the system.  Sometimes those "simulated user" delay periods would need to be randomzied.  This script allows the specification of a lower and upper bounds as two arguments, one beginning with `-` and the other beginning with `+`.  

---

### Public Domain

This script is given freely into the public domain with all the standard "use at your own risk" disclaimers.

(Well, technically it is [Creative Commons Zero](LICENSE) for this repository.)
