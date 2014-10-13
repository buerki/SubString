#!/usr/bin/env bash

##############################################################################
# substring.sh 
copyright="Copyright (c) 2011-2014 Andreas Buerki"
# licensed under the EUPL V.1.1.
version="0.9.5"
####
# DESCRRIPTION: performs frequency consolidation among different length n-grams
#				for options see -h
# SYNOPSIS: 	substring.sh [OPTIONS] [-u uncut_list]+ FILE+
##############################################################################
# history
# date			change
# 21 Dec 2011	created substring.sh as a re-write of substrd.sh
#				now uses temporary directory to process lists
#				Automatic mode removed, options revised, integrated functionality of
#				core_substring.sh and prep_stage.sh
# 23 Dec 2011	added test for consecutive n of n-gram lists
# (0.8.2)		consolidated list now retains document counts and/or other numbers
#				that follow the n-gram frequency, adjusted mktemp command not throw
#				errors under the Xubuntu version
# 05 Jan 2012	resolved a problem whereby an empty max. n-gram list is created during
#				the preparation stage, but nothing is added to it. This list will now
#				be deleted before the main consolidation stage.
# 10 Jan 2012	added lines to remove any doubly imported n-grams at the end of the
#				the prep stage
# 11 Jan 2012	added -d option and adjustment of document counts (if they end up
#				higher than frequency counts they are then reduced to the same number
#				as n-gram frequency) as well as format check for input lists
# 16 Jan 2012	added check whether all input files exist and adjusted progress reporting
# (0.8.7)		on prep stage to look nicer, added -f option
# 20 Feb 2012	added identifier line to neg-freq.lst
# (0.8.9)
# 05 May 2012
# (0.9)			added -n and -z option, removed -m option, adjusted help
# 25 Nov 2013	programme now handles n-gram constituent separators flexibly
# (0.9.1)		<> · and _ are recognised automatically, or can be specified
#				using the -p option
# 27 Dec 2013	fixed an issue with reporting unexpected format if underscores
# (0.9.2)		are present in the data
# 18 Sep 2014	efficiency improvements, added ability to include word lists as
# (0.9.4)		shortest list in consolidation.
# 12 Oct 2014	moved to the use of associative arrays if Bash 4 is available to
# (0.9.5)		enable the processing of large amounts of data


#############################################
# define help function
#############################################
help ( ) {
	echo "
Usage:    $(basename $0) [OPTIONS] [-u uncut_list]+ FILE+
Options:  -v verbose (output will not appear on stdout if -v is active)
          -h help
          -d include document count in consolidated lists
          -f sort output list according to frequency (highest first)
          -n include sequences in the final list that show negative frequency
          -o specify an output filename (and location)
          -p SEP specify the separator used in input lists (if none of the
             standard separators (· <> or _) are used.
          -k keep intermediate files
          -z include sequences that feature a consolidated freq. of zero 
Notes:    the output is put in a .substrd file in the pwd unless a different
          output file and location are passed using the -o option
          If -v and -o options are inactive, output is sent to STOUT instead."
}

# define getch function
getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}


#############################################
# define add_to_name function
# this function checks if a file name (given as argument) exists and
# if so appends a number at the end of the name so as to avoid overwriting 
# existing files of the name as in the argument or any with the same name as the 
# argument plus an incremented number count appended.
#############################################
add_to_name ( ) {

count=
if [ -e $1 ]; then
	add=-
	count=1
	while [ -e $1-$count ]
		do
		(( count += 1 ))
		done
else
	count=
	add=
fi
output_filename=$(echo "$1$add$count")

}


#############################################
# define rename_to_tmp function
# this function renames all the lists given as arguments into the N.lst format
# and save them in $SCRATCHDIR
#############################################
rename_to_tmp ( ) {
# RENAME LISTS
if [ "$verbose" ]; then
	echo "selecting lists"
fi

# create a copy of each argument list in the simple N.lst format
for file in $@; do
		# extract n of n-gram list
		nsize=$(head -1 $file | awk '{c+=gsub(s,s)}END{print c}' s="$separator")
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
			sed -e 's/\-/HYPH/g' -e 's/\./DOT/g' -e 's=/=SLASH=g' -e "s/'/APO/g" -e 's/\`//g' -e 's/(/LBRACKET/g' -e 's/)/RBRACKET/g' -e 's/\*/ASTERISK/g' -e 's/+/PLUS/g' -e 's/	/./g' $file > $SCRATCHDIR/$nsize.lst
			# count the number of lists copied
			(( number_of_lists += 1 ))
			
		# if it's not an empty list
		elif [ -s $file ]; then
			echo "ERROR: format of $file not recognised" >&2
			exit 1
		# if it's an empty list, do nothing
		else
			:
		fi
done
}


#############################################
# define prep_stage function
# this function uses uncut (or less severely cut) versions of the input
# lists to improve the accuracy of the frequency consolidation
#############################################
prep_stage ( ) {
# reading files into memory

if [ "$bash_v4" ]; then
	# make sure we're starting afresh
	unset -v 'uncut_list' 'long_list'
	short_list=
	# create associative array for uncut list, put filename in uncut_name and shift to remaining arguments
	declare -A uncut_list; flip=0
	while IFS='.' read -r ngram freq; do uncut_list[$ngram]=$freq; done < <(sed -e 's/\-/HYPH/g' -e 's/\./DOT/g' -e 's=/=SLASH=g' -e "s/'/APO/g" -e 's/\`//g' -e 's/(/LBRACKET/g' -e 's/)/RBRACKET/g' -e 's/\*/ASTERISK/g' -e 's/+/PLUS/g' -e 's/	/./g' $1)
	uncut_name=$1
	shift
	# create associative array for long_list
	declare -A long_list; flip=0
	while IFS='.' read -r ngram freq; do long_list[$ngram]=$freq; done < $2
	# and put short_list into a regular variable, replacing dot with tab
	short_list="$(cat $1)"
else
	# put first arg in var uncut_list, its name in uncut_name and shift args
	uncut_list=$(sed -e 's/\-/HYPH/g' -e 's/\./DOT/g' -e 's=/=SLASH=g' -e "s/'/APO/g" -e 's/\`//g' -e 's/(/LBRACKET/g' -e 's/)/RBRACKET/g' -e 's/\*/ASTERISK/g' -e 's/+/PLUS/g' -e 's/	/./g' $1)
	uncut_name=$1
	shift
	# put long and short list into their variables, too
	short_list="$(cat $1)"
	long_list="$(cat $2)"
fi

#check that nsize of first argument is as expected
if [ "$(head -1 <<< "$short_list" | awk '{c+=gsub(s,s)}END{print c}' s="$separator")" != "$start_list" ]; then
	echo "unexpected format in $1"
	exit 1
fi
# use value of start_list as nsize
nsize=$start_list

# initialise variables
total=$(wc -l <<< "$short_list")
current=0
superstring=

# inform user
if [ "$verbose" ]; then
	echo "looking to restore necessary superstrings from $uncut_name ..."
	echo -n "processing line $current of $total"
fi

# check if running under MacOS and if so use more efficient variant
if [ $(uname -s) == Darwin ]; then
	command1="cut -d "\$short_sep" -f 1-\$extent"
	command2='$(echo $(echo $left | cut -d "$short_sep" -f 1)$separator$line)'
else
	command1='egrep -o "([^$short_sep]*$short_sep){$extent}" | sed "s/$short_sep$//g"'
	command2='$(sed "s/^\([^$short_sep]*·\).*/\1/" <<< "$left")$line'
fi

if [ "$diagnostic" -gt 2 ]; then
	add_to_name superstrings.txt; superout="$output_filename"
	add_to_name transfer.lst; transferout="$output_filename"
	add_to_name rightcut.txt; rightout="$output_filename"
	add_to_name leftnew.txt; leftout="$output_filename"
	echo "diagnostic mode level 3 is ON" >&2
fi

for line in $(cut -d '.' -f 1 <<< "$short_list"); do # line without freqs of first cut list
		
		# inform user
		if [ "$verbose" ] && [ "$(grep '00' <<< $current)" ]; then
		if [ "$current" -lt "10" ]; then
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		elif [ "$current" -lt "100" ]; then
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		elif [ "$current" -lt "1000" ]; then
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		elif [ "$current" -lt "10000" ]; then
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		else
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		fi
		fi
		
		# step 1
		# cut off the rightmost word
		# put the number of words to keep in the variable $extent
		# (this would be the n-size of the current list minus 1)
		extent=$(( $nsize - 1 ))

		right_cut="$(echo $line | eval $command1)$short_sep"
		if [ "$diagnostic" -gt 2 ]; then
			echo "$right_cut" >> $rightout
		fi
		
		# step 2
		# search for a string with anything as leftmost item, followed by
		# the string that had its rightmost word cut off
		# and put the result in the variable 'left_new'
		left_new=$(egrep "$separator$right_cut" <<< "$short_list" | cut -d '.' -f 1)
		# it's ok not to do egrep "^[^$separator]*$separator$right_cut"
		# because $1 will be the list that's only one 'n' longer anyway.
		if [ "$left_new" ]; then # check if anything was found
			#if [ "$diagnostic" -gt 2 ]; then
			#		echo "$left_new" >> $leftout
			#elif [ "$diagnostic" -eq 1 ]; then
			#	echo "step 2"
			#fi
			
			# step 3
			# for each of the lines found,
			# cobble together the projected superstring 
			# (that is: the original line with anything as the leftmost item)
			# and check if it exists in second cut list (i.e. the list of size
			# n+1)
			for left in $left_new ; do
				superstring=$(eval echo $command2)
				#if [ "$diagnostic" -eq 1 ]; then
				#	echo "$superstring" >> $superout
				#fi
				
				# step 4
				if [ "$bash_v4" ]; then
					if [ -z "${long_list["$superstring"]}" ]; then					
					# if this superstring was not found in second cut list
					# try to find it in the uncut list
						if [ "${uncut_list["$superstring"]}" ]; then
							long_list["$superstring"]=${uncut_list["$superstring"]}
						fi
					fi
				else				
					if [ -z "$(egrep "$superstring" <<< "$long_list")" ]; then					
					# if this superstring was not found in second cut list
					# try to find it in the uncut list
					long_list+="
$(egrep "$superstring" <<< "$uncut_list")"
					#if [ "$diagnostic" -gt 2 ]; then
					#	egrep "$superstring" <<< "$uncut_list" >> $transferout &
					#elif [ "$diagnostic" -le 2 ]; then
					#	echo "step 4, looking for $superstring"
					#fi
					fi
				fi
				done
		fi	
done

if [ "$verbose" ]; then
	echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b                   $total lines processed.           "
	echo ""
fi

# write to file and tidy up
if [ "$bash_v4" ]; then
for i in "${!long_list[@]}"; do echo "$i.${long_list[$i]}"; done > $2
unset -v 'uncut_list' 'long_list'
short_list=
else
	echo "$long_list" > $2
	short_list=
	long_list=
fi
}



#############################################
# define consolidate function
# this function does the pairwise consolidation of n-gram lists
#############################################
consolidate ( ) {
# read list with greater N into an array
longer_list="$(cat $2)"
# look at things line by line of list with smaller size N
for line in $(cat $1); do
			# step 1:
			# create variable with line frequency of line in argument 1
			freq1=$(cut -d '.' -f 2 <<< "$line")
			# create variable with any remaining numbers such as document count
			if [ "$doc" ]; then
				remaining_numbers=".$(cut -d '.' -f 3-10 <<< "$line")"
				# this incorporates and initial dot as separator
			else
				remaining_numbers=
			fi

			# step 2:
			# search the second argument for corresponding lines and put
			# their frequency in variable freq2
			# this must happen in 2 steps to make sure we're not matching
			# unintended strings
			
			# create searchline (line without frequencies)
			searchline="$(cut -d '.' -f 1 <<< "$line")"
			
			# match strings that have words to the right of the search string
			# and add their frequencies (produces 0 if no match)
			freq2_right=$(( $(grep "^$searchline" <<< "$longer_list" | \
			cut -d '.' -f 2 | sed 's/^\([0-9]*\)$/\1 +/g') 0 ))
			
			# match strings that have words to the left or ON BOTH SIDES of the
			# search string # and add their frequencies (produces 0 if no match)
			freq2_left_middle=$(( $(grep "$separator$searchline" <<< "$longer_list" | \
			cut -d '.' -f 2 | sed 's/^\([0-9]*\)$/\1 +/g') 0 ))
			
			# add up the frequencies of all matching strings
			freq2=$(( $freq2_right + $freq2_left_middle ))
		
			# this is explained as follows: (starting after report to user)
			# 1 the current line has its freq information cut off
			# 2 a grep search is done with the remaining line 1 in the list
			#   given as second argument
			# 3 the result is piped to cut and only the freq is retained
			# 4 this has a space and a '+' added to it with sed
			# 5 the expression is inside $(( )) to calculate (a '0' is added at
			#   the end so that the string to be evaluated doesn't end in a plus
			# 6 the result of the evaluation is retained in the variable freq2
		
			# step 3:
			# deduct freq2 from freq1
			# put the new freq-value into the newfreq variable
			newfreq=$(( $freq1 - $freq2 ))
			# if there's a problem, print error message
			if [ -z "$freq1" ]; then
				echo "ERROR: $line: freq1 is $freq1, freq2 is $freq2" >&2
			fi
			
			# flag up if there are negative frequencies and log them
			if [ $newfreq -lt 0 ]; then
				# echo "Caution: negative frequencies"
				echo $searchline	$newfreq$remaining_numbers >> $neg_freq_list_name
				((neg_freq_counter +=1))
			fi
			
			# step 4:
			# now line 1 and its new frequency are written to a temporary var
			# unless the frequency is zero or less, in which case the string is 
			# not written unless the -m option was invoked in which case those 
			# strings are written as well
			if [ "$show_neg_freq" == true ] ; then
				new_shorter_list+="
$searchline.$newfreq$remaining_numbers"
			elif [ "$show_zero_freq" == true ] ; then
				if [ $newfreq -ge 0 ]; then
					new_shorter_list+="
$searchline.$newfreq$remaining_numbers"
				fi
			else
				if [ $newfreq -gt 0 ]; then
					new_shorter_list+="
$searchline.$newfreq$remaining_numbers"
				fi
			fi
			
#			((current +=1))
	done
# the original list is overwritten with the temporary variable
echo "$new_shorter_list" > $1
new_shorter_list=
longer_list=
}

#################################end define functions########################

# set some standard variables
diagnostic=0


# analyse options
while getopts hdD:fkno:p:u:vVz opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	d)	doc=true
		;;
	D)	diagnostic="$OPTARG"
		# argument indicates level of diagnostic feedback
		;;
	f)	freq_sort="-nrk 2"
		;;
	k)	keep_intermediate_files=true
		;;
	n)	show_neg_freq=true
		# this includes neg_freq (and 0-freq) sequences in final output
		;;
	o)	special_outdir=$OPTARG
		;;
	p)	separator=$OPTARG
		short_sep=$(cut -c 1 $OPTARG)
		;;
	u)	(( number_of_uncut_lists += 1 ))
		if [ $number_of_uncut_lists -eq 1 ]; then
			uncut1=$OPTARG
		elif [ $number_of_uncut_lists -eq 2 ]; then
			uncut2=$OPTARG
		elif [ $number_of_uncut_lists -eq 3 ]; then
			uncut3=$OPTARG
		elif [ $number_of_uncut_lists -eq 4 ]; then
			uncut4=$OPTARG
		elif [ $number_of_uncut_lists -eq 5 ]; then
			uncut5=$OPTARG
		else
			echo "no more than 5 uncut lists allowed" >&2
			exit 1
		fi
		;;
	v)	verbose=true
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "licensed under the EUPL V.1.1"
		exit 0
		;;
	z)	show_zero_freq=true # this includes zero sequences in final output
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

# check if input lists exist and check separator used
for list; do
	if [ -e $list ]; then
		# check separator for current list
		if [ "$separator" ]; then
			if [ "$(head -1 $list | grep "$separator")" ]; then
				:
			# if the separator given is not found and list is not empty,
			# produce error
			elif [ -s $list ]; then
				echo "separator $separator not found in $(head -1 $list) of file $list" >&2
				exit 1
			fi
		elif [ "$(head -1 $list | grep '<>')" ]; then
			separator='<>'
			short_sep='<'
		elif [ "$(head -1 $list | grep '·')" ]; then
			separator="·"
			short_sep="·"
		else
			echo "unknown separator in $(head -1 $list) of file $list" >&2
			exit 1
		fi
	else
		echo "$list was not found"
		exit 1
	fi
done

# check if all is in order with uncut lists provided
# first check if uncut list was provided
if [ -z "$(echo $uncut1)" ]; then
	# if not, set no_prep_stage to true
	no_prep_stage=true
	if [ "$verbose" ]; then
		echo "running without preparatory stage"
	fi
# if uncut list provided, check if (first) uncut list exists and is not empty
elif [ -s $uncut1 ]; then
	# check n of uncut lists
	if [ "$verbose" ]; then
		echo "checking n of uncut lists"
	fi
	i="$number_of_uncut_lists"
	while [ $i -gt 0 ]; do
		if [ -s $(eval echo \$uncut$i) ]; then
			eval nsize_u$i=$(head -1 $(eval echo \$uncut$i) | awk '{c+=gsub(s,s)}END{print c}' s="$separator")
			if [ "$verbose" ]; then
				echo -n "$(eval echo \$nsize_u$i) "
			fi
		else
			echo "$(eval echo \$uncut$i) not found or empty" >&2
			exit 1
		fi
		(( i -= 1 ))
	done

	# check if uncut lists are consecutive with regard to n-size
	i="$number_of_uncut_lists"
	im1=$(( $number_of_uncut_lists - 1 ))
	while [ $im1 -gt 0 ]; do
		if [ $(eval echo \$nsize_u$i) -eq $(( $(eval echo \$nsize_u$im1) + 1 )) ]; then
			(( i -= 1 ))
			(( im1 -= 1 ))
		else
			echo " " >&2
			echo "Error: uncut lists do not appear to have consecutive n-gram lengths." >&2
			exit 1
		fi
	done
	if [ "$verbose" ]; then
		echo "... test passed"
	fi
	
	# establish n-size of first uncut list 
	# and report error if unsuitable
	uncutnsize=$(head -1 $uncut1 | awk '{c+=gsub(s,s)}END{print c}' s="$separator")
	if [ "$uncutnsize" -lt 4 ]; then
		echo 'Error: the first uncut list must be a list of 4-grams or longer n-grams' >&2
		exit 1
	fi
else
	# if provided list does not exist report error and exit
	echo "$uncut1 could not be found or is empty" >&2
	exit 1
fi

# put directory of first input file into input_dir
input_dir=$(dirname $1)

# RENAME n-gram lists into N.lst format and put them in the SCRATCHDIR
# they will also have tabs converted to dots
rename_to_tmp $@

# check if frequency information is of format n<>gram<>	00[	00]
if [ "$verbose" ]; then
	echo "checking list formats..."
fi
for listnumber in $all_cut_lists; do
	if [ "$verbose" ]; then
		echo "checking $listnumber ..."
	fi
	if [ "$(head -1 $SCRATCHDIR/$listnumber | cut -d '.' -f 4)" ]; then
		echo "CAUTION: $listnumber is not of expected format:"
		echo "format is: $(head -1 $SCRATCHDIR/$listnumber)"
		echo "expected format is: n$(echo $separator)gram$(echo $separator)	0[	0]"
		echo "continue? (Y/N)"
		getch
		case $GETCH in
		Y|y)	:
			;;
		*)	exit 1
			;;
		esac
	fi
done

# check if 1.lst is present and if so, if it's empty
if [ -e $SCRATCHDIR/1.lst ]; then
	if [ -s $SCRATCHDIR/1.lst ]; then
		:
	else
		echo "ERROR: 1.lst is empty" >&2
		exit 1
	fi
fi

# check if at least 2 lists were supplied and warn if more than 16 were supplied
if [ $number_of_lists -lt 2 ]; then
	echo "ERROR: please supply at least two valid n-gram lists" >&2
	usage
	rm -r $SCRATCHDIR
	exit 1
elif [ $number_of_lists -gt 16 ]; then
	echo "Warning: over 16 n-gram lists supplied, this will take a long time" >&2
fi

# check if lists are consecutive with regard to n-size
if [ "$verbose" ]; then
	echo "checking whether n of n-gram lists are consecutive"
fi
# depending on whether a 1-gram list exists, set n to correct number
if [ -e $SCRATCHDIR/1.lst ]; then
	n=$number_of_lists
else
	n=$(( $number_of_lists + 1 ))
fi
while [ $n -gt 1 ]; do
	if [ -s $SCRATCHDIR/$n.lst ]; then
		if [ "$verbose" ]; then
			echo -n "$n "
		fi
		(( n -= 1 ))
	else
		echo " " >&2
		echo "Error: list with $n-grams is missing. Check that n-gram lists of consecutive n are provided." >&2
		exit 1
	fi
done
if [ "$verbose" ]; then
	echo "... test passed"
fi

# if prep stage is requested,
# check that the greatest n of uncut lists is at most n of highest cut list +1 and at least n of the highest n cut list
if [ "$no_prep_stage" ]; then
	if [ "$verbose" ]; then
		echo "running without preparatory stage"
	fi
else
	# depending on whether a 1-gram list exists, set n to correct number
	if [ -e $SCRATCHDIR/1.lst ]; then
		n=$number_of_lists
	else
		n=$(( $number_of_lists + 1 ))
	fi
	nu=$(eval echo \$nsize_u$number_of_uncut_lists)
	if [ $n -eq $nu ]; then
		:
	elif [ $(( $n + 1 )) -eq $nu ]; then
		:
	else
		# delete reference to uncut list with largest n
		eval uncut$number_of_uncut_lists=""
		# reduce number_of_uncut_lists
		(( number_of_uncut_lists -= 1))
		# check again
		nu=$(eval echo \$nsize_u$number_of_uncut_lists)
		if [ $n -eq $nu ]; then
			:
		elif [ $(( $n + 1 )) -eq $nu ]; then
			:
		else
			echo "ERROR: the largest n of uncut lists is $nu, the largest n of cut lists is $n"  >&2
			exit 1
		fi
	fi

# check version of bash in use
if [ "$(grep '^4' <<< $BASH_VERSION)" ]; then
	bash_v4=true
else
	echo "Warning: $(basename $0) is running under bash version $BASH_VERSION. If possible, upgrade to bash on your system to version 4.3 or later." >&2
fi



##### starting prep_stage procedure #####
		
	# establish which list we are starting from
	# that is, one smaller than n-size of first uncut list
	start_list=$(( $uncutnsize - 1 ))
		
	# establish next argument up
	next_list=$uncutnsize
	
	#initialise uncut list counter
	uncut_count=1

	## start prep_stage loop
	# while a next uncut list exists
	while [ -e "$(eval echo \$uncut$uncut_count)" ]; do
	
		# check if files exist
		if [ ! -e $SCRATCHDIR/$start_list.lst ];then
			echo "Error: $SCRATCHDIR/$start_list.lst does not exist" >&2
			exit 1
		fi
		if [ ! -e $SCRATCHDIR/$next_list.lst ];then
			# if it does not exist, we create the list
			touch $SCRATCHDIR/$next_list.lst
			(( number_of_lists += 1 ))
		fi
		if [ "$verbose" ]; then
			echo "starting preparatory stage for $start_list.lst $next_list.lst"
		fi
		prep_stage $(eval echo \$uncut$uncut_count) $SCRATCHDIR/$start_list.lst $SCRATCHDIR/$next_list.lst
		
		# move uncut counter forward
		(( uncut_count += 1 ))
		# move other counters forward
		(( start_list +=1 ))
		(( next_list +=1 ))
	
	done
		
# remove any duplicate imports (this can happen in exceptional circumstances)
	if [ "$verbose" ]; then
		echo "checking for duplicates ..."
	fi
	list="$uncutnsize"
	while [ -e "$SCRATCHDIR/$list.lst" ]; do
		#echo "before: $(wc -l $SCRATCHDIR/$list.lst)"
		sort $SCRATCHDIR/$list.lst | uniq > $SCRATCHDIR/$list.lst.alt
		mv $SCRATCHDIR/$list.lst.alt $SCRATCHDIR/$list.lst
		#echo "after: $(wc -l $SCRATCHDIR/$list.lst)"
		(( list += 1 ))
	done
		
fi

##### end of prep_stage #####

# create output filename for neg-freq.lst
add_to_name neg_freq.lst
neg_freq_list_name="$output_filename"

# check we kept track of number of lists correctly
if [ $number_of_lists -ne "$(ls $SCRATCHDIR/*.lst | wc -l)" ]; then
	echo "ERROR: confusion in number of lists: we counted $number_of_lists, \
	but there are $(ls $SCRATCHDIR/*.lst) lists in $SCRATCHDIR." >&2
	exit 1
fi

# check if we have empty lists and reduce the number of lists by the number
# of empty lists found, making sure that the lists remain consecutive in
# n-size (any applied 1-gram list was already checked)
if [ -e $SCRATCHDIR/1.lst ]; then
	n=$number_of_lists
else
	n=$(( $number_of_lists + 1 ))
fi
previous_list_empty=true
for number in $(eval echo {$n..2});do
	if [ -s $SCRATCHDIR/$number.lst ]; then
		previous_list_empty=false
	elif [ "$previous_list_empty" == true ]; then
		rm $SCRATCHDIR/$number.lst
		((n -= 1))
		((number_of_lists -= 1))
	else
		echo "ERROR: $number.lst is empty, but next larger n-list isn't." >&2
		exit 1
	fi
done

# name n-gram lists with the 'argN' variable
current=1 # create count variable for naming
for ii in $(ls $SCRATCHDIR/*.lst); do
	if [ -s $ii ]; then # if they are non empty
		eval arg$current=$ii # create variable with the name of the list
		((current +=1))
	fi
done

# if list with longest n-grams includes more than one number after n-gram,
# this needs to be removed, unless -d option is active
if [ -z "$doc" ] && [ "$(head -1 $(eval echo \$arg$number_of_lists) | cut -d '.' -f 3)" ]; then
	cut -d '.' -f 1,2 $(eval echo \$arg$number_of_lists) > $(eval echo \$arg$number_of_lists).alt
	mv $(eval echo \$arg$number_of_lists).alt $(eval echo \$arg$number_of_lists)
fi

####### start consolidation #######

# report to user
if [ "$verbose" ]; then
	echo "$number_of_lists lists to consolidate"
fi

# initialise indices
longlistindex="$number_of_lists"
longlistminusindex=$(( $longlistindex - 1 ))

# start loops
until [ 1 -gt $longlistminusindex ]
do
	if [ "$verbose" ]; then
		echo "---------------------------------------------"
		echo "consolidating $(basename $(eval echo \$arg$longlistminusindex)) \
		$(basename $(eval echo \$arg$longlistindex))"
	fi
	consolidate $(eval echo \$arg$longlistminusindex) $(eval echo \$arg$longlistindex)
	
	secondarylonglistindex=$(( $longlistindex - 1 ))
	until [ $longlistminusindex -eq $secondarylonglistindex ]; do
		if [ "$verbose" ]; then
			echo "consolidating $(basename $(eval echo \$arg$longlistminusindex)) \
			$(basename $(eval echo \$arg$secondarylonglistindex))"
		fi
		consolidate $(eval echo \$arg$longlistminusindex) \
		$(eval echo \$arg$secondarylonglistindex)
		(( secondarylonglistindex -= 1 ))
	done
	(( longlistminusindex -= 1 ))
done

# the nested until-loops above result in the lists being passed in pairs to the
# substring function in the following fashion:
# T = top level, list with largest n
# TmN = list with n-grams of length top minus N
# assuming T = 6-grams, for example, this works out to:
#
# 5.lst (Tm1) 6.lst (T)
# ----------------------------
# 4.lst (Tm2) 6.lst (T)
# 4.lst (Tm2) 5.lst (Tm1)
# ----------------------------
# 3.lst (Tm3) 6.lst (T)
# 3.lst (Tm3) 5.lst (Tm1)
# 3.lst (Tm3) 4.lst (Tm2)
# ----------------------------
# 2.lst (Tm4) 6.lst (T)
# 2.lst (Tm4) 5.lst (Tm1)
# 2.lst (Tm4) 4.lst (Tm2)
# 2.lst (Tm4) 3.lst (Tm3)

########################## assemble final list
# derive name for target list
add_to_name $(echo $(basename $arg1)-$(basename $(eval \
echo \$arg$number_of_lists).substrd))
outlist=$output_filename
list_to_print=$number_of_lists

until [ $list_to_print -lt 1 ]; do
	cat $(eval echo \$arg$list_to_print) >> $SCRATCHDIR/$outlist
	(( list_to_print -= 1 ))
done
# if -d option is active, check and adjust document counts
if [ "$doc" ] && [ "$(head -1 $SCRATCHDIR/$outlist | cut -d '.' -f 3)" ]; then
	if [ "$verbose" ]; then
		echo "adjusting document counts..."
	fi
	for line in $(cat $SCRATCHDIR/$outlist); do
		# check if document count is higher than frequency of n-gram
		freq="$(echo -n $line | cut -d '.' -f 2)"
		doccount="$(echo -n $line | cut -d '.' -f 3)"
		if [ "$freq" -lt "$doccount" ]; then
			# write n-gram followed by twice the frequency (the second is the new document count)
			echo "$(cut -d '.' -f 1 <<< "$line").$freq.$freq" >> $SCRATCHDIR/$outlist
			# remove old lines
			echo "^$line" >> $SCRATCHDIR/lines_to_be_deleted.tmp
		fi
	done
	grep -v -f $SCRATCHDIR/lines_to_be_deleted.tmp $SCRATCHDIR/$outlist > $SCRATCHDIR/$outlist.alt
	mv $SCRATCHDIR/$outlist.alt $SCRATCHDIR/$outlist
fi

# if -o option is active, output file to specified directory
# if -v and -o options are off, send list to STOUT so it can be piped
# if -v option is on, but -o is off, write list to default output file
if [ "$special_outdir" ]; then
	# check if such a file already exists and change name accordingly
	add_to_name $special_outdir
	special_outdir="$output_filename"
	if [ "$verbose" ]; then
		echo "writing output list to $special_outdir"
	fi
	sed -e 's/\./	/g' -e 's/HYPH/-/g' -e 's/DOT/./g' -e 's/SLASH/\//g' -e "s/APO/\'/g"  -e 's/LBRACKET/(/g' -e 's/RBRACKET/)/g' -e 's/PLUS/+/g' -e '/^$/d' $SCRATCHDIR/$outlist | sort $freq_sort > $special_outdir
	
elif [ "$verbose" ]; then
	sed -e 's/\./	/g' -e 's/HYPH/-/g' -e 's/DOT/./g' -e 's/SLASH/\//g' -e "s/APO/\'/g"  -e 's/LBRACKET/(/g' -e 's/RBRACKET/)/g' -e 's/PLUS/+/g' -e '/^$/d' $SCRATCHDIR/$outlist | sort $freq_sort > $outlist
	echo "writing output list to $(pwd)/$outlist"
else # that is, if neither -v nor -o options are active
	 # display the result (so it can be piped by the user)
	sed -e 's/\./	/g' -e 's/HYPH/-/g' -e 's/DOT/./g' -e 's/SLASH/\//g' -e "s/APO/\'/g"  -e 's/LBRACKET/(/g' -e 's/RBRACKET/)/g' -e 's/PLUS/+/g' -e '/^$/d' $SCRATCHDIR/$outlist | sort $freq_sort 
fi
######## end of consolidation procedure

# if -k option is active, move intermediate files to a special directory in the pwd
if [ "$keep_intermediate_files" ]; then
	add_to_name intermediate_files
	mkdir $output_filename
	if [ "$verbose" ]; then
		echo "moving intermediate files to $output_filename"
	fi
	mv $SCRATCHDIR/* $output_filename/
fi

# delete temp directory
rm -r $SCRATCHDIR

# negative frequency warning
if [ "$neg_freq_counter" ]; then
	# write identifier line to neg_freq.lst
	echo "# neg_freq list for $input_dir/$outlist - $(date)" | cat - $neg_freq_list_name > $neg_freq_list_name.
	mv $neg_freq_list_name. $neg_freq_list_name
	echo "$neg_freq_counter negative frequencies encountered. see $neg_freq_list_name"  >&2
fi
# display time of completion
if [ "$verbose" ]; then
	echo "operation completed $(date)."
fi
