#!/usr/bin/env bash
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin:"$HOME/bin"" # needed for Cygwin
##############################################################################
# substring.sh 
copyright="Copyright (c) 2016-18 Cardiff University, 2011-2014 Andreas Buerki"
# licensed under the EUPL V.1.1.
version="1.0.1"
####
# DESCRRIPTION: this is an interactive wrapper script for the Substring package
# SYNOPSIS: 	substring.sh [OPTIONS]
##############################################################################
# history
# date			change
# 2016-01-08	created as a wrapper script (previous substring.sh renamed substring-processor.sh)
# 2018-08-22	updated name to reflect new configuration of the SubString package

#############################################
# define help function
#############################################
help ( ) {
	echo "
Usage:    $(basename $0) [OPTIONS]
Options:  -h help
          -V display version, licensing and copyright information
Notes:    the output is put in a .substrd file in the pwd unless a different
          output file and location are specified."
}
# define add_to_name function
#######################
# this function checks if a file name (given as argument) exists and
# if so appends a number to the end so as to avoid overwriting existing
# files of the name as in the argument or any with the name of the argument
# plus an incremented count appended.
####
add_to_name ( ) {
count=
# establish extension
ext="$(egrep -o '\.[[:alnum:]]+$' <<<"$1")"
if [ "$ext" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed "s/$ext//" <<< "$1")"
		while [ -e "$new$add$count$ext" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed "s/$ext//" <<< "$1")$add$count$ext"
else
	if [ -e "$1" ]; then
		add=-
		count=1
		while [ -e "$1"-$count ]
			do
			(( count += 1 ))
			done
	else
		count=
		add=
	fi
	output_filename=$(echo ""$1"$add$count")
fi
}
# define getch function
getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}
#######################
# define add_windows_returns function
#######################
add_windows_returns ( ) {
sed 's/$//g' $1
}
#######################
# define remove_windows_returns function
#######################
remove_windows_returns ( ) {
sed 's///g' $1
}
#######################
# define splash0 function
#######################
splash0 ( ) {
printf "\033c"
echo "Substring (c) 2016-18 Cardiff University - Licensed under the EUPL 1.1"
echo
echo
echo
echo
echo "          SUBSTRING"
echo "          substring reduction and frequency consolidation tool"
echo "          version $version"
echo 
echo 
echo
echo "          Please choose a function"
echo
echo "          (A) consolidate n-gram list using algorithm A"
echo "          (B) consolidate n-gram lists using algorithm B"
echo "          (T) test accuracy of a consolidated list"
echo "          (X) exit"
echo
read -p '         > ' next  < /dev/tty
case $next in
	A|a)	splashA
		;;
	B|b)rm -r $SCRATCHDIR/* 2> /dev/null
		splash
		process_substring_reduction
		splash0
		;;
	T|t)	rm -r $SCRATCHDIR/* 2> /dev/null
		assess
		splash0
#		exit 0
		;;
	*)	exit 0
		;;
esac
next=
if [ -z "$diagnostics" ]; then
	rm -r $SCRATCHDIR/* 2> /dev/null
fi
}
#######################
# define splashA function
#######################
splashA ( ) {
printf "\033c"
echo "Substring (c) 2016-18 Cardiff University - Licensed under the EUPL 1.1"
echo
echo
echo
echo
echo "          SUBSTRING"
echo "          substring reduction and frequency consolidation tool"
echo "          version $version"
echo 
echo 
echo
echo "          Please drop an n-gram list in XML format into this window."
echo
read -p '         > ' inxml  < /dev/tty
if [ -z "$inxml" ]; then
	echo "no file was provided. Returning to main menu."
	sleep 1
	splash0
	return
fi
# get rid of any single quotation marks that might have attached
export inxml="$(sed "s/'//g" <<<"$inxml")"
# check if filename ends in xml
if [ "$(basename $inxml | grep '\.xml$')" ]; then
	# change to directory of input file
	cd "$(dirname $inxml)"
	ext="xml"
	outtxt="$(sed "s/\.xml$//" <<< $inxml)"
	add_to_name $(basename $outtxt-consolidated.txt)
	printf "\033c"
	substring-A.py --to NGP $inxml > $output_filename
	echo "Frequency-consolidated list saved as $(dirname $inxml)/$output_filename."
	### ask if dir should be opened
	echo
	echo "          Would you like to open the output directory?"
	echo "          (Y) yes       (N) no"
	echo
	read -p '          > ' a  < /dev/tty
	if [ "$a" == "y" ] || [ "$a" == "Y" ] || [ -z "$a" ]; then
		if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
			cygstart $(dirname "$inxml")
		elif [ "$(grep 'Darwin' <<< $platform)" ]; then
			open $(dirname "$inxml")
		else
			xdg-open $(dirname "$inxml")
		fi
	fi
	splash0
else
	echo "$(basename $inxml) is not an XML file."
	sleep 1
	splash0
fi
}
#######################
# define splash function
#######################
splash ( ) {
printf "\033c"
echo "Substring (c) 2016-18 Cardiff University - Licensed under the EUPL 1.1"
echo
echo
echo
echo
echo "          SUBSTRING"
echo "          substring reduction and frequency consolidation tool"
echo "          version $version"
echo 
echo 
echo
echo "          Please drop a folder with n-gram lists into this window."
echo
read -p '         > ' indir  < /dev/tty
# get rid of any single quotation marks that might have attached
export indir="$(sed "s/'//g" <<<"$indir")"
# check if anything was entered
indir_check
}
###########
# define indir_check function
###########
indir_check ( ) {
	if [ -z "$indir" ]; then
		echo "A folder with n-gram lists must be provided. Please drop the folder into this window."
		read -p '           ' indir  < /dev/tty
		if [ -z "$indir" ]; then
			echo "No data provided." >&2; sleep 2
			return
		fi
	fi
	# check if the path provided was to a directory
	if [ -d "$indir" ]; then
		:
	else
		echo "A folder with n-gram lists must be provided. Please drop the folder into this window."
		read -p '           ' indir  < /dev/tty
		if [ -d "$indir" ]; then
			:
		else
			echo "No data of the correct type was provided." >&2; sleep 2
			return
		fi
	fi
	# check if anything is inside the directory
	if [ "$(ls "$indir" | wc -l | sed 's/ //g')" -gt 0 ]; then
		:
	else
		echo "$indir is empty."
		echo "A folder with n-gram lists in it must be provided. Please drop the folder into this window."
		read -p '           ' indir  < /dev/tty
		if [ -n "$indir" ] && [ "$(ls "$indir" | wc -l | sed 's/ //g')" -gt 0 ]; then
			:
		else
			echo "No data of the correct type was provided." >&2; sleep 2
			return
		fi
	fi
}
#######################
# define assess function
#######################
assess ( ) {
echo
echo "          Please drop a consolidated list into this window."
echo
read -p '         > ' inlist  < /dev/tty
export inlist
# get rid of any single quotation marks that might have attached
export inlist="$(sed "s/'//g" <<<"$inlist")"
if [ -e "$inlist" ]; then
	# check if already TP-filtered
	if [ "$(grep 'tpfltd' <<< "$inlist")" ]; then
		new_inlist="$inlist"
		onlylooking=true
		TPtesting
	else
		echo "          Please type in a sample size for the assessment."
		echo "          (e.g. 100)"
		echo
		read -p '         > ' samplesize  < /dev/tty
		if [ $samplesize -gt 1 ]; then
			export samplesize
			remove_windows_returns "$inlist" > "$inlist."
			mv "$inlist." "$inlist"
			random_lines.sh -sn $samplesize "$inlist" > "$inlist"tmp
			new_inlist="$inlist"tmp
			TPtesting
		else
			echo "Unexpected input. Please enter sample size."
			read -p '         > ' samplesize  < /dev/tty
			if [ $samplesize -gt 1 ]; then
				export samplesize
			else
				export samplesize=20
				echo "sample size 20 was used."
			fi
			random_lines.sh -n $samplesize "$inlist" > "$inlist"tmp
			new_inlist="$inlist"tmp
			TPtesting
		fi
	fi
else
	echo "$inlist does not exist!"; sleep 2
	exit 1
fi
}
#######################
# define TPtesting function
#######################
TPtesting ( ) {
	TP-filter.sh "$new_inlist"
	# remove unrated sample unless only looking
	if [ "$onlylooking" ]; then
		:
	else
		rm "$new_inlist"
	fi
	# tidy up the name
	tmpext="$(egrep -o '\.[[:alnum:]]+$' <<<"$new_inlist")"
	new="$(sed "s/$tmpext//" <<< "$new_inlist").tpfltd"
	newext=$(sed 's/tmp$//'<<<"$tmpext")
	add_to_name $new$newext
	mv "$new$ext"tmp $output_filename
	echo
	echo "          Your assessed sample is found here:"
	echo "          $output_filename"
	### ask if dir should be opened
	echo
	echo "          Would you like to open the output directory?"
	echo "          (Y) yes       (N) no"
	echo
	read -p '          > ' a  < /dev/tty
	if [ "$a" == "y" ] || [ "$a" == "Y" ] || [ -z "$a" ]; then
		if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
			cygstart $(dirname "$inlist")
		elif [ "$(grep 'Darwin' <<< $platform)" ]; then
			open $(dirname "$inlist")
		else
			xdg-open $(dirname "$inlist")
		fi
	fi
}
#############################################
# define rename_to_tmp function
# this function renames all the lists given as arguments into the N.lst format
# and save them in $SCRATCHDIR
#############################################
rename_to_tmp ( ) {
# RENAME LISTS
# create a copy of each argument list in the simple N.lst format
for file in $@; do
	if [ -d "$file" ]; then
		return
	fi
	# eliminate total n-gram count if present
	if [ "$(head -1 "$file" | grep '^[[:digit:]]*.$')" ] || [ "$(head -1 "$file" | grep '^[[:digit:]]*$')" ]; then
		mv "$file" "$file.."
		sed 1d "$file.." > "$file"
		restore=true
		if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
			:
		else
			remove_windows_returns "$file" > "$file." 2> /dev/null
			mv "$file." "$file"
		fi
	fi
	# extract n of n-gram list
	nsize=$(head -1 "$file" |  tr -dc "$short_sep" | wc -c | sed 's/ //'g)
	# this counts binary separator characters as two, so needs adjusting
	if [ "$short_sep" == "·" ]; then
		nsize=$(( nsize / 2 ))
	fi
	# if no n-size was detected, set $nsize to 0
	if [ -z "$nsize" ]; then
		nsize=0
	fi
	#echo $nsize
	# create a copy named N.lst if N is more than 0
	if [ $nsize -gt 0 ]; then
		if [ "$verbose" ]; then
			echo $nsize.lst
		fi
		# create variable with all list names
		all_cut_lists+=" $nsize.lst "
		# replace special characters to avoid problems later
		# and replace tab with dot (.)
		sed -e 's/\-/HYPH/g' -e 's/\./DOT/g' -e 's=/=SLASH=g' -e "s/'/APO/g" -e 's/\`//g' -e 's/(/LBRACKET/g' -e 's/)/RBRACKET/g' -e 's/\*/ASTERISK/g' -e 's/+/PLUS/g' "$file" > $SCRATCHDIR/$nsize.lst
		# count the number of lists copied
		(( number_of_lists += 1 ))		
	# if it's not an empty list
	elif [ -s "$file" ]; then # if file has size greater than zero
		echo "ERROR: format of $file not recognised" >&2; sleep 2
		exit 1
	# if it's an empty list, do nothing
	else
		:
	fi
	# restore original list of total n-grams were cut out
	if [ "$restore" ]; then
		mv "$file.." "$file"
	fi
done
}
#############################################
# define cut_routine function
# this function enforces minimum frequencies in n-gram lists
#############################################
cut_routine ( ) {
echo "          Please enter the minimum n-gram frequency you wish to consider."
echo "          (values between 3 and 101 are acceptable)"
echo
read -p '         > ' cut_freq  < /dev/tty
if [ -z "$cut_freq" ]; then
	echo "You have not entered a value, please enter a number between 3 and 100."
	read -p '         > ' cut_freq  < /dev/tty
	if [ -z "$cut_freq" ]; then
		echo "ERROR: no minimum frequency provided."; sleep 2
		exit 1
	fi
fi
if [ $cut_freq -lt 3 ]; then
	echo "WARNING: a minimum frequency of less than 3 was chosen."
	echo "Frequency consolidation is likely to fail with minimum frequencies as low as this."
	echo
	echo "         Continue anyway?"
	echo 
	echo "         (Y) yes       (N) no"
	read -p '         > ' a  < /dev/tty
	if [ "$a" == "Y" ] || [ "$a" == "y" ]; then
		:
	else
		return
	fi
fi
# organise SCRATCHDIR
mkdir $SCRATCHDIR/uncut
mv $SCRATCHDIR/* $SCRATCHDIR/uncut 2> /dev/null
# now run cutoff.sh
for list in $(ls $SCRATCHDIR/uncut); do
	cutoff.sh -if "$cut_freq" $SCRATCHDIR/uncut/$list
done
mkdir $SCRATCHDIR/cut
mv $SCRATCHDIR/uncut/*.cut.* $SCRATCHDIR/cut
}
process_substring_reduction ( ) {
# check lists are right
echo
echo "          Please confirm that ALL of the following are to be consolidated with each other:"
echo "$(ls "$indir" | sed 's/^/                 /g')"
echo
echo "          (C) confirm       (N) choose new folder       (X) exit"
read -p '         > ' conf  < /dev/tty
case $conf in
	C|c)	echo "          confirmed."
	;;
	N|n)	echo "          Please drop a folder with n-gram lists into this window."
	echo
	read -p '         > ' indir  < /dev/tty
	;;
	X|x)	exit 0
	;;
	*)	echo "          Not a valid choice. Please drop a folder with n-gram lists into this window."
	read -p '         > ' indir  < /dev/tty
esac
indir_check
# check if input lists exist, check separator used and move to SCRATCHDIR
for list in $(ls "$indir"); do
	if [ -e "$indir/$list" ]; then
		# check separator for current list
		if [ "$(head -1 "$indir/$list" | grep '<>')" ]; then
			separator='<>'
			short_sep='<'
		elif [ "$(head -1 "$indir/$list" | grep '·')" ]; then
			separator="·"
			short_sep="·"
		elif [ "$(head -2 "$indir/$list" | grep '<>')" ]; then
				separator='<>'
				short_sep='<'
				eliminate_first_line=true
		elif [ "$(head -2 "$indir/$list" | grep '·')" ]; then
				separator="·"
				short_sep="·"
				eliminate_first_line=true
		else
			echo "unknown separator in $(head -1 "$indir/$list") of file $list" >&2; sleep 2
			exit 1
		fi
	else
		echo "$list was not found"; sleep 2
		exit 1
	fi
done
# move lists to SCRATCHDIR
cd "$indir"
rename_to_tmp $(ls)
cd - > /dev/null
# check if uncut lists are consecutive with regard to n-size
echo
echo "checking lists..."
number_of_lists=$(ls $SCRATCHDIR | wc -w | sed 's/ //g'); echo "number of lists: $number_of_lists"
shortest_list=$(ls $SCRATCHDIR | head -1 | sed 's/.lst//g'); echo "shortest list: $shortest_list-grams"
longest_list=$(( $shortest_list + $number_of_lists - 1 )); echo -n "longest list should be: $longest_list-grams..."
i="$shortest_list"
while [ $i -le $longest_list ]; do
	if [ -e $SCRATCHDIR/$i.lst ]; then
		# remove Windows returns if necessary
		if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
			remove_windows_returns $SCRATCHDIR/$i.lst > $SCRATCHDIR/$i.lst. 2> /dev/null
			mv $SCRATCHDIR/$i.lst. $SCRATCHDIR/$i.lst
		fi
		(( i += 1 ))
	else
		echo " " >&2
		echo "ERROR: lists do not appear to have consecutive n-gram lengths." >&2
		echo "Only lists that are consecutive in terms of n-gram lengths can be processed." 
		sleep 2
		exit 1
	fi
done
echo "OK"
echo
########## cut
cut_routine
# check if anything is left after enforcing minimum frequency
for file in $(ls $SCRATCHDIR/cut); do
	if [ -s "$SCRATCHDIR/cut/$file" ]; then
		(( file_with_content += 1 ))
	fi
done
if [ $file_with_content -lt 2 ]; then
	echo "ERROR: not enough data left after enforcement of minimum frequency."
	echo "There need to be at least two n-gram lists with content to consolidate."
	echo "Try using a lower minimum frequency."
	sleep 2
	exit 1
fi
########## substring reduction
original_dir=$(pwd)
cd $SCRATCHDIR
if [ "$diagnostics" ]; then
	if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
		cygstart $SCRATCHDIR
	elif [ "$(grep 'Darwin' <<< $platform)" ]; then
		open $SCRATCHDIR
	else
		xdg-open $SCRATCHDIR
	fi
fi
echo
echo "starting substring reduction and frequency consolidation..."
echo
substring-B.sh -dv $(for list in 4 5 6 7 8 9; do if [ -e uncut/$list.lst ]; then echo -n "-u uncut/$list.lst ";fi;done) $(for list in $(ls cut); do echo -n "cut/$list ";done) || exit 1
mv neg_freq.lst "$indir/neg_freq.txt" 2> /dev/null
# ascertain filename of consolidated list
filename=$(ls *substrd)
########## length-adjustment
echo
echo "          Would you like to perform n-gram length adjustment? (recommended)"
echo "          (Y) yes       (N) no"
echo
read -p '         > ' next  < /dev/tty
if [ "$next" == "y" ] || [ "$next" == "Y" ]; then
	echo "processing..."
	length-adjust.sh -rc "$cut_freq" *.substrd
	if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
		add_windows_returns $(ls correction-log.*) > "$indir/$(ls correction-log.*)"
	else
		mv correction-log.* "$indir"
	fi
fi
next=
######### second cutoff
cutoff.sh -if "$cut_freq" $filename
# delete uncut list
rm $filename
# add generic txt extension
mv *substrd $(ls *substrd).txt
######### filtering
echo
echo "          Would you like to apply the standard lexico-structural filter for English? (recommended)"
echo "          (Y) yes       (N) no"
echo
read -p '         > ' next  < /dev/tty
case $next in
	Y|y)	echo "processing..."
		en-filter.sh -d *.substrd.txt
		filter=true
		#removing previous stage file
		rm *.substrd.txt
	;;
	*)	:
		#echo "          Drop a custom-made filter file into this window or press ENTER to skip."
		#read -p '         > ' filter  < /dev/tty
		#if [ "$filter" ]; then
		#	:
		#fi
	;;
esac
next=
######### consolidation if not already consolidated with filter
if [ -z "$filter" ]; then
	echo
	echo "Consolidating output file..."
	echo
	consolidate.sh -rv *.txt
fi
######### moving files into place and tidying up
# producing nice name for output file and adding windows returns if necessary
add_to_name "$indir/$(ls *.txt)"
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	add_windows_returns $(ls *.txt) > "$output_filename"
else
	mv *.txt "$output_filename"
	echo "consolidated list placed in $output_filename"
fi
echo "          Task complete. Your output files are found here:"
echo "          $indir"
### ask if dir should be opened
echo
echo "          Would you like to open the output directory?"
echo "          (Y) yes       (N) no"
echo
read -p '         > ' a  < /dev/tty
if [ "$a" == "y" ] || [ "$a" == "Y" ] || [ -z "$a" ]; then
	if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
		cygstart "$indir"
	elif [ "$(grep 'Darwin' <<< $platform)" ]; then
		open "$indir"
	else
		xdg-open "$indir"
	fi
fi
}
#################################end define functions########################
# set some standard variables
diagnostic=0
# check what platform we're under
platform=$(uname -s)
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	CYGWIN=true
elif [ "$(grep 'Darwin' <<< $platform)" ]; then
	extended="-E"
	DARWIN=true
else
	LINUX=true
fi
# analyse options
while getopts adhV opt
do
	case $opt	in
	a) auxiliary=true
		;;
	d)	diagnostics=true
		;;
	h)	help
		exit 0
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "licensed under the EUPL V.1.1"
		echo "written by Andreas Buerki"
		exit 0
		;;
	3)	force_bash3=TRUE
		;;
	esac
done
shift $((OPTIND -1))
# create scratch directory where temp files can be moved about
SCRATCHDIR=$(mktemp -dt substringXXX)
# if mktemp fails, use a different method to create the scratchdir
if [ "$SCRATCHDIR" == "" ] ; then
	mkdir ${TMPDIR-/tmp/}substring.$$
	SCRATCHDIR=${TMPDIR-/tmp/}substring.$$
fi
# show appropriate splash screen
if [ "$auxiliary" ]; then
	splash
else
	splash0
fi