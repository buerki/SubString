#!/bin/bash -

##############################################################################
# cutoff.sh (c) Andreas Buerki 2009-2011, licensed under the EUPL V.1.1.
####
# DESCRRIPTION: enforces frequency cutoffs in n-gram lists
# SYNOPSIS: cutoff.sh [-f 'regex'][-d 'regex'] [-a 'regex'] FILE(S)
# OPTIONS:	-f	requires as argument a regular expression matching
#				the n-gram frequencies that should be cut out,
#				to cut out frequencies 1-15 the pattern '([0-9]|[1][0-5])'
#				should be given as argument (mind the quotes and parentheses)
#			-d	analog to -f, but applies to document frequencies, i.e.
#				to cut all n-grams that occur in only one document, the
#				argument '1' should be given (no quotes necessary as this
#				does not contain meta characters)
#			-a	analog to -f and -d, but applied to the score of association
#				measures (if listed). use only integers, it will cut the
#				integers AND following decimals,
#				i.e. if AM score [0-5] is entered, 0.0000 to 5.9999 is cut)
#
# NOTES:
# input files must contain data in either of these formats:
#
# 	1	'n<>gram<> 370'
#		(i.e. n-gram of any size, with tab delimited frequency count, w/o
#		trailing space)
#
#	2	'n<>gram<>	370	258'
# 		(i.e. n-gram of any size, tab delimited without trailing space,
#		first number is freq., second doc count)
#
#	3	'n<>gram<>	370	258	T|F'
# 		(i.e. n-gram of any size, tab delimited without trailing space,
#		first number is freq., second doc count, then TP/TP designation)
#
#	4	'n<>gram<>	1	1128.4296	21'
#		(i.e. as immediately below, but without document count)
#
#	5	'n<>gram<>	1	1128.4296	21	1'
#		(i.e. n-gram of any size, tab or space delimited rank, association 
#		measure frequency and document frequency, without trailing space)
#
# The script detects these formats automatically and deals with
# each accoringly.
# This script implements n-gram frequency and, if applicable, document 
# frequency cut-offs. It cuts out items on the n-gram lists as specified
# by the user-supplied regex string
#
# It appends '.cut.X[.X]' to the cut list (where X is the cut-off regex
# for frequency and doc); it leaves the uncut list in place
##############################################################################
# History
# date			change
# 13/01/2011	made output naming more consistent (no trailing dot if no doc
#				cutoff is specified as appeared sporadically before) by ad-
#				justing the method to determine list structure (tab count).
# 04/02/2011	added -v option, fixed recognition of rank stat freq lists
# 10/02/2011	fixed -a option
# 30/04/2011	errors channelled to strderr
# 
#

# define functions
help ( ) {
	echo "
Usage: $(basename $0)  [-f 'regex'][-d 'regex'] FILE(S)
Example: $(basename $0)  -f '([0-9]|[1][0-5])' -d 1 list1.txt list2.txt
"
}

Usage ( ) {
	echo "
Usage: $(basename $0)  [-f cutoff_regex][-d cutoff_regex] [-v] FILE[S]
use -h for help
"
}

# analyse options
while getopts ha:f:d:v opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	a)	score=$OPTARG
		a=given
		;;
	f)	nfreq=$OPTARG
		f=given
		;;
	d)	doc=$OPTARG
		d=given
		;;
	v)	verbose=true
		;;
	esac
done

shift $((OPTIND -1))



if [ $# = 0 ]
	then
		Usage
		exit 1
fi

#if [ -z $f ] && [ -z $d ] ; then
#	exit 0
#fi

for arg in $@
		do
			# check for data structure in input files and treat accordingly
			# 1 tab -> case 1: n<>gram<>	freq
			# 2 tabs -> case 2: n<>gram<>	freq	doc
			# 3 tabs, T|F as last character -> case 3: n<>gram<> freq	doc	T/F
			# 3 tabs, not T|F as last char. -> case 4: n<>gram<> rank stats freq
			# 4 tabs -> case 5: n<>gram<>	rank	stats	freq	doc
			
			if [ $(head -1 $arg | awk -v RS="	" 'END {print NR - 1}') -eq 1 ] ; then # n-gram freq
				if [ "$verbose" == "true" ]; then
					echo "1tab recognised"
				fi
				# check if impossible cutoffs were specified
				if [ "$d" = "given" ]; then
					echo "the list $arg does not seem to contain document frequency information: $(head -1 $arg)" >&2
				elif [ "$a" = "given" ]; then
					echo "this list does not seem to contain score information: $(head -1 $arg)" >&2
				fi
				# execute desired cutoff
				cat $arg | grep -E -v "<>	$nfreq$|^[0-9]*$" > $arg.cut.$nfreq
				
			elif [ $(head -1 $arg | awk -v RS="	" 'END {print NR - 1}') -eq 2 ] ; then # n-gram	freq doc
				if [ "$verbose" == "true" ]; then
					echo "2tabs recognised"
				fi
				# check if impossible cutoffs were specified
				if [ "$a" = "given" ]; then
					echo "this list does not seem to contain score information: $(head -1 $arg)" >&2
				fi
				# check if docment cutoff was specified
				if [ "$d" = "given" ]; then # execute desired cutoffs
					cat $arg | grep -E -v "<>	$nfreq	|<>	[0-9]*	$doc$|^[0-9]*$" > $arg.cut.$nfreq.$doc
				else # execute desired cutoffs
					cat $arg | grep -E -v "<>	$nfreq	|^[0-9]*$" > $arg.cut.$nfreq
				fi
				
			elif [ $(tail -n 1 $arg | awk -v RS="	" 'END {print NR - 1}') -eq 3 ] ; then # if tab-delimited with 3 tabs
				if [ "$verbose" == "true" ]; then
					echo "3tabs recognised"
				fi
				if [ -n "$(tail -n 1 $arg | grep [TF]$ | cut -f 1)" ]; then
				# n-gram freq doc T|F
				if [ "$verbose" == "true" ]; then
					echo "T/F list recognised"
				fi
				cat $arg | grep -E -v "<>	$nfreq	|<>	[0-9]*	$doc	[TF]$|^[0-9]*$" > $arg.cut.$nfreq.$doc
				else # n-gram rank stats freq
				if [ "$verbose" == "true" ]; then
					echo "rank stats freq list recognised"
				fi
				cat $arg | grep -E -v "<>	[0-9]*	[0-9]*\.[0-9]*	$nfreq$|<>	[0-9]*	$score\.[0-9]*" > $arg.cut.$nfreq.$score
				fi
				
			elif [ $(tail -n 1 $arg | awk -v RS=" " 'END {print NR - 1}') -eq 3 ] ; then # if space-delimited with 3 tabs
				if [ "$verbose" == "true" ]; then
					echo "3space recognised"
				fi
				if [ -n $(tail -n 1 $arg | grep "[TF]$" | cut -f 1) ]; then
				# n-gram freq doc T|F
				if [ "$verbose" == "true" ]; then
					echo "n-gram freq doc T|F list recognised"
				fi
				cat $arg | grep -E -v "<> $nfreq |<> [0-9]* $doc	[TF]$|^[0-9]*$" > $arg.cut.$nfreq.$doc
				else # n-gram rank stats freq
				if [ "$verbose" == "true" ]; then
					echo "n-gram rank stats freq list recognised"
				fi
				cat $arg | grep -E -v "<> [0-9]* [0-9]*\.[0-9]* $nfreq$|<> [0-9]* $score\.[0-9]*" > $arg.cut.$nfreq.$score
				fi
			
			elif [ $(head -1 $arg | awk -v RS="	" 'END {print NR - 1}') -eq 4 ] ; then # n-gram rank stats freq doc
				if [ "$verbose" == "true" ]; then
					echo "n-gram rank stats freq doc list recognised"
				fi
				cat $arg | grep -E -v "<>	[0-9]*	[0-9]*\.[0-9]*	$nfreq	|<>	[0-9]*	[0-9]*\.[0-9]*	[0-9]*	$doc$|<>	[0-9]*	$score\.[0-9]*" > $arg.cut.$nfreq.$doc.$score
				
			elif [ $(head -1 $arg | awk -v RS=" " 'END {print NR - 1}') -eq 4 ] ; then # n-gram rank stats freq doc, space delimited
				if [ "$verbose" == "true" ]; then
					echo "n-gram rank stats freq doc, space delimited list recognised"
				fi
				cat $arg | grep -E -v "<> [0-9]* [0-9]*\.[0-9]* $nfreq |<> [0-9]* [0-9]*\.[0-9]* [0-9]* $doc$|<> [0-9]* $score\.[0-9]*" > $arg.cut.$nfreq.$doc.$score
				
			else
				echo "input list format not recognised: $(head -n 1 $arg)" >&2
				exit 1
			fi
		done
