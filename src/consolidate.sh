#!/bin/bash -

##############################################################################
# consolidate.sh
copyright="Copyright (c) 2016 Cardiff University, 2014 Andreas Buerki"
# licensed under the EUPL V.1.1.
version='0.9.9'
####
# DESCRRIPTION: this script consolidates lists with duplicate n-grams (which may
#               have different frequencies) by adding their frequencies into a
#               single entry
# SYNOPSIS:     consolidate.sh [OPTIONS] FILE(s)
# NOTES:		Document frequencies in output lists are handled as follows:
#				if the -d option is active, no document count will be produced,
#				regardless.
#				if input lists WITH document counts are provided, for each 
#				consolidated n-gram, the highest document count of any single
#				one of the unconsolidated duplicate n-grams will be used.
#				if input lists WITHOUT document counts are provided, the 
#				document count added is the number of duplicate n-grams that
#				existed of the n-gram in question, before consolidation.
#				
#				To verify the accuracy of the consolidation, 
#				use token_counter.sh -w to count word tokens before and
#				after consolidation - the number will be the same
#
#				As input lists, n-gram lists tidied with tidy.sh are accepted.
##############################################################################
# History
# date			change
# 26 Jul 2010	enabled processing of several argument lists
# 01 Oct 2010	added .c suffixation of output file, corrected
#               progress percentage display
# 11 Oct 2010	added add_to_name function to prevent overwriting of 
#				consolidated_lines.lst and tidied the output this list.
# 13 Oct 2010	corrected progress display (to stop moving percentage)
# 06 Nov 2010	corrected an error in consolidation that consolidated all
#				strings starting with the same bigram
#				also changed the consolidated_lines.lst contents to actually
#				list all the duplicate lines with frequencies
# 05 Feb 2010	fixed a bug whereby script would exit after no strings to
#				be consolidated were found, leaving subsequent lists undone
# 08 Dec 2011	added -n option and enabled document counts to be written to
#				output lists if -n is inactive and input lists contain doc count
#				moved file processing to a safe scatch directory
# 03 Jan 2012	added -V option
# 05 Jan 2012   changed -k option to -d option, added add_to_name function for
#				output files, original files are left in place w/o .bkup 
#				extension
# 12 Jan 2012	adjusted -d option to also suppress production of 
#				consolidated_lines.lst
# 18 Jan 2012 0.8.3	fixed bug whereby exiting .c file might be overwritten if no 
#				duplicates
#					were found
# 19 Jan 2012 0.8.4 added -r option
# 20 Dec 2013 0.8.5 added -k option and made script compatible with Korean 
#				language input
# 23 Dec 2013 0.9 re-wrote core algorithm for efficiency savings
#				added new -d and -n options
# 28 Dec 2013 0.9.1 adjusted algorithm in line with consolidate function in 
#				split-unify.sh
# 30 Aug 2014 0.9.2 changed semantics of -d option to opposite, fixed separator
#				detection, added filter to filter out monograms.
# 01 Sep 2014 0.9.3 implemented some efficiency improvements re: verbosity stmts
# 04 Sep 2014 0.9.4 fixed problem dealing with several input lists given as args
# 13 Sep 2014 0.9.5 efficiency improvements
# 28 Jan 2015 0.9.6 fixed problem dealing with input that contains parentheses
# 10 Jan 2016 0.9.9 updated (c) notice and -V option
###

# define help function
help ( ) {
	echo "
DESCRRIPTION: this script consolidates lists with duplicate n-grams (which may
              have different frequencies) by adding their frequencies into a
              single entry
SYNOPSIS:     $(basename $0) FILE(s)
OPTIONS:      -v verbose
              -d document count, includes document counts (see more below)
              -k use Korean soring order (programme will try to guess this,
                 but to be certain it can be enforced with this option)
              -n sort final output file by frequency rather than alphabetically
              -p SEP provide a n-gram constituent separator other than <>,·,_
              -r replace input file with output file (includes -d)
              -V display copyright and licensing information
NOTES:		  Document frequencies in output lists are handled as follows:
              With -d option inactive, none are listed; with -d option active,
			  if input lists WITH document counts are provided, for each 
			  consolidated n-gram, the highest document count of any single
			  one of the unconsolidated duplicate n-grams will be used.
			  if input lists WITHOUT document counts are provided, the 
			  document count added is the number of duplicate n-grams that
			  existed of the n-gram in question, before consolidation.

			  To verify the accuracy of the consolidation, 
			  use token_counter.sh -w to count word tokens before and
			  after consolidation - the number will be the same

			  As input lists, n-gram lists tidied with tidy.sh are accepted.
"
}

# define add_to_name function
add_to_name ( ) {
#####
# this function checks if a file name (given as argument) exists and
# if so appends a number to the end so as to avoid overwriting existing
# files of the name as in the argument or any with the name of the argument
# plus an incremented count appended.
####

count=
if [ -a $1 ]; then
	add=-
	count=1
	while [ -a $1-$count ]
		do
		(( count += 1 ))
		done
else
	count=
	add=
fi
output_filename=$(echo "$1$add$count")

}


# define usage function
usage ( ) {
	echo "
Usage:    $(basename $0) FILE(s)
Example:  $(basename $0) 80s-90s-*

"
}


# set default no_document parameter
target_nodoc=true
# define progress counter variable
num=0

# analyse options
while getopts hdknp:rvV opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	d)	target_nodoc=
		;;
	k)	korean="LC_ALL='ko-KR'"
		;;
	n)	sort_by_n='-k2,2nr -k1,1'
		;;
	p)	separator=$OPTARG
		;;
	r)	replace=true
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

if [ "$verbose" == true ]; then
	start=$(date)
	echo "these lists will be processed: $@"
fi

for list in $@; do
	# forward counter
	(( num += 1 ))

	# create scratch directory
	SCRATCHDIR=$(mktemp -dt combinationXXX) 
	# if mktemp fails, use a different method to create the SCRATCHDIR
	if [ "$SCRATCHDIR" == "" ] ; then
		mkdir ${TMPDIR-/tmp/}combination.1$$
		SCRATCHDIR=${TMPDIR-/tmp/}combination.1$$
	fi

	# create name and path for temporary output file
	TMPFILE=$(mktemp -t combinationXXX) || TMPFILE=${TMPDIR-/tmp/}combination.$$
	# this uses mktemp to create a path to a random filename with 'combination'
	# in it, using the path given in the TMPDIR variable and then puts the
	# path into the TMPFILE variable. If this fails, a path is put into the 
	# TMPFILE variable which takes the TMPDIR variable as path (or else the
	# /tmp directory) and 'combination' dot process number as file name.
	# delete the actual file, so we don't get the error that the OUTFILE
	# exists
	rm $TMPFILE

	# for debugging purposes:
	# echo "SCRATCHDIR is $SCRATCHDIR"
	
	# check if source list has document count 
	# (i.e. check for a third column)
	if [ -z "$(head -1 $list | cut -f 3)" ]; then
		source_nodoc=true # source list is supplied without doc counts
		if [ "$verbose" == true ]; then
			echo "lists without document count detected"
		fi
	fi 2> /dev/null
	
	# check if file contains mostly Korean and if so, flip -k option ON
	if [ -n "$(grep -m 1 '[가이를을다습서'] $list)" ]; then
		korean="LC_ALL='ko-KR'"
		if [ -n "$verbose" ]; then
			echo "Hangeul data detected"
		fi
	fi
	
	# set separator
	if [ -z "$separator" ]; then
		line=$(head -1 $list)|| exit 1
		nsize=$(echo $line | tr -dc '<' | wc -c | sed 's/ //'g) 
		if [ "$nsize" -gt 0 ]; then
			separator='<>'
		else
			nsize=$(echo $line | tr -dc '·' | wc -c | sed 's/ //'g)
			if [ "$nsize" -gt 0 ]; then
				separator='·'
			else
				nsize=$(echo $line | tr -dc '_' | wc -c | sed 's/ //'g)
				if [ "$nsize" -gt 0 ]; then
					separator='_'
				else
					echo "unknown separator in $line" >&2
					exit 1
				fi
			fi
		fi
	fi
	
	if [ "$verbose" == true ]; then
		echo "separator is $separator"
		echo "-------------------------------------------------"
		echo "sorting $list ..."
	fi

	# now tidy (in case freqs are not yet separated from n-grams), 
	# sort list and put into memory
	copied_list="$(sed -e 's/\./DOT/g' -e 's/-/HYPH/g' -e 's/(/LBRACKET/g' -e 's/)/RBRACKET/g' -e "s/$separator\([0-9]*\)  /$separator	\1	/g" -e "s/$separator\([0-9]*\) $/$separator	\1/g" -e 's/ $//g' -e 's/	/./g' $list | grep -v '^[0-9]*$' | eval $korean sort)"
	
	# check for instances of duplication and put lines (w/o freq) into variable
	duplicates=$(echo $copied_list | tr ' ' '\n' | cut -d '.' -f 1 | uniq -d | tee $SCRATCHDIR/d)
	
	# if duplicates found, report, otherwise go to next file
	if [ -s $SCRATCHDIR/d ]; then
		if [ "$verbose" == true ]; then
			echo "consolidating duplicate n-grams in list $num of $#,"
			echo "$(cat $SCRATCHDIR/d | wc -l) instances of duplication found..."
		fi
	else
		if [ "$verbose" == true ]; then
			echo "no duplicate n-grams found in $list."
		fi
		# still sort and adjust the name, except if -r option active
		if [ -z "$replace" ]; then
			# check if name for output directory already exists
			add_to_name $list.c
			eval $korean sort -k2,2nr -k1,1 $list > "$output_filename"
		fi
		continue
	fi
		
	# cut off document count if -n option is active and list has a doc-count
	if [ "$target_nodoc" == true ] && [ -z "$source_nodoc" ]; then
		if [ "$verbose" == true ]; then
			echo "cutting out document counts..."
		fi
		copied_list=$(echo "$copied_list" | cut -d '.' -f 1-2)
	fi
	
	# initiate some variables
	total_freq=0
	progress=0
	
	# work out how document counts should be treated
	if [ -z "$target_nodoc" ]; then # doc count is required
		if [ -z "$source_nodoc" ]; then # doc count is present in input
			mode="max" # doc count should be the highest value among those
					   # being consolidated
		else
			mode="dupl" # doc count should be the number of duplicates being
			            # consolidated
		fi
	else
		mode="none" # no doc count required
	fi
	
	# go through list of duplicates line by line
	for line in $(echo $duplicates); do

		# go through actual duplicates, one by one
		for duplicate_lines in $(echo "$copied_list" | egrep "^$line\."); do
			
			# put duplicates into the array 'in'
			IFS='.' read -a in <<< "$duplicate_lines"
			# n-wc -gram is then ${in[0]}
			# freq of n-gram is then ${in[1]}
			# and any document frequency is then ${in[2]}
		
			(( total_freq += ${in[1]} ))
			case $mode in
				max)	acc_doc_freqs+=" ${in[2]}";;
				dupl)	(( acc_doc_freqs += 1 ))
			esac
		done

		# having gone through all duplicates
		case $mode in
			max)	# work out the highest doc count in acc_doc_freqs
					max=0
					for count in $acc_doc_freqs; do
						val=$count
						if [ $val -gt $max ]; then
							max=$val
						fi
					done
					# write to buffer
					buffer+=$"$line	$total_freq	$max "
					# reset variables
					acc_doc_freqs=
					;;
			dupl)	# write to buffer
					buffer+=$"$line	$total_freq	$acc_doc_freqs "
					# reset acc_doc_freqs
					acc_doc_freqs=1
					;;
			none)	# write to buffer
					buffer+=$"$line	$total_freq "
		esac

		# reset total_freq
		total_freq=
				
	done


	# write buffer to file
	echo "$buffer" | tr ' ' '\n' > $TMPFILE

	# write non-duplicates to file:
	# produce grep-line from 'duplicates' variable
	if [ -n "$korean" ]; then
		grepline=$(echo $duplicates | LC_ALL='ko-KR' sed -e 's/$/\\./g' -e 's/ /\\.|^/g' -e 's/^/^/g')
	else
		grepline=$(echo $duplicates | sed -e 's/$/\\./g' -e 's/ /\\.|^/g' -e 's/^/^/g')
	fi
	
	echo "$copied_list" | egrep -v "$grepline" | sed -e 's/\./	/g' -e 's/DOT/./g' -e 's/HYPH/-/g' >> $TMPFILE
	
	
	if [ "$replace" == true ]; then
		eval $korean sort -k2,2nr -k1,1 $TMPFILE | sed -e '/^$/d' -e 's/LBRACKET/(/g' -e 's/RBRACKET/)/g' > $list
	else
		# check if name for output directory already exists
		add_to_name $list.c
		# sort the list
		eval $korean sort -k2,2nr -k1,1 $TMPFILE | sed -e '/^$/d' -e 's/LBRACKET/(/g' -e 's/RBRACKET/)/g' > "$output_filename"
	fi
	
	# empty memory
	copied_list=
	buffer=

	# tidy up in the background
	rm -r $SCRATCHDIR > /dev/null &
	
done


if [ "$verbose" == true ]; then
	echo "start: $start"
	echo "end: $(date)"
fi