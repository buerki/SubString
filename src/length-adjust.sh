#!/bin/bash -
##############################################################################
# length-adjust.sh 
copyright="(c) 2016 Cardiff University, 2014 Andreas Buerki"
# licensed under the EUPL V.1.1.
version='0.9.9'
####
# DESCRRIPTION: this script takes substringreduced n-gram lists and checks for
#				strings that have an unusually higher number of variants off
#				their base. It then offers various correction procedures.
#				The script has an automatic mode and a manual mode (-m).
# SYNOPSIS:     length-adjust.sh -c 'REGEX' [OPTIONS] FILE[S]
# OPTIONS:      see length-adjust.sh -h
#
# DEPENDENCIES: this script makes use of consolidate.sh if installed
##############################################################################
# History
# date			v.		change
# 2016-01-09	0.9.9	made script silent except if -v active, adjusted (c)
# 2014-09-18	0.9.6	first release version

### define functions
#######################
# define help function
#######################
help ( ) {
	echo "
DESCRRIPTION: this script takes substringreduced n-gram lists and checks for
              strings that have an unusually higher number of variants off
              their base. It then offers various correction procedures.
SYNOPSIS:     $(basename $0) -c '([REGEX])' -[OPTIONS] FILE[S]
OPTIONS:  -[2-9] these are used to set the activation threshold (i.e. the
                 number of strings that need to be found before a correction
                 is made. The default, without invoking the option is 6.
          -c N minimum frequency in plain numbers (see also -C)
          -C '([REGEX])' | '([REGEX]) ([REGEX]) ([REGEX]) ([REGEX])'
                cutoff regex (frequency) needs to be provided with this
                mandatory option; if 1 REGEX is given,
                it is applied to n-grams of all sizes, if several REGEXES
                are given, the first will be applied to bigrams, the next
                to trigrams and so on, so REGEXES should be supplied for
                all n-gram sizes in the list to be corrected.
          -b N  set maximum base frequency for length adjustments
                the default value is 1000
          -l    only adjust below-cutoff n-grams if new freq > cutoff
                (this only works if a single regex is provided)
          -o    only adjust lengths of below-cutoff sequences
          -p SEP defined separator used in n-gram lists if not either ·,<>,_  
          -v    verbose
          -V    display version and license information
          -r    replace input file with output file, keep no backup
          -s '0.x' set minimum ratio for automatic correction between
          	    frequency of base sequence and associated sequences:
          	    For a 50% ratio (base sequence must contribute at least
          	    50% to total frequency of corrected sequence), enter '0.5'
          	    default value is '0.333'
          	    
NOTE1:     Changed n-grams are logged in the file correction-log.txt
NOTE2:     the cutoff-regex that needs to be provided with the -c option
           must be the one(s) used in processing the source list. It is
           used to correct n-grams with below-cutoff frequency 
           by checking for the existence and frequency of substrings of the
           below cutoff n-gram. If more than one substring is found, the
           one with a higher frequency will be used to adjust the string
           to. In any case the string will be left as is if correction
           would result in a frequency which is still below cutoff
NOTE3:     Document counts, if present in input lists, are handled such that
		   the document count of the original shorter n-gram is used for the
		   length-adjusted n-gram. This is a conservative estimate likely to
		   be very close to the actual figure.
"
}
#######################
# define usage function
#######################
usage ( ) {
	echo "
Usage:    $(basename $0) -[2-9] FILE
Example:  $(basename $0) -4 80s-90s-2-7.cut.([0-9]|[1][0-2]).1.substrd
OPTIONS:  for options see help (-h option)
"
}
#######################
# define getch function (reads the first character input from the keyboard)
#######################
getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}
#######################
# define regex_maker function
#######################
regex_maker ( ) {
#deduct 1 to get the cut-frequency
(( cut_freq -= 1 ))
# work out the correct regex for cutting
num_of_digits=$(( $(echo $cut_freq | wc -c) - 1 ))
if [ $num_of_digits -eq 1 ]; then
	export cut_regex="[0-$cut_freq]|$cut_freq"
elif [ $num_of_digits -eq 2 ]; then
	first_digit=$(sed 's/\(^[[:digit:]]\).*/\1/g' <<< $cut_freq)
	first_dm1=$(( $first_digit - 1 ))
	second_digit=$(sed 's/^.\([[:digit:]]\).*/\1/g' <<< $cut_freq)
	export cut_regex="[0-9]|[0-$first_dm1][0-9]|$first_digit[0-$second_digit]|$cut_freq"
elif [ $num_of_digits -eq 3 ]; then
	export cut_regex="[1-9]|[1-8][0-9]|9[0-9]|100"
	if [ $cut_freq -gt 100 ]; then
		echo "The value entered is greater than 101. The value 101 will be used instead."
	fi 
fi
}
##########################
# define eroutine function (that is the below-cutoff correction routine)
##########################
# description of the steps carried out by this function (in overview):
# 1) picking out lines in the input list that feature below cutoff freqs
# 2) for each of those lines, shorten by 1 element on the right edge and see if there are any identical lines in the input list with which it could be combined. Note the combined frequency
# 3) do the same thing for shorting by 1 element on the left edge
# 4) see if right or left shortening results in higher combined freq and go with that (if same freq, go with left shortening)
# 5) delete original line and line with which is will be combined from list
# 6) write new line with combined freq to the list
eroutine ( ) {
# reset progress variable
progress=0
# set noshortstring variable
noshortstring=0
# log operations
echo "Below cutoff correction(s):" >> "$corr_log_name"
#inform user
if [ $num_of_regexes -gt 1 ]; then
	echo "$num_of_regexes regex patterns provided:"
	echo "${regex[0]} for 2-grams"
	echo "${regex[1]} for 3-grams"
	if [ $num_of_regexes -gt 2 ]; then
		echo "${regex[2]} for 4-grams"
	fi
	if [ $num_of_regexes -gt 3 ]; then
		echo "${regex[3]} for 5-grams"
	fi
	if [ $num_of_regexes -gt 4 ]; then
		echo "${regex[4]} for 6-grams"
	fi
	if [ $num_of_regexes -gt 5 ]; then
		echo "${regex[5]} for 7-grams"
	fi
	if [ $num_of_regexes -gt 6 ]; then
		echo "${regex[6]} for 8-grams"
	fi
fi
# if only one regex was provided, we can use the short procedure
if [ $num_of_regexes -eq 1 ]; then
	# we set the regex provided as the relevant regex for processing below
	relevant_regex=$regex
	# pick out below-cutoff n-grams and look at each of them
	for line in $(echo "$input_list" | egrep "$separator\.$relevant_regex($|\.)"); do
		# if it's a bigram, we continue to the next iteration
		nsize=$(echo "$line" | tr -dc "$short_sep" | wc -c | sed 's/ //'g)
		# this counts binary separator characters as two, so needs adjusting
		if [ "$short_sep" == "·" ]; then
			nsize=$(( nsize / 2 ))
		fi
		if [ "$nsize" -gt "2" ]; then
			lines_to_be_adjusted+="$line "
		fi
	done
# if several regexes were provided
else
	# changes this to pick out lines of appropriate size and below cutoff freq
	# and put them into the $lines_to_be_adjusted variable
	# look at the lines, line by line
	for line in $(sed 's/	/./g' $file) ; do
		# we first check n-size, 
		# and then check if the freq in the line matches the appropriate regex
		# check n-size
		nsize=$(echo "$line" | tr -dc "$short_sep" | wc -c | sed 's/ //'g)
		# this counts binary separator characters as two, so needs adjusting
		if [ "$short_sep" == "·" ]; then
			nsize=$(( nsize / 2 ))
		fi
		case $nsize in
			2)	continue
				;;
			3)	if [ -z "$(echo "$line" | egrep "$separator\.${regex[1]}($|\.)")" ]; then
					continue
				else
					lines_to_be_adjusted+="$line "
				fi
				;;
			4)	if [ -z "$(echo "$line" | egrep "$separator\.${regex[2]}($|\.)")" ]; then
					continue
				else
					lines_to_be_adjusted+="$line "
				fi
				;;
			5)	if [ $num_of_regexes -gt 2 ]; then
					if [ -z "$(echo "$line" | egrep "$separator\.${regex[3]}($|\.)")" ]; then
						continue
					else
						lines_to_be_adjusted+="$line "
					fi
				else
					echo "   no regex matching $nsize-grams!" >&2
					exit 1
				fi
				;;
			6)	if [ $num_of_regexes -gt 3 ]; then
					if [ -z "$(echo "$line" | egrep "$separator\.${regex[4]}($|\.)")" ]; then
						continue
					else
						lines_to_be_adjusted+="$line "
					fi
				else
					echo "   no regex matching $nsize-grams!!" >&2
					exit 1
				fi
				;;
			7)	if [ $num_of_regexes -gt 4 ]; then
					if [ -z "$(echo "$line" | egrep "$separator\.${regex[5]}($|\.)")" ]; then
						continue
					else
						lines_to_be_adjusted+="$line "
					fi
				else
					echo "   no regex matching $nsize-grams!!" >&2
					exit 1
				fi
				;;
			8)	if [ $num_of_regexes -gt 5 ]; then
					if [ -z "$(echo "$line" | egrep "$separator\.${regex[6]}\.")" ]; then
						continue
					else
						lines_to_be_adjusted+="$line "
					fi
				else
					echo "   no regex matching $nsize-grams!" >&2
					exit 1
				fi
				;;
			*)	echo "n-gram of size $nsize found: variable regexes with the -c option are implemented for n-grams up to length 8 only" >&2
			exit 1
				;;
		esac
	done
fi
# inform user
if [ "$verbose" == true ]; then
	echo "correcting $(echo "$lines_to_be_adjusted" | tr -dc ' ' | wc -c | sed 's/ //'g) n-grams below cutoff frequency..."
fi
# check if running under MacOS and if so use more efficient variant
if [ $(uname -s) == Darwin ]; then
	command1='cut -d "$short_sep" -f 1-$(( $nsize - 1 ))'
	command2='echo "$(echo $line | cut -d "$short_sep" -f 2-$nsize)$short_sep"'
else
	command1='egrep -o "([^$short_sep]*$short_sep){$(( $nsize - 1 ))}" | sed "s/$short_sep$//g"'
	command2='echo $line | sed "s/^[^$short_sep]*·\([^\.]*\).*/\1/"'
fi
for line in $lines_to_be_adjusted; do
	(( progress += 1 ))	
	# establish nsize
	nsize=$(echo "$line" | tr -dc "$short_sep" | wc -c | sed 's/ //'g)
	# this counts binary separator characters as two, so needs adjusting
	if [ "$short_sep" == "·" ]; then
		nsize=$(( nsize / 2 ))
	fi
	# put freq information into variable freqinfo
	freqinfo=$(echo "$line" | cut -d '.' -f 2-10)
	# check if substrings exist and compare their frequencies
	# checking for right-cut:
	# cut one word off the right side of the n-gram and put result in rightcutline variable
	rightcutline="$(echo $line | eval $command1)"
	# different results if we were to say "$(echo $line | eval $command1)$separator"
	# put a line corresponding to rightcutline (if such exists) in a variable
	existing_right="$(echo "$input_list" | egrep "^$rightcutline$separator\.")"
	# if rightcutline exists in the list
	if [ -n "$existing_right" ]; then	
		# put combined frequency in variable combination_freq_right
		combination_freq_right="$(( $(echo $existing_right | cut -d '.' -f 2) + $(echo "$freqinfo" | cut -d '.' -f 1) ))"
		# if -o option active and it's still not above the cutoff
		if [ "$legacy" == true ] && [ -z "$(echo $combination_freq_right | egrep -v "^$relevant_regex$")" ]; then
		# reset to 0
			combination_freq_right=0
		fi
	else
		combination_freq_right=0
	fi
	# checking for left-cut:
	# cut one word off the left side of the n-gram and put result in leftcutline variable
	leftcutline=$(eval $command2)
	# put a line corresponding to leftcutline (if such exists) in the variable existing_left
	existing_left="$(echo "$input_list" | egrep "^$leftcutline\.")"
	# if leftcutline exists in the list
	if [ -n "$existing_left" ]; then
		# put combined frequency in variable combination_freq_left
		combination_freq_left="$(( $(echo $existing_left | cut -d '.' -f 2) + $(echo "$freqinfo" | cut -d '.' -f 1) ))"
		# if -o option active and it's still not above the cutoff
		if [ "$legacy" == true ] && [ -z "$(echo $combination_freq_left | egrep -v "^$relevant_regex$")" ]; then
		# reset to 0
			combination_freq_left=0
		fi
	else
		combination_freq_left=0
	fi
	# check if any combinations are above 0
	if [ "$combination_freq_right" -gt 0 ] || [ "$combination_freq_left" -gt 0 ]; then	
		# compare projected combined frequencies and write appropriate value to
		# variables
		# if left combination is better or equal
		if [ $combination_freq_left -ge $combination_freq_right ]; then
			cutline="$leftcutline"
			combination_freq=$combination_freq_left
			existing=$existing_left
		else
			cutline="$rightcutline$separator" # line needs a separator!
			combination_freq=$combination_freq_right
			existing=$existing_right
		fi
		# delete old lines, both the shortened line and the original short line,
		# and write new line to list
		if [ "$doc" == true ]; then
			input_list="$cutline.$combination_freq.$(echo "$existing" | cut -d '.' -f 3-9)
$(echo "$input_list" | egrep -v "^$line|^$existing")"
			# there is a line break in this, of course.
			# log operations
			echo "$line + $existing -->> $cutline	$combination_freq	$(echo "$existing" | cut -d '.' -f 3-9))" | sed 's/\./	/g' >> "$corr_log_name"
		else
			input_list="$cutline.$combination_freq
$(echo "$input_list" | egrep -v "^$line|^$existing")"
			# there is a line break in this, of course.
			# log operations
			echo "$line + $existing -->> $cutline	$combination_freq" | sed 's/\./	/g' >> "$corr_log_name"
		fi
	else
		(( noshortstring += 1 ))
	fi
done
if [ "$verbose" == true ]; then
	echo "$noshortstring n-grams had no substrings to consolidate with"
fi
# check if we've maxed out
if [ $progress -eq $noshortstring ]; then
	maxed_out=true
	# that is, none of the lines to be adjusted have any shorter strings
	# they could be combined with
	export maxed_out
fi
# write processed list to file
# echo "$input_list" | sed -e 's/\./	/g' > $file
# clear memory
lines_to_be_adjusted=
}
#######################
# define add_to_name function
#######################
# this function checks if a file name (given as argument) exists and
# if so appends a number to the end so as to avoid overwriting existing
# files of the name as in the argument or any with the name of the argument
# plus an incremented count appended.
####
add_to_name ( ) {
count=
if [ "$(egrep '.csv$' <<<"$1")" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed 's/\.csv//' <<< "$1")"
		while [ -e "$new$add$count.csv" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed 's/\.csv//' <<< "$1")$add$count.csv"
elif [ "$(egrep '.dat$' <<< "$1")" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed 's/\.dat//' <<< "$1")"
		while [ -e "$new$add$count.dat" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed 's/\.dat//' <<< "$1")$add$count.dat"
elif [ "$(grep '.txt' <<< "$1")" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed 's/\.txt//' <<< "$1")"
		while [ -e "$new$add$count.txt" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed 's/\.txt//' <<< "$1")$add$count.txt"
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
############################### END DEFINING FUNCTIONS ###############
# set activation threshold to default value
activationat=6
# set basetop to default value
basetop=1000
# set min_ratio to default value
min_ratio=0.333
# analyse options
while getopts b:hC:c:d23456789lop:rs:vV opt
do
	case $opt	in
	b)	basetop=$OPTARG
		;;
	h)	help
		exit 0
		;;
	c)	cut_freq=$OPTARG
		regex_maker
		regex="($cut_regex)"
		;;
	C)	regex=$OPTARG
		;;
	d)	diagnostic=true
		;;
	l)	legacy=true
		;;
	[2-9])	activationat=$opt
		export activationat
		;;
	p)	separator="$OPTARG"
		short_sep="$(echo "$OPTARG" | cut -c 1)"
		;;
	o)	only_below_cutoff=true
		;;
	v)	verbose=true
		;;
	r)	replace=true
		;;
	s)	min_ratio=$OPTARG
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "Copyright $copyright"
		echo "licensed under the EUPL V.1.1"
		echo "written by Andreas Buerki"
		exit 0
		;;
	esac
done
shift $((OPTIND -1))
# check if at least one argument was supplied
if [ $# -lt 1 ]; then
	echo "Error: please supply at least one list to correct" >&2
	exit 1
fi
# check if input lists exist and check separator used
for list; do
	if [ -s "$list" ]; then
		# check separator for current list
		if [ -n "$separator" ]; then
			if [ -n "$(head -1 "$list" | grep "$separator")" ]; then
				:
			# if the list is not empty, produce error
			elif [ -s "$list" ]; then
				echo "separator $separator not found in $(head -1 "$list") of file $list" >&2
				exit 1
			fi
		elif [ "$(head -3 "$list" | grep -c '<>')" -ge 3 ]; then
			separator='<>'
			short_sep='>'
		elif [ "$(head -3 "$list" | grep -c '·')" -ge 3 ]; then
			separator="·"
			short_sep="·"
		elif [ "$(head -3 "$list" | grep -c '_')" -ge 3 ]; then
			separator="_"
			short_sep="_"
		else
			echo "unknown separator in $(head -1 "$list") of file $list" >&2
			exit 1
		fi		
		# check list format
		if [ $(head -1 "$list" | tr -dc '	' | wc -c | sed 's/ //'g) -eq 1 ] ; then
			if [ "$verbose" == true ]; then
				echo "1tab recognised, no document counts"
			fi
		elif [ $(head -1 "$list" | tr -dc '	' | wc -c | sed 's/ //'g) -eq 2 ] ; then
			if [ "$verbose" == true ]; then
				echo "2tabs recognised, document counts included"
			fi
			doc=true
		else
			echo "list format not recognised: $(head -1 $1)" >&2
			exit 1
		fi
	else
		echo "$list does not exist or is empty" >&2
		exit 1
	fi
done
if [ "$verbose" == true ]; then
	echo "the following files will be processed"
	echo "$(echo "$@" | sed 's/ /\
/g')"
	echo "separator: $separator"
fi
# check if regex was supplied
if [ -z "$regex" ]; then
	echo "ERROR: no cutoff regex was supplied." >&2
	echo "Please supply the cutoff regex which was used in creating the list to be corrected" >&2
	echo "use -c 'REGEX' to provide the REGEX" >&2
	exit 1
elif [[ "$regex" != *'(['* ]]; then
	echo "ERROR: -c option (-c $regex ) does not appear to be of the proper format" >&2
	exit 1
else
	# check if it's a single regex or several
	if [ "$(echo $regex | tr -dc ' ' | wc -c | sed 's/ //'g)" -le 1 ]; then
		# it's only one, so we just take a note of that
		num_of_regexes=1
		if [ "$verbose" ]; then
			echo "regex provided: $regex"
		fi
	else
		# it's more than one, so we convert the variable into an array
		regex=( $regex )
		# and check how many elements it contains
		num_of_regexes=${#regex[@]}
		echo "$num_of_regexes regex patterns provided: ${regex[@]}"
	fi
fi
# create scratch directories where temp files can be moved about
SCRATCHDIR=$(mktemp -dt correctionXXX) 
# if mktemp fails, use a different method to create the SCRATCHDIR
if [ "$SCRATCHDIR" == "" ] ; then
	ID1=$$
	mkdir ${TMPDIR-/tmp/}correction.1$ID1
	SCRATCHDIR=${TMPDIR-/tmp/}correction.1$ID1
fi
####################### START LOOP OVER INPUT DOCS ###############
# copy files to SCRATCHDIR and create variable for original files
# and replace some special characters in the
# lists that will cause trouble with grep regexes
for argument_file; do
# we keep this for-loop open until the end, so all argument files
# will be processed
# (temporarily) replace problematic characters and put file in scratch dir
sed -e 's/\-/HYPH/g' -e 's/\./DOT/g' -e 's=/=SLASH=g' -e "s/'/APO/g" -e 's/\`//g' -e 's/(/LBRACKET/g' -e 's/)/RBRACKET/g' -e 's/\*/AST/g' -e 's/+/PLUS/g' "$argument_file" > $SCRATCHDIR/$(basename "$argument_file")
file="$SCRATCHDIR/$(basename "$argument_file")"
original_file="$argument_file"
# for prevention of problems, first consolidate any duplicate lines
if [ "$verbose" == true ]; then
	echo "consolidating..."
	if [ "$doc" == true ]; then
		consolidate.sh -vdr $file 2> /dev/null
	else
		consolidate.sh -vr $file 2> /dev/null
	fi
else
	if [ "$doc" == true ]; then
		consolidate.sh -dr $file 2> /dev/null
	else
		consolidate.sh -r $file 2> /dev/null
	fi
fi
# we'll need frequent access to the source list, so we are putting it into one big variable. freqs are separated by a dot (.) and line breaks are preserved as long as the variable is "quoted" when used
input_list="$(sed 's/	/./g' $file)"
# in bash 4, we could put it into an associative array (a hash), but for compatibility with older versions, we'll stick with a big variable for now
######## taking care of the log file
# create name for log file
outdir=$(dirname "$argument_file")
add_to_name "$outdir"/correction-log.txt; corr_log_name="$output_filename"
# write an identifier line to the log
echo "# correction-log for $argument_file - $(date)
# min.ratio: $min_ratio - activation at $activationat
# basetop: $basetop" >> "$corr_log_name"
######## correction of below-cutoff n-grams
# this tries to correct n-grams with below-cutoff frequency automatically
# it does this by checking for the existence and frequency of substrings of the
# below cutoff n-gram. If more than one substring is found, the one with
# a higher frequency will be used to adjust the string to.
if [ -n "$regex" ]; then
	# write to log file
	if [ $num_of_regexes -eq 1 ]; then
		echo "# regex: $regex" >> "$corr_log_name"
	else
		echo "# regexes: ${regex[*]}" >> "$corr_log_name"
	fi
	echo "-----------------------------------------------------------" >> "$corr_log_name"
	# run eroutine
	eroutine
	echo "----------------------------------------------------------" >> "$corr_log_name"
fi
######## END of routine for below-cutoff n-gram correction
# run automatic correction (main run), unless -o is active
if [ -z "$only_below_cutoff" ]; then
# write to log file
echo "main run:" >> "$corr_log_name"
# inform user
if [ "$verbose" == true ]; then		
	echo "running main length correction..."
	# create feedback variable
	total=$(echo "$input_list" | wc -l)
	# reset progress tracker
	progress_overall=0
fi
# look at things line-by-line
# frequencies and the document count are cut out
for line in $(echo "$input_list" | cut -d '.' -f 1) ; do		
		# update progress_overall
		(( progress_overall += 1 ))
		# report on progress
		if [ "$verbose" == true ] && [ -n "$(echo $progress_overall | grep '000')" ]; then
			if [ "$(( $progress_overall * 100 / $total ))" -lt "10" ]; then
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b  $(expr $progress_overall '*' 100 '/' $total)% complete"
			else
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b $(expr $progress_overall '*' 100 '/' $total)% complete"
			fi
		fi
		# see how many lines in the list contain the current line (excluding the
		# current line itself)
		if [ $(echo "$input_list" | egrep "(^$line|$separator$line\.)" | grep -v "^$line\." | wc -l) -ge $activationat ]; then
			if [ "$diagnostic" == true ]; then
				echo "hurdle 1 passed for $line"
			fi
			# check if the line itself is still in the file now (it might have
			# been eliminated in the meantime)
			if [ -z "$(echo "$input_list" | egrep "^$line\.")" ]; then
				if [ "$diagnostic" == true ]; then
					echo "is already eliminated"
				fi
				continue
				echo "this should not be displayed"
			fi				
			# establish nsize + 1
			nsize=$(echo "$line" | tr -dc "$short_sep" | wc -c | sed 's/ //'g)
			if [ "$short_sep" == "·" ]; then
				nsize=$(( nsize / 2 ))
			fi
			nsize_plus1=$(( $nsize + 1 ))
			# reset asso_lines
			asso_lines=
			asso_line=
			num_of_asso_lines=
			# get associated lines of length nsize +1
			for asso_line in $(echo "$input_list" | egrep "^$line|$separator$line\."); do
				asso_size=$(echo "$asso_line" | tr -dc "$short_sep" | wc -c | sed 's/ //'g)
				if [ "$short_sep" == "·" ]; then
					asso_size=$(( asso_size / 2 ))
				fi
				if [ $asso_size -eq $nsize_plus1 ]; then
					# count 'em
					(( num_of_asso_lines += 1 ))
					# put them in a variable (there is a line break in it)
					asso_lines="$asso_line
$asso_lines"
				fi
			done
			# if no associated lines of correct size were found, set 
			# variable accordingly
			if [ -z "$num_of_asso_lines" ]; then
				num_of_asso_lines=0
			fi
			# check if number of associated lines of length nsize +1 clear the
			# second activation threshold, if not skip to next line
			if [ $num_of_asso_lines -gt $activationat ]; then
				# i.e., if the number is higher than second threshold,
				# store lines to be corrected in array lines_to_corr
				# only associated lines of length nsize +1 are considered
				# (we've already stored these in the variable asso_lines)
				# since the current line will also need correcting, we add it, too
				lines_to_corr="$(echo "$input_list" | egrep "^$line\.") $asso_lines"	
				# reset values
				new_freq=
				new_doc=
				# sum frequencies of associated lines
				for a_line in $(echo "$lines_to_corr"); do
					(( new_freq += $(echo "$a_line" | cut -d '.' -f 2) ))
				done
				# additional restrictions before executing correction:
				# 1) line sequence must have sufficient frequency vis a vis
				#    associated frequencies
				# 2) base sequence must not have a higher frequency than
				#    indicated in the $basetop variable
				# get frequency of base line
				base_freq=$(echo $lines_to_corr | cut -d '.' -f 2 | cut -d ' ' -f 1)
				# get ratio
				ratio=$(echo "$base_freq / $new_freq" | bc -l )
				# apply ratio test
				if [ $(echo "$ratio > $min_ratio" | bc) -eq 1 ] && [ $base_freq -lt $basetop ]; then
					# execute correction:
					# write corrected line to to corrected_line variable
					if [ "$doc" == true ]; then
						new_doc=$(echo $lines_to_corr | cut -d ' ' -f 1 | cut -d '.' -f 3-9)
						corrected_line="$line.$new_freq.$new_doc"
					else
						corrected_line="$line.$new_freq"
					fi
					# remove lines that were corrected from list
					for i in $lines_to_corr; do
						input_list=$(echo "$input_list" | egrep -v "^$i$")
					done
					# add the corrected line to the original list
					input_list="$corrected_line
"$input_list""	
					# write to corr_log_name
					# first write lines that were corrected
					echo "$lines_to_corr" | sed -e 's/  / /g' -e 's/ /\
/g' -e 's/\./ /g' 	>> "$corr_log_name"
					# then write new line
					echo "---corrected-to-->> $line	$new_freq	$new_doc" >> "$corr_log_name"
					if [ "$diagnostic" == true ]; then
						echo "hurdles 2 and 3 also passed for $line"
					fi
				else
					if [ "$diagnostic" == true ]; then
						echo "ratio was $ratio, min ratio was $min_ratio"
						echo "base freq was $base_freq, more than limit at $basetop"
					fi
				fi
			fi
		fi
done
# inform user
if [ "$verbose" == true ]; then
	echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b 100% complete"
	echo ""
fi
fi # this is the 'fi' for the test of whether to run the main run
# routine for below-cutoff n-grams (third time)
if [ "$maxed_out" == true ]; then
	:
elif [ -n "$regex" ]; then
	# write a divider to the correction-log.txt file
	echo "----------------------------------------------------------" >> "$corr_log_name"
	# run eroutine
	eroutine
fi
if [ "$maxed_out" == true ]; then
	:
elif [ -n "$regex" ]; then
	# write a divider to the correction-log.txt file
	echo "----------------------------------------------------------" >> "$corr_log_name"
	# run eroutine
	eroutine
fi
# write output file
add_to_name "$argument_file.adju.txt"
echo "$input_list" | sed -e 's/\./	/g' -e 's/HYPH/-/g' -e 's/DOT/./g' -e 's/SLASH/\//g' -e "s/APO/\'/g"  -e 's/LBRACKET/(/g' -e 's/RBRACKET/)/g' -e 's/PLUS/+/g' > "$output_filename"
# empty memory
input_list=
if [ "$replace" == true ]; then
	mv "$output_filename" "$argument_file"
	# inform user
	if [ "$verbose" == true ]; then
		echo "output file in $argument_file (replaced input file)"
		echo "log file in $corr_log_name"
	fi
else
	# inform user
	if [ "$verbose" == true ]; then
		echo "output file in $output_filename"
		echo "log file in $corr_log_name"
	fi
fi
# now we close the for-loop that looped over argument lists
done
###################################### END OF UNINDENTED FOR LOOP #############
# tidy up
rm -r $SCRATCHDIR > /dev/null &