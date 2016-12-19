#!/bin/bash
########################################################################################
#
# Bash shell script for project rebuildcleanholdshelf 
#
# Find and report holds that were expird by the 'Expire Available Holds' (expshlfholds)
#    Copyright (C) 2016  Andrew Nisbet
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Copyright (c) 2016
# Rev: 
#          0.0 - Dev. 
#
#########################################################################################

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
source /s/sirsi/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
###############################################
VERSION=0.1
# If the the clean hold list report is run but the results didn't get sent to branches this report will rebuild them. 
# The report rebuilds them based on transactions saved in the history files. This script DOES NOT FTP as the standard
# cleanhold_test.pl report does.
#
# The list of branches is retrieved with getpol -tLIBR, so all branches are rebuild dynamically, though shadowed branch
# lists may not have any items.
#
# These holds are cancelled at <report time here> and appear as in the example below.
# E201612190515311703R ^S84FZFFADMIN^FEEPLMNA^FcNONE^NQ31221111890872^HH27336299^UO21221018486834^HKTITLE^HIN^HT8^^O00093
# We can grab all of these with a simple grep on today's report.
printf "gathering cancelled hold information from history file.\n" >&2
# Note: the assumption is that you are running this the day that the report failed so we look in today's history file.
# If that is not the case, you should enter the date of the file in the form of 'YYYYMM.hist.Z'.
HIST_DIR=`getpathname hist`
HIST_FILE_DATE=`date +%Y%m%d`
RECOVER_HIST_FILE=recover.$HIST_FILE_DATE.hist
# The report time is a regular expression so in the log string: 'E20161219"051"5311703R ^S8' is the time of 05:1* so anything
# from 05:10 - 05:19 inclusive. If you run your report at 6:30PM  then change this to 183.
REPORT_TIME=051
# TODO fix so correct file name is computed it recovery not from today.
egrep -e "^E$HIST_FILE_DATE$REPORT_TIME" $HIST_DIR/$HIST_FILE_DATE.hist | egrep FZFFADMIN >$RECOVER_HIST_FILE
# Let's grab as much data from hist as we can.
if [ ! -s "$RECOVER_HIST_FILE" ]; then
	printf "no holds crecovered from $HIST_DIR/$HIST_FILE_DATE.hist during $HIST_FILE_DATE$REPORT_TIME for ADMIN.\n" >&2
	exit 0
fi

# Function that prints a report for each library.
# param:  Branch 3 character code.
# return: none - outputs each list.
print_each_branch_list()
{
	clean_file=$1"_cleanholdshelf.txt"
	master_list_file=$2
	report_date=`date`
	# Hold Slip|Title|ItemID|ItemType|Pickup Library|Next Pickup User|Current Location|Call num|
	# .email crareports@epl.ca
	# $<clean_hold_shelf_list>
	# $<produced:u> Sun Dec 18 08:29:19 2016
	# $<library:1u>EPLMNA
	# .end
	# Shik - 4475|Bleeding edge / Thomas Pynchon. --|31221108246674|BOOK|||FICGENERAL|PYN|
	# Shik - 4475|Beat the champ [sound recording] / the Mountain Goats|31221112520395|CD|||MUSIC|CD ROCK MOU|
	# Shik - 4475|Transcendental youth [sound recording] / Mountain Goats|31221100396592|CD|||MUSIC|CD POP ROCK MOU|
	# Davi - 5279|High-rise [videorecording] / directed by Ben Wheatley|31221113170968|DVD21|MNA|Thom - 9122|HOLDS|DVD HIG|
	# Davi - 5279|Now you see me. 2 [videorecording] / directed by Jon M. Chu|31221113169937|DVD21|WOO|Haas - 6464|INTRANSIT|DVD NOW|
	# Muss - 2322|Colour your life : how to use the right colors to achieve balance, health, and happiness / Howard an|31221110522658|BOOK|MLW|Jose - 3594|INTRANSIT|615.8312 SUN|
	# Sten - 9472|Cook. Nourish. Glow. / Amelia Freer ; photography by Susan Bell|31221115242096|BOOK|||NONFICTION|641.563 FRE|
	# Sten - 9472|Humanism : a very short introduction / Stephen Law|31221115306032|BOOK|||NONFICTION|144 LAW|
	# Sten - 9472|What is humanism, and why does it matter  / edited by Anthony B. Pinn. --|31221110330573|BOOK|||NONFICTION|144 WHA|
	# Mans - 7243|Florida / Kim Grant [and others]|31221093220254|BOOK|||NONFICTION|917.5904 FLO 2012|
	# Mah, - 5549|A hologram for the king [videorecording] / directed by Tom Tykwer|31221113187277|BLU-RAY21|HIG|Stre - 6510|INTRANSIT|Blu-ray HOL|
	# Kost - 5637|Darksiders II [game] / developed by Vigil Games|31221100191795|VIDGAME|RIV|Thom - 0868|INTRANSIT|Video game 793.932 DAR|
	# Pawl - 6284|Globe trekker. Vietnam [videorecording]|31221106949022|DVD21|||MOVIES|DVD 915.97044 GLO 2004|
	# ...
	# .endemail
	cat << EOM > $clean_file
Hold Slip|Title|ItemID|ItemType|Pickup Library|Next Pickup User|Current Location|Call num|
.email crareports@epl.ca
$<clean_hold_shelf_list>
$<produced:u> $report_date
$<library:1u>EPL$1
.end
EOM
	# Find all the entries for the required branch and add them to this branch's clean list.
	cat $master_list_file | pipe.pl -g"c4:$1" >> $clean_file
	echo ".endemail" >> $clean_file
}

printf "refining history data.\n" >&2
cat $RECOVER_HIST_FILE | pipe.pl -W'\^' -m'c4:__#,c5:__#,c6:__#' -oc4,c6,c5 -P >item.user.hold.lst
if [ ! -s "item.user.hold.lst" ]; then
	printf "** error item.user.hold.lst not created.\n" >&2
	exit 1
fi
printf "collecting item, user data.\n" >&2
# List should look like this:
# 31221117114087|21221020649106|26387631
cat item.user.hold.lst | selitem -iB -oNCSBtly 2>/dev/null | selcallnum -iN -oSD 2>/dev/null | selcatalog -iC -oSt 2>/dev/null | seluser -iB -oBDS 2>/dev/null >raw.clean.lst

if [ ! -s "raw.clean.lst" ]; then
	printf "** error raw.clean.lst not created.\n" >&2
	exit 1
fi
# Hold Slip|Title|ItemID|ItemType|Pickup Library|Next Pickup User|Current Location|Call num|
# 21221018486834|Georgetti, Mark|27336299|31221111890872  |JBOOK|JUVGRAPHIC|EPLCSD|J YAN pt.2|Avatar, the last airbender. Smoke and shadow. Part two / Gene Luen Yang, script ; Gurihiru, art ; Michael Heisler, lettering|
printf "compiling results.\n" >&2
cat raw.clean.lst | pipe.pl -tc3 -oc0,c1,c8,c3,c5,c6,c6,c4,c7 -P >ordered.clean.lst
if [ ! -s "ordered.clean.lst" ]; then
	printf "** error ordered.clean.lst not created.\n" >&2
	exit 1
fi
cat ordered.clean.lst |  pipe.pl -m'c0:\ -\ __________#,c1:####_,c6:N/A_' -Oc1,c0 -oc1,c2,c3,c4,c5,c6,c7,c8 | pipe.pl -sc0 -P >master.clean.lst
# 6834 - Geor|Avatar, the last airbender. Smoke and shadow. Part two / Gene Luen Yang, script ; Gurihiru, art ; Michael Heisler, lettering|31221111890872  |JUVGRAPHIC|EPLCSD|N/A|JBOOK|J YAN pt.2|
# Find all the branches from the policy file and build a list for each branch.
declare -a branches=(`getpol -tLIBR | pipe.pl -oc2 -m'c2:___#'`)
# MNA
# ABB
# ...
for branch in "${branches[@]}"
do
	printf "rebuilding clean list for $branch...\n"
	print_each_branch_list $branch "master.clean.lst" 
done
printf "rebuild complete.\n" >&2
# EOF
