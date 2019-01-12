#!/bin/bash -
##############################################################################
# listconv.sh
copyright="Copyright (c) 2016, 2019 Cardiff University, 2011-4 Andreas Buerki"
# licensed under the EUPL V.1.1.
version="1.0"
####
# SYNOPSIS: listconv.sh [OPTIONS] FILE(S)
####
# history
# date			change
# 14 Jan 2016	updated (c) notice and licence information
# 19 Sep 2014	fixed -n option, added -p option and more input formats
# 25 Nov 2013	added -n option and made default output use the interpunct
# 23 Dec 2011	remove placement of empty (i.e. 0) document count into output lists
# 01 Jan 2019   adjustments to work better with Google n-gram format 1

### defining functions
# define help function
help ( ) {
	echo "
SYNOPSIS:   $(basename $0) [OPTIONS] FILE(S)
OPTIONS: -v verbose
         -h help
         -t output list in NGramTools format (i.e. 'n gram 0')
         -n output list using diamond (<>) as separator (i.e. 'n<>gram<>	0[ 0]')
          
DESCRRIPTION: converts the format of n-gram lists from a number of input formats
          (see below), incl. the format of
          NGramTools (http://homepages.inf.ed.ac.uk/lzhang10/ngram.html),
          the N-Gram Statistics Package (found at http://
          ngram.sourceforge.net) and Google Books n-gram corpus (version 1)
          (http://storage.googleapis.com/books/ngrams/books/datasetsv2.html)
          to the NGP format (see http://buerki.github.io/ngramprocessor/).
          The original list has the affix .old added to its name and
          a new list is produced in the desired format (by default this
          is the NGP format: 'n·gram·	0	0' (tab delimited), but see -t and
          -n options.
          
NOTE:     The -n option should be used when in a non-unicode environment.
          The script automatically recognises the format of input lists if in
          any of the formats listed below and converts to the format
          'n·gram·	0[	0]'
# input formats: (automatically recognised)
################
#
# 	1	'n<>gram<>1 1 1 ' or n·gram·1 1 (output of count.pl of the NSP)
#		(i.e. n-gram of any size, with frequency count immediately following
#		then (optionally) various figures for stats calculation (space 
#		delimited) with a final trailing space on each line)
#
#	2	'n<>gram<>154091 4.4659 2 1 1' (output of statistics.pl of NSP)
#		(i.e. n-gram of any size, with rank, statistics-score, frequency  
#		[possibly document frequency or other numbers], space-delimited)
#		a variant of this format is 'n<>gram<> 154091 4.4659 2 1'
#
#	3	'n gram 6' (output of text2ngram)
#		(i.e. n-gram of any size followed by its frequency all space delimited)
#
#	4	'n<>gram<> 370' or 'n·gram·	370'
#		(i.e. n-gram of any size, with tab delimited frequency count, w/o
#		trailing space)
#
#	5	'n<>gram<>	370	258' or 'n·gram·	370	258'
# 		(i.e. n-gram of any size, tab delimited without trailing space,
#		first number is freq., second doc count)
#
#	6	'n<>gram<>	370	258	T|F'	or  'n·gram·	370	258	T|F'
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
#	9	'n gram	1991	1	1' or 'n gram	1991	1	1	1'
#		This is the Google Books n-gram corpus version 1 (version 2 is different).
#		(i.e. n-gram with a space between constituents, tab, year,
#		frequency, page frequency, book frequency). Book frequency is taken as 
#		document frequency in the conversion
#
# output formats:
#################
#
#	default:	'n·gram· 370	320'
#				(i.e. the NGP format; n-gram, frequency, [doc frequency], 
#				tab delimited. Document frequency is optional, depending on the input)
#
#	-t option	'n gram 6'
#				(i.e. the NGramTools format)
#
#	-n option	'n<>gram<>	3	2'
#				(i.e. n-gram, frequency, [doc frequency], tab delimited)
"
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
### end define functions
# set default outsep
outsep='·'
# analyse options
while getopts hvnptV opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	v)	verbose=true
		;;
	n)	outsep='<>'
		;;
	p)	separator="$OPTARG"
		;;
	t)	t2n=true
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
	# set separator for list with either · or <>
	if [ -z "$separator" ]; then
		echo "establishing separator"
		if [ -e "$list" ]; then
			# check separator for current list
			if [ "$(head -1 "$list" | egrep ' ([[:punct:]]|[[:alnum:]])+	[0-9][0-9][0-9][0-9]	[0-9]+	[0-9]+	[0-9]+$')" ]; then
							separator=" "
							short_sep=" "
							googlebooksformat=TRUE
							echo "Google Books n-gram format detected"
			elif [ "$(head -1 "$list" | grep '<>')" ]; then
				separator='<>'
				short_sep='<'
			elif [ "$(head -1 "$list" | grep '·')" ]; then
				separator="·"
				short_sep="·"
			elif [ "$(head -2 "$list" | grep '<>')" ]; then
					separator='<>'
					short_sep='<'
					eliminate_first_line=true
			elif [ "$(head -2 "$list" | grep '·')" ]; then
					separator="·"
					short_sep="·"
					eliminate_first_line=true
			else
				echo "unknown separator in $(head -1 "$list") of file $list" >&2; sleep 2
				exit 1
			fi
		else
			echo "$list was not found"; sleep 2
			exit 1
		fi
	fi
	# determine name for .old file
	add_to_name $list.old
	old=$output_filename
	# make old list
	mv $list $old
	#### if NSP or NGP-based format: (i.e. there are at least two '$separator's)
	if [ -n "$(grep -m1 "$separator.*$separator" $old)" ] && [ -z "$googlebooksformat" ]; then
		# if it is tab delimited
		if [ -n "$(grep -m1 '	' $old)" ]; then
			# if conversion to t2n format
			if [ "$t2n" == "true" ]; then
				# if stats format (format 7 or 8),
				# i.e. there is a full-stop with numbers either side
				if [ -n "$(egrep -m1 '[0-9]\.[0-9]' $old)" ]; then
					stats_list=true
					mv $old $list
					echo "listconv.sh does not handle this conversion combination." >&2
					exit 0
				fi
				# remove any lines with only numbers and
				# cut off any further numbers after the first and 
				# replace $separator and tabs with spaces
				sed '/^[0-9]*$/d' $old | cut -f 1,2 |
				sed -e "s/$separator/ /g" -e 's/	//g' > $list
			else
				if [ $separator == '·' ] && [ $outsep == '·' ]; then
					mv $old $list
					echo "$list appears to be in the desired format already."
					exit 0
				fi
				sed "s/$separator/$outsep/g" < $old > $list
			fi
		# if space-delimited (actually, if it is NOT tab delimited)
		else
			# if conversion to t2n format
			if [ "$t2n" == "true" ]; then
				# if stats format (format 2)
				# i.e. there is a full-stop with numbers either side
				if [ -n "$(egrep -m1 '[0-9]\.[0-9]' $old)" ]; then
					# if there is a space after the n-gram
					if [ -n "$(egrep -m1 "$separator " $old)" ]; then
						mv $old $list
						echo "conversion of the following format is not yet implemented: $(head -1 $list)" >&2
						exit 0
					fi
					# extract n-gram and frequency information
					sed "s/$separator[0-9]* [0-9]*\.[0-9]* \([0-9]*\) [0-9]*.*$/$separator\1/g" < $old > $list.	
				# if not stats format (format 1)
				else
					# cut off after the first space
					cut -d ' ' -f 1 < $old > $list.
				fi
				# replace $separator with space and
				# remove any lines with only numbers and
				sed -e "s/$separator/ /g" -e '/^[0-9]*$/d' < $list. > $list
				rm $list.
			# if conversion to format for substring reduction
			else
				# if stats format (format 2)
				# i.e. there is a full-stop with numbers either side
				if [ -n "$(egrep -m1 '[0-9]\.[0-9]' $old)" ]; then
					# if there is a space after the n-gram (variant of format 2)
					if [ -n "$(egrep -m1 "$separator " $old)" ]; then
						echo "conversion of the following format is not yet implemented: $(head -1 $old)"
					fi
					# extract n-gram and frequency information
					sed "s/$separator[0-9]* [0-9]*\.[0-9]* \([0-9]*\) [0-9]*.*$/$separator	\1/g" < $old > $list.	
				# if not stats format (format 1)
				else
					# cut off after the first space
					cut -d ' ' -f 1 < $old > $list.
				fi
				# remove any lines with only numbers,
				# insert tab before final number
				sed -e '/^[0-9]*$/d' -e "s/$separator\([0-9]*$\)/$separator	\1/g" -e "s/$separator/$outsep/g" < $list. > $list
				rm $list.
			fi
		fi
	#### if t2n formatted: ####
	elif [ -n "$(egrep -m1 ' [0-9]*$' $old)" ] && [ -n "$(grep -m1 ' .* ' $old)" ]; then
		# we assume it is t2n formatted if it ends in a digit (or several)
		# preceeded by a space
		if [ "$t2n" == "true" ]; then
			mv $old $list
			echo "$list is already in the requested t2n format" >&2
			exit 0
		fi
		# now we re-format the list
		sed -e 's/ \([0-9]*\)$/ 	\1/g' -e "s/ /$outsep/g" < $old > $list
	### if Google Books formatted: ####
	elif [ -n "$(egrep -m1 '	[0-9][0-9][0-9][0-9]	[0-9]+	[0-9]+	[0-9]+$' $old)" ] && [ "$separator" == " " ]; then
		# select first and 3rd tab-separated field, replace spaces with $outsep
		# insert $outsep before tab
		cut -f 1,3,5 $old | sed -e "s/ /$outsep/g" -e "s/	/$outsep	/" > $list
	# if not in a known format:
	else
		mv $old $list
		echo "$list is in an unrecognised format" >&2
		exit 1
	fi
	done