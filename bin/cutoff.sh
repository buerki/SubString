#!/bin/bash -
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin:"$HOME/bin"" # needed for Cygwin
##############################################################################
# cutoff.sh
copyright="Copyright (c) 2016-2018 Cardiff University, 2011-2014 Andreas Buerki"
# licensed under the EUPL V.1.1.
version="1.0"
####
# DESCRRIPTION: enforces frequency cutoffs in n-gram lists
# SYNOPSIS: cutoff.sh [-f 'regex'][-d 'regex'] [-a 'regex'] FILE(S)
# OPTIONS:	see -h
##############################################################################
# History
# date			change
# 13/01/2011	made output naming more consistent (no trailing dot if no doc
#				cutoff is specified as appeared sporadically before) by ad-
#				justing the method to determine list structure (tab count).
# 04/02/2011	added -v option, fixed recognition of rank stat freq lists
# 10/02/2011	fixed -a option
# 30/04/2011	errors channelled to strderr
# 22/12/2011	added -V option
# 07 Jan 2012	adjusted verbose behaviour to list the lists that will be
#				processed
# 11 Jan 2012	added add_to_name function for output filenames
# (0.8.7)
# 17 Feb 2012	added -n option and expanded information in -h option
# (0.8.8)	
# 25 Nov 2013	made n-gram separators flexible; can not detect · _ or <> as
# (0.8.9)		as valid constituent separators	or whatever is supplied in -p
# 01 Sep 2014	made a few optimisation changes (replaced all cat | grep)
# 07 Sep 2014   added -i option
# (0.9.1)
# 09 Jan 2016	created an easier way to specify cutoff frequencies using -f
# (0.9.9)		and -d (previous way to operate -f/d shifted to -F/-D options) 
# 28 Aug 2018	modified naming behaviour of files with extensions so that 
# (1.0)			extension ends up at the end of the filename as it should

# define functions
help ( ) {
	echo "
Usage: $(basename $0)  [-f 'regex'][-d 'regex'] FILE(S)
Example: $(basename $0)  -f 30 -d 1 list1.txt list2.txt
Options: -f N where 'N' is the minimum frequency allowed (a number between 1 and 101)
         -F requires as argument a regular expression matching
            the n-gram frequencies that should be cut out,
            to cut out frequencies 1-15 the pattern '([0-9]|[1][0-5])'
            should be given as argument (mind the quotes and parentheses)
         -d analog to -f, but applies to document frequencies
         -D analog to -F, but applies to document frequencies, i.e.
            to cut all n-grams that occur in only one document, the
            argument '1' should be given (no quotes necessary as this
            does not contain meta characters)
         -i intelligible name: uses the last number of the freqency cutoff
            regular expression (supplied via -F/f), rather than the whole
            expression, in naming the output file. If -F is used, a
            number (not range of numbers) must be provided as the last
            element in the regular expression, i.e. for all below 11 it
            would be '([1-9]|10|11)' rather than '([1-9]|1[01])'.
         -a analog to -f and -d, but applied to the score of association
            measures (if listed). use only integers, it will cut the
            integers AND following decimals,
            i.e. if AM score [0-5] is entered, 0.0000 to 5.9999 is cut)
         -n N restricts the cutoff to n-grams of size N. This is useful if
            a list with different lengths of n-grams needs to have length-
            specific cutoffs applied.
         -p SEP provide the separator character used to separate elements of
            n-grams in the list (if the script cannot guess it).
         -v verbose
NOTES:
input files must contain data in one of these formats:

	1	'n·gram· 370'
		(i.e. n-gram of any size, with tab delimited frequency count, w/o
		trailing space)

	2	'n·gram·	370	258'
 		(i.e. n-gram of any size, tab delimited without trailing space,
		first number is freq., second doc count)

	3	'n·gram·	370	258	T|F'
 		(i.e. n-gram of any size, tab delimited without trailing space,
		first number is freq., second doc count, then TP/TP designation)

	4	'n·gram·	1	1128.4296	21'
		(i.e. as immediately below, but without document count)

	5	'n·gram·	1	1128.4296	21	1'
		(i.e. n-gram of any size, tab or space delimited rank, association 
		measure, frequency and document frequency, without trailing space)

The script detects these formats automatically and deals with each accoringly.
This script implements n-gram frequency and, if applicable, document 
frequency cut-offs. It cuts out items on the n-gram lists as specified
by the user-supplied regex string.
It appends '.cut.X[.X]' to the cut list (where X is the cut-off regex
for frequency and doc); it leaves the uncut list in place
"
}
Usage ( ) {
	echo "
Usage: $(basename $0)  [-f N][-d N] [-n N] [-v] FILE[S]
use -h for help
"
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
# define regex_maker function
regex_maker ( ) {
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
########################## end defining functions
# analyse options
while getopts ha:F:f:D:d:in:p:vV opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	a)	score=$OPTARG
		a=given
		;;
	f)	cut_freq=$OPTARG
		#deduct 1 to get the cut-frequency
		(( cut_freq -= 1 ))
		min_freq="$cut_freq"
		f=given
		regex_maker
		nfreq="($cut_regex)"
		;;
	F)	nfreq=$OPTARG
		f=given
		min_freq="$(echo "$nfreq"|grep -o '\|[[:digit:]]*)'|sed -e 's/)//' -e 's/\|//')"
		;;
	d)	cut_freq=$OPTARG
		#deduct 1 to get the cut-frequency
		(( cut_freq -= 1 ))
		d=given
		regex_maker
		doc="($cut_regex)"
		min_doc="$doc"
		;;
	D)	doc=$OPTARG
		d=given
		min_doc="$(echo "$doc"|grep -o '\|[[:digit:]]*)'|sed -e 's/)//' -e 's/\|//')"
		;;
	i)	intelligible=true
		;;
	n)	nsize_restriction=$OPTARG
		;;
	p)	separator=$OPTARG
		;;
	v)	verbose=true
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "licensed under the EUPL V.1.1"
		echo "written by Andreas Buerki"
		exit 0
		;;
	esac
done
shift $((OPTIND -1))
# check if any arguments are supplied at all
if [ $# = 0 ]
	then
		Usage
		exit 1
fi
if [ "$verbose" == "true" ]; then
	echo "the following files will be processed"
	echo "$(echo $@ | sed 's/ /\
/g')"
	if [ -n "$nsize_restriction" ]; then
		echo "only n-grams of size $nsize_restriction will be processed"
	fi
	echo " "
fi
# check if arguments exist
for list; do
	if [ -s $list ]; then
		:
	else
		echo "$list not found or empty" >&2
		exit 1
	fi
done
# if -n option is active,
# create scratch directory where temp files can be moved about
if [ -n "$nsize_restriction" ]; then
	SCRATCHDIR=$(mktemp -dt cutoffXXX)
	# if mktemp fails, use a different method to create the scratchdir
	if [ "$SCRATCHDIR" == "" ] ; then
		mkdir ${TMPDIR-/tmp/}cutoff.$$
		SCRATCHDIR=${TMPDIR-/tmp/}cutoff.$$
	fi
fi
for arg in $@
do
	if [ "$verbose" == "true" ]; then
		echo "processing file $arg ..."
	fi
	# establish extension
	ext=$(egrep -o '\.[[:alnum:]]+$' <<<"$arg")
	# establish name without extension
	arg_woext="$(sed -E 's/\.[[:alnum:]]+$//' <<<"$arg")"
	# eliminate total n-gram count if present
	if [ "$(head -1 "$arg" | grep '^[[:digit:]]*.$')" ] || [ "$(head -1 "$arg" | grep '^[[:digit:]]*$')" ]; then
		sed 1d "$arg" > "$arg."
		mv "$arg." "$arg"
		restore=true
	fi
	# set separator and
	# set nsize variable
	# checking input list to derive separator and nsize
	# check if -p option is active and if so, use that separator
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
#	# extract n of n-gram list
#	nsize=$(head -1 "$arg" |  tr -dc "$short_sep" | wc -c | sed 's/ //'g)
#	# this counts binary separator characters as two, so needs adjusting
#	if [ "$short_sep" == "·" ]; then
#		nsize=$(( nsize / 2 ))
#	fi
	if [ "$verbose" == "true" ]; then
		echo "separator is $separator"
	fi
	# check for data structure in input files and treat accordingly
	# 1 tab -> case 1: n·gram·	freq
	# 2 tabs -> case 2: n·gram·	freq	doc
	# 3 tabs, T|F as last character -> case 3: n·gram· freq	doc	T/F
	# 3 tabs, not T|F as last char. -> case 4: n·gram· rank stats freq
	# 4 tabs -> case 5: n·gram·	rank	stats	freq	doc
	# case 1
	if [ $(head -1 $arg | tr -dc '	' | wc -c | sed 's/ //'g) -eq 1 ] ; then # n-gram freq
		if [ "$verbose" == "true" ]; then
			echo "1tab recognised"
		fi
		# check if impossible cutoffs were specified
		if [ "$d" = "given" ]; then
			echo "the list $arg does not seem to contain document frequency information: $(head -1 $arg)" >&2
		elif [ "$a" = "given" ]; then
			echo "this list does not seem to contain score information: $(head -1 $arg)" >&2
			exit 1
		fi
		if [ -z "$nsize_restriction" ]; then
			# make name for output file
			if [ "$intelligible" == true ]; then
				add_to_name $arg_woext.cut.$min_freq$ext
			else
				add_to_name $arg_woext.cut.$nfreq$ext
			fi
			# execute desired cutoff
			grep -E -v "$separator	$nfreq$|^[0-9]*$" $arg > $output_filename
		else
			# make name for output file
			add_to_name $arg_woext.cut.$nfreq.$nsize_restriction-grams$ext
			# execute desired cutoff
			for line in $(sed 's/	/•/g' $arg); do
				# extract n of n-gram
				nsize=$(tr -dc "$short_sep" <<<"$line"| wc -c | sed 's/ //'g)
				# this counts binary separator characters as two, so needs adjusting
				if [ "$short_sep" == "·" ]; then
					nsize=$(( nsize / 2 ))
				fi
				if [ $nsize -eq $nsize_restriction ] && [ -n "$(echo $line | egrep "$separator•$nfreq$")" ]; then
					:
				else
					echo $line | sed 's/•/	/g' >> $SCRATCHDIR/tmp.lst
				fi
			done
			grep -E -v "^[0-9]*$" $SCRATCHDIR/tmp.lst > $output_filename
		fi
	# case 2	
	elif [ $(head -1 $arg | tr -dc '	' | wc -c | sed 's/ //'g) -eq 2 ] ; then # n-gram	freq doc
		if [ "$verbose" == "true" ]; then
			echo "2tabs recognised"
		fi
		# check if impossible cutoffs were specified
		if [ "$a" = "given" ]; then
			echo "this list does not seem to contain score information: $(head -1 $arg)" >&2
			exit 1
		fi
		# check if document cutoff was specified
		if [ "$d" = "given" ]; then
			if [ -z "$nsize_restriction" ]; then
				# make name for output file
				if [ "$intelligible" == true ]; then
					add_to_name $arg_woext.cut.$min_freq.$min_doc$ext
				else
					add_to_name $arg_woext.cut.$nfreq.$doc$ext
				fi
				# execute desired cutoffs
				grep -E -v "$separator	$nfreq	|$separator	[0-9]*	$doc$|^[0-9]*$" $arg > $output_filename
			else
				# execute desired cutoff
				for line in $(sed 's/	/•/g' $arg); do
					# extract n of n-gram
					nsize=$(tr -dc "$short_sep" <<<"$line"| wc -c | sed 's/ //'g)
					# this counts binary separator characters as two, so needs adjusting
					if [ "$short_sep" == "·" ]; then
						nsize=$(( nsize / 2 ))
					fi
					if [ $nsize -eq $nsize_restriction ] && [ -n "$(echo $line | sed 's/•/	/g' | egrep "$separator	$nfreq	|$separator	[0-9]*	$doc$|^[0-9]*$")" ]; then
						:
					else
						echo $line | sed 's/•/	/g' >> $SCRATCHDIR/tmp.lst
					fi
				done
				# make name for output file
				add_to_name $arg_woext.cut.$nfreq.$doc.$nsize_restriction-grams$ext
				# move list into place
				mv $SCRATCHDIR/tmp.lst $output_filename
			fi	
		else
			# no doc-cutoff specified
			if [ -z "$nsize_restriction" ]; then					
				# make name for output file
				if [ "$intelligible" == true ]; then
				add_to_name $arg_woext.cut.$min_freq$ext
				if [ "$verbose" ]; then
					echo "nfreq is $nfreq"
					echo "min_freq is $min_freq"
					echo "name is $output_filename"
				fi
			else
				add_to_name $arg_woext.cut.$nfreq$ext
				if [ "$verbose" ]; then
					echo "nfreq is $nfreq"
					echo "name is $output_filename"
				fi
			fi
				# execute desired cutoffs
				grep -E -v "$separator	$nfreq	|^[0-9]*$" $arg > $output_filename
			else
				# make name for output file
				add_to_name $arg_woext.cut.$nfreq.$nsize_restriction-grams$ext
				# execute desired cutoff
				for line in $(sed 's/	/•/g' $arg); do
					if [ $nsize -eq $nsize_restriction ] && [ -n "$(echo $line | sed 's/•/	/g' | egrep "$separator	$nfreq	|^[0-9]*$")" ]; then
						:
					else
						echo $line | sed 's/•/	/g' >> $SCRATCHDIR/tmp.lst
					fi
				done
				mv $SCRATCHDIR/tmp.lst $output_filename
			fi
		fi
	# if tab-delimited with 3 tabs	
	elif [ $(tail -n 1 $arg | tr -dc '	' | wc -c | sed 's/ //'g) -eq 3 ] ; then
		if [ "$verbose" == "true" ]; then
			echo "3tabs recognised"
		fi
		if [ -n "$nsize_restriction" ]; then
			echo "the -n option is not implemented for this type of list" >&2
			exit 1
		fi
		if [ -n "$(tail -n 1 $arg | grep [TF]$ | cut -f 1)" ]; then
		# n-gram freq doc T|F
		if [ "$verbose" == "true" ]; then
			echo "T/F list recognised"
		fi
		# make name for output file
		add_to_name $arg_woext.cut.$nfreq.$doc$ext
		grep -E -v "$separator	$nfreq	|$separator	[0-9]*	$doc	[TF]$|^[0-9]*$" $arg > $output_filename
		else # n-gram rank stats freq
		if [ "$verbose" == "true" ]; then
			echo "rank stats freq list recognised"
		fi
		# make name for output file
		add_to_name $arg_woext.cut.$nfreq.$score$ext
		grep -E -v "$separator	[0-9]*	[0-9]*\.[0-9]*	$nfreq$|$separator	[0-9]*	$score\.[0-9]*" $arg > $output_filename
		fi
	elif [ $(tail -n 1 $arg | tr -dc '	' | wc -c | sed 's/ //'g) -eq 3 ] ; then # if space-delimited with 3 spaces
		if [ "$verbose" == "true" ]; then
			echo "3space recognised"
		fi
		if [ -n "$nsize_restriction" ]; then
			echo "the -n option is not implemented for this type of list" >&2
			exit 1
		fi
		if [ -n $(tail -n 1 $arg | grep "[TF]$" | cut -f 1) ]; then
		# n-gram freq doc T|F
		if [ "$verbose" == "true" ]; then
			echo "n-gram freq doc T|F list recognised"
		fi
		# make name for output file
		add_to_name $arg_woext.cut.$nfreq.$doc$ext
		grep -E -v "$separator $nfreq |$separator [0-9]* $doc	[TF]$|^[0-9]*$" $arg > $output_filename
		else # n-gram rank stats freq
		if [ "$verbose" == "true" ]; then
			echo "n-gram rank stats freq list recognised"
		fi
		# make name for output file
		add_to_name $arg_woext.cut.$nfreq.$score$ext
		grep -E -v "$separator [0-9]* [0-9]*\.[0-9]* $nfreq$|$separator [0-9]* $score\.[0-9]*" $arg > $output_filename
		fi
	elif [ $(head -1 $arg | tr -dc '	' | wc -c | sed 's/ //'g) -eq 4 ] ; then # n-gram rank stats freq doc
		if [ "$verbose" == "true" ]; then
			echo "n-gram rank stats freq doc list recognised"
		fi
		if [ -n "$nsize_restriction" ]; then
			echo "the -n option is not implemented for this type of list" >&2
			exit 1
		fi
		# make name for output file
		add_to_name $arg_woext.cut.$nfreq.$doc.$score$ext
		grep -E -v "$separator	[0-9]*	[0-9]*\.[0-9]*	$nfreq	|$separator	[0-9]*	[0-9]*\.[0-9]*	[0-9]*	$doc$|$separator	[0-9]*	$score\.[0-9]*" $arg > $output_filename
	elif [ $(head -1 $arg | tr -dc '	' | wc -c | sed 's/ //'g) -eq 4 ] ; then # n-gram rank stats freq doc, space delimited
		if [ "$verbose" == "true" ]; then
			echo "n-gram rank stats freq doc, space delimited list recognised"
		fi
		
		if [ -n "$nsize_restriction" ]; then
			echo "the -n option is not implemented for this type of list" >&2
			exit 1
		fi
		# make name for output file
		add_to_name $arg_woext.cut.$nfreq.$doc.$score$ext
		grep -E -v "$separator [0-9]* [0-9]*\.[0-9]* $nfreq |$separator [0-9]* [0-9]*\.[0-9]* [0-9]* $doc$|$separator [0-9]* $score\.[0-9]*" $arg > $output_filename
	else
		echo "input list format not recognised: $(head -n 1 $arg)" >&2
		exit 1
	fi
done
# tidy up
if [ -n "$nsize_restriction" ]; then
	rm -r $SCRATCHDIR
fi