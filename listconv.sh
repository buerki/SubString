#!/bin/bash -

##############################################################################
# listconv.sh (c) A Buerki 2011-2013 licensed under the EUPL V.1.1.
version="0.8.3"
####
# DESCRRIPTION: converts the format of n-gram lists between those of NGramTools
#				(found at http://homepages.inf.ed.ac.uk/lzhang10/ngram.html),
#				the N-Gram Statistics Package (found at http://
#				ngram.sourceforge.net) and the format for substrd.sh.
#				The original list has the affix .bkup added to its name and
#				a new list is produced in the desired format (by default this
#				is the input format for substrd.sh: 'n·gram·	0	0' (tab
#				delimited).
#
# SYNOPSIS: listconv.sh [OPTIONS] FILE(S)
#
# OPTIONS:	-h	help
#			-v 	verbose
#			-t  output list in NGramTools format (i.e. 'n gram 0')
#			-n  output list using diamond (<>) as separators
##############################################################################
# 
# input formats: (automatically recognised)
################
#
# 	1	'n<>gram<>1 1 1 ' (output of count.pl of the NSP)
#		(i.e. n-gram of any size, with frequency count immediately following
#		then various figures for stats calculation (space delimited) with a 
#		final trailing space on each line)
#
#	2	'n<>gram<>154091 4.4659 2 1 1' (output of statistics.pl of NSP)
#		(i.e. n-gram of any size, with rank, statistics-score, frequency  
#		[possibly document frequency or other numbers], space-delimited)
#		a variant of this format is 'n<>gram<> 154091 4.4659 2 1'
#
#	3	'n gram 6' (output of text2ngram)
#		(i.e. n-gram of any size followed by its frequency all space delimited)
#
#	4	'n<>gram<> 370'
#		(i.e. n-gram of any size, with tab delimited frequency count, w/o
#		trailing space)
#
#	5	'n<>gram<>	370	258'
# 		(i.e. n-gram of any size, tab delimited without trailing space,
#		first number is freq., second doc count)
#
#	6	'n<>gram<>	370	258	T|F'
# 		(i.e. n-gram of any size, tab delimited without trailing space,
#		first number is freq., second doc count, then TP/TP designation)
#
#	7	'n<>gram<>	1	1128.4296	21'
#		(i.e. as immediately below, but without document count)
#
#	8	'n<>gram<>	1	1128.4296	21	1'
#		(i.e. n-gram of any size, tab or space delimited rank, association 
#		measure frequency and document frequency, without trailing space)
#
# output formats:
#################
#
#	default:	'n·gram· 370	320'
#				(i.e. n-gram, frequency, [doc frequency], tab delimited)
#
#	-t option	'n gram 6'
#				(i.e. the NGramTools format)
#
#	-n option	'n<>gram<>	3	2'
#				(i.e. n-gram, frequency, [doc frequency], tab delimited)
###############
# history
# date			change
# 25 Nov 2013	added -n option and made default output use the interpunct
# 23 Dec 2011	remove placement of empty (i.e. 0) document count into output lists


### defining functions

# define help function
help ( ) {
	echo "
Usage:    $(basename $0) [OPTIONS] FILE(S)
Options:  -v verbose
          -h help
          -t  output list in NGramTools format (i.e. 'n gram 0')
          -n  output list using diamond (<>) as separator (i.e. 'n<>gram<>	0[ 0]')
              The -n option should be used when in a non-unicode environment.
note:	  the script automatically recognises the format of the input list
          and converts to the format 'n·gram·	0[	0]'"
}

# define getch function
getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}

# define add_to_name function
add_to_name ( ) {
#####
# this function checks if a file name (given as argument) exists and
# if so appends a number at the end of the name so as to avoid overwriting 
# existing files of the name as in the argument or any with the same name as the 
# argument plus an incremented number count appended.
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

# define exists function (checks if target files exists)
exists ( ) {
if [ -a $1 ] ; then
	echo "$1 exists. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $1
	elif [ $GETCH == n ] ; then
		add_to_name $1.bkup
		mv $1 $output_filename
		echo "named original list $output_filename" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
}

### end define functions

# set default outsep
outsep='·'


# analyse options
while getopts hvt opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	v)	verbose=true
		;;
	n)	outsep='<>'
		;;
	t)	t2n=true
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "Copyright (c) 2011-2013 Andreas Buerki"
		echo "licensed under the EUPL V.1.1"
		exit 0
		;;
	esac
done

shift $((OPTIND -1))

# initialise variables
missing=0

### check if arguments were given and exist
if [ "$#" -lt "1" ]; then
	echo "ERROR: no argument lists provided" >&2
	exit 1
fi
for arg in $@
do
	if [ -a $arg ]; then
		:
	else
		echo "ERROR: $arg could not be found" >&2
		(( missing += 1 ))
	fi
done
if [ "$missing" -gt "0" ]; then
	exit 1
fi




for list in $@
	do
	
	#### if NSP-based format: (i.e. there are at least two '<>') ####
	if [ -n "$(grep -m1 '<>.*<>' $list)" ]; then
	
		# if it is tab delimited
		if [ -n "$(grep -m1 '	' $list)" ]; then
			# if conversion to t2n format
			if [ "$t2n" == "true" ]; then
				# check if $list.bkup exists
				exists $list.bkup
				# append .bkup to original list
				cp $list $list.bkup
				
				# if stats format (format 7 or 8),
				# i.e. there is a full-stop with numbers either side
				if [ -n "$(egrep -m1 '[0-9]\.[0-9]' $list)" ]; then
					stats_list=true
					echo "this conversion is not yet implemented." >&2
					exit 0
				fi
				
				# remove any lines with only numbers
				sed '/^[0-9]*$/d' < $list.bkup > $list
				# cut off any further numbers after the first
				cut -f 1,2 < $list > $list.
				# replace <> and tabs with spaces
				sed -e 's/<>/ /g' -e 's/	//g' < $list. > $list
				rm $list.
				
			# if formats 4,5 or 6:
			else
				# check if $list.bkup exists
				exists $list.bkup
				# append .bkup to original list
				mv $list $list.bkup
				sed 's/<>/·/g' < $list.bkup > $list
			fi
			
		# if space-delimited (actually, if it is NOT tab delimited)
		else
			# check if $list.bkup exists
			exists $list.bkup
			# append .bkup to original list
			cp $list $list.bkup
			
			# if conversion to t2n format
			if [ "$t2n" == "true" ]; then
			
				# if stats format (format 2)
				# i.e. there is a full-stop with numbers either side
				if [ -n "$(egrep -m1 '[0-9]\.[0-9]' $list)" ]; then
					# if there is a space after the n-gram (variant of format 2)
					if [ -n "$(egrep -m1 '<> ' $list)" ]; then
						echo "conversion of the following format is not yet implemented: $(head -1 $list)" >&2
					fi
					# extract n-gram and frequency information
					sed 's/<>[0-9]* [0-9]*\.[0-9]* \([0-9]*\) [0-9]*.*$/<>\1/g' < $list > $list.
					
				# if not stats format (format 1)
				else
					# cut off after the first space
					cut -d ' ' -f 1 < $list > $list.
				fi
				
				# replace <> with space and
				# remove any lines with only numbers and
				sed -e 's/<>/ /g' -e '/^[0-9]*$/d' < $list. > $list
				rm $list.
				
			# if conversion to format for substring reduction
			else
				# if stats format (format 2)
				# i.e. there is a full-stop with numbers either side
				if [ -n "$(egrep -m1 '[0-9]\.[0-9]' $list)" ]; then
					# if there is a space after the n-gram (variant of format 2)
					if [ -n "$(egrep -m1 '<> ' $list)" ]; then
						echo "conversion of the following format is not yet implemented: $(head -1 $list)"
					fi
					# extract n-gram and frequency information
					sed 's/<>[0-9]* [0-9]*\.[0-9]* \([0-9]*\) [0-9]*.*$/<>	\1/g' < $list > $list.
					
				# if not stats format (format 1)
				else
					# cut off after the first space
					cut -d ' ' -f 1 < $list > $list.
				fi
				
				# remove any lines with only numbers,
				# insert tab before final number
				if [ "$outsep" == "<>" ]; then
					sed -e '/^[0-9]*$/d' -e 's/>\([0-9]*$\)/>	\1/g' < $list. > $list
				else
					sed -e '/^[0-9]*$/d' -e 's/>\([0-9]*$\)/>	\1/g' -e 's/<>/·/g' < $list. > $list
				fi
				rm $list.
			fi
		fi
		
	#### if t2n formatted: ####
	elif [ -n "$(egrep -m1 ' [0-9]*$' $list)" ] && [ -n "$(grep -m1 ' .* ' $list)" ]; then
		# we assume it is t2n formatted if it ends in a digit (or several)
		# preceeded by a space
		if [ "$t2n" == "true" ]; then
			echo "$list is already in the requested t2n format" >&2
			exit 0
		fi
		# check if $list.bkup exists
		exists $list.bkup
		# append .bkup to original list
		cp $list $list.bkup
		# now we check what n the n-gram is
		# N=$(head -1 $list | awk -v RS=" " 'END {print NR - 1}')
		# now we re-format the list
		sed -e 's/ \([0-9]*\)$/ 	\1/g' -e "s/ /$outsep/g" < $list.bkup > $list
		
	# if not in a known format:
	else
		echo "$list is in an unrecognised format" >&2
		exit 1
	fi
	done