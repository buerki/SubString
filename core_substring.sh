#!/bin/bash -

################################################################################
# core_substring.sh (c) Andreas Buerki 2010-2011, licensed under the EUPL V.1.1.
####
# DESCRRIPTION: produces a substring reduced n-gram list from argument lists
# SYNOPSIS: core_substring.sh [OPTIONS] input_lists
# NOTES:
# lists given as arguments must start with the list of the shortest N-grams and finish
# with the longest
# the consolidated list will be named first.lst-last.lst.substrd
# This script absolutely depends on the input being formatted as it is by the
# combination scripts, that is: ZAHL<>ZAHL<>cm<>  205     10
# -> tab delimited without trailing space, first number is freq., second doc count
#
# it is recommended that substring reduction is conducted AFTER any frequency
# cut-offs have been applied to the relevant lists (otherwise it takes forever)
#
# OPTIONS:
# -v verbose mode
# -b keep a separate backup of original, unconsolidated lists w/extension
#    .bkup and let the individual lists reflect the consolidated state
#	 (ordinarily, the individual lists would be left unconsolidated in original state)
# -m also write zero and negative frequencies to output files
#          
#  (-b and -m options are really for diagnostics and not needed for normal operation)
#
#
################################################################################
# History
# date			change
# 21/09/2010	added check for existing output files
# 09/10/2010	changed name of negative.freq.log to neg_freq.hours.minutes
# 12/01/2011	added conversion of HYPH to - stage in final output lists if
#				necessary
# 19/04/2011	changed name of negative frequency log to neg_freq.lst
# 22/04/2011	changed name of script to core_substring.sh, all further
#				development takes place under the new name.
# 30/04/2011	error messages channelled to strderr
###

# initialise variables
number_of_arguments=$(echo "$#")
noaplus1=(expr $number_of_arguments + 1) # number of args + 1
restore_backup=true
neg_freq_counter=0


# define functions


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



# define getch function (reads the first character input from the keyboard)
getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}


# define substring_routine function
substring_routine()
{

if [ "$verbose" == "true" ]; then
	# create variables for user feedback
	total=$(wc -l "$1" | sed 's/^ *\([0-9]*\).*/\1/g')
	currentline=1
fi

# look at things line by line
# spaces in the lines need to be got rid of
# so an underscore is inserted between n-gram and frequency count
# the document count is cut out
for line in $(sed 's/<>	\([0-9]*\).*/<>_\1/g' < "$1")
	do
			# create variable with line frequency of line in argument 1
			line1freq=$(echo $line | cut -d "_" -f 2)

			# search the second argument for corresponding lines and put
			# their frequency in variable line2freq
			# this must happen in 2 steps to make sure we're not matching
			# unintended strings
	
			# match strings that have words to the right of the search string
			line2freq_right=$(expr $(grep "^$(echo $line | sed 's/_[0-9]*//g')" "$2" | \
			cut -f 2 | sed 's/^\([0-9]*\)$/\1 +/g') 0)
			
			# match strings that have words to the left or ON BOTH SIDES of the search string
			line2freq_left_middle=$(expr $(grep "<>$(echo $line | sed 's/_[0-9]*//g')" "$2" | \
			cut -f 2 | sed 's/^\([0-9]*\)$/\1 +/g') 0)
			
			# add up the frequencies of all matching strings
			line2freq=$(expr $line2freq_right + $line2freq_left_middle)
		
			# this is explained as follows: (starting after report to user)
			# 1 the current line has its freq information cut off
			# 2 a grep search is done with the remaining line 1 in the list given as
			#   second argument
			# 3 the result is piped to cut and only the freq is retained
			# 4 this has a space and a '+' added to it with sed
			# 5 expr is called to evaluate the expression (a '0' is added at
			# 6 the end so that the string to be evaluated doesn't end in a plus
			# 7 the result of the evaluation is retained in the variable line2freq
		
		
			# deduct freq from arg 2 line from freq arg 1 line
			# put the new freq-value into the linefreq variable
			linefreq=$(expr $line1freq - $line2freq)
			
			# flag up if there are negative frequencies and log them
			
			if [ $linefreq -lt 0 ]; then
				# echo "Caution: negative frequencies"
				echo $(echo $line | sed 's/_[0-9]*//g')	$linefreq >> $output_filename
				((neg_freq_counter +=1))
			fi
			
			# now line 1 and its new frequency are written to a temporary file
			# unless the frequency is zero, in which case the string is not written
			# unless the -m option was invoked in which case those strings are written
			# as well
			
			# create file so that it is there even if nothing is later written to it
			touch "$1".tmp
			
			if [ "$show_minus_zero_freq" == "true" ] ; then
				echo $(echo $line | sed 's/_[0-9]*//g')	$linefreq >> "$1".tmp
			else
				if [ $linefreq -gt 0 ]; then
					echo $(echo $line | sed 's/_[0-9]*//g')	$linefreq >> "$1".tmp
				fi
			fi
			
			((currentline +=1))
	done
	
	# the spaces are replaced by tabs and the original list replaced by the temporary file
	sed 's/ /	/g' < "$1".tmp  > "$1"
	rm "$1".tmp
	
	# inform user
	if [ "$verbose" == "true" ]; then
		echo "complete."
	fi
}


# define usage function
usage()
{
	echo "
Usage:    $(basename $0) [-v] input_lists
Example:  $(basename $0) 2-gram.lst 3-gram.lst 4-gram.lst 5-gram.lst 6-gram.lst
OPTIONS:  -v cause script to run in verbose mode
          -b keep a separate backup of original, unconsolidated lists 
             w/extension .bkup and let the individual lists (.lst.tidy) reflect
             the consolidated state
          -m also write zero and negative frequencies to output files
          
          (-b and -m options are really for diagnostics and not needed for 
          normal operation)
"
}


# define help function
help()
{
	echo "
DESCRRIPTION: produces a substring reduced n-gram list out of lists supplied
SYNOPSIS: $(basename $0) [-v] input_lists
OPTIONS:  -v cause script to run in verbose mode
          -b keep a separate backup of original, unconsolidated lists 
             w/extension .bkup and let the individual lists (.lst.tidy)
             reflect the consolidated state
          -m also write zero and negative frequencies to output files
          
          (-b and -m options are really for diagnostics and not needed for 
          normal operation)
          
NOTES:
lists given as arguments must start with the list of the shortest N-grams and
finish with the list of longest N-grams
the consolidated list will be named "$1"-$@.substrd
This script absolutely depends on the input being formatted as it is by the
combination scripts, that is: ZAHL<>ZAHL<>cm<>  205     10
-> tab delimited without trailing space, first number is freq., second doc count

it is recommended that substring reduction is conducted AFTER any frequency
cut-offs have been applied to the relevant lists (otherwise it takes forever)
"
}


# define transform_t2n function
transform_t2n()
{
# transform text2ngram lists into NSP-format
# i.e. n gram N  -> n<>gram<>	N	N

# first we make a backup of the original list
cp "$1" "$1".t2nbkup
# now we check what n the n-gram is
N=$(head -1 "$1" | awk -v RS=" " 'END {print NR - 1}')
# now we re-format the list
sed -e 's/ /\<\>/g' -e "s/\<\>/\<\>	/$N" "$1".t2nbkup > "$1"
}

# end defining functions


# analyse options
while getopts hvbm opt
do
	case $opt	in
	b)	restore_backup=false
		;;
	h)	help
		exit 0
		;;
	v)	verbose=true
		;;
	m)	show_minus_zero_freq=true
		;;
	esac
done

shift $((OPTIND -1))

#### input checks

# check if at least 2 arguments and no more than 16 were supplied
	if [ $# -lt 2 ]; then
		echo "Error: please supply at least two arguments" >&2
		usage
		exit 1
	elif [ $# -gt 16 ]; then
		echo "Error: a maximum of 16 arguments are allowed" >&2
		usage
		exit 1
	fi

# check if supplied arguments exist
for i in $@
	do
	if [ -e $i ]; then
		:
	else
		echo "error: '$i' does not exist" >&2
		usage
		exit 1
	fi
	done

# check if arguments are non-empty and if so assign them a variable name 'argN'
current=1 # create count variable for naming
for ii in $@ # for all arguments
	do
		if [ -s $ii ]; then # if they are non empty
			eval arg$current=$ii # create variable with the name of the list
			((current +=1))
		fi
	done


# check if neg_freq.lst exists
add_to_name neg_freq.lst


# report to user
if [ "$verbose" == "true" ]; then
echo "$arg1 is arg1"
echo "$arg2 is arg2"
if [ -e "$arg3" ]; then
	echo "$arg3 is arg3"
fi
if [ -e "$arg4" ]; then
	echo "$arg4 is arg4"
fi
if [ -e "$arg5" ]; then
	echo "$arg5 is arg5"
fi
if [ -e "$arg6" ]; then
	echo "$arg6 is arg6"
fi
if [ -e "$arg7" ]; then
	echo "$arg7 is arg7"
fi
if [ -e "$arg8" ]; then
	echo "$arg8 is arg8"
fi
if [ -e "$arg9" ]; then
	echo "$arg9 is arg9"
fi
if [ -e "$arg10" ]; then
	echo "$arg10 is arg10"
fi
if [ -e "$arg11" ]; then
	echo "$arg11 is arg11"
fi
if [ -e "$arg12" ]; then
	echo "$arg12 is arg12"
fi
if [ -e "$arg13" ]; then
	echo "$arg13 is arg13"
fi
if [ -e "$arg14" ]; then
	echo "$arg14 is arg14"
fi
if [ -e "$arg15" ]; then
	echo "$arg15 is arg15"
fi
if [ -e "$arg16" ]; then
	echo "$arg16 is arg16"
fi
fi

# adjust the number_of_arguments variable to exculde any empty lists
number_of_arguments=$(echo "$arg1 $arg2 $arg3 $arg4 $arg5 $arg6 $arg7 $arg8 $arg9 $arg10 $arg11 $arg12 $arg13 $arg14 $arg15 $arg16" \
| wc -w | sed 's/ //g')

# report to user
if [ "$verbose" == "true" ]; then
echo "the number of arguments is $number_of_arguments"
fi

# check if lists are of the correct format, i.e. n<>gram<>	N	N
# first check is it NSP-formatted or not. If not it is assumed to be text2ngram formatted
# then check if the lists might be in the untidy output form
# then check if they might be list processed with statistic.pl
for iii in $arg1 $arg2 $arg3 $arg4 $arg5 $arg6 $arg7 $arg8 $arg9 $arg10 $arg11 $arg12 $arg13 $arg14 $arg15 $arg16
	do
		if [ -n "$(grep -m1 '<>.*<>' $iii)" ]; then # checking if the pattern <>.*<> exists
			if [ -n "$(grep -m1 '<>[0-9]* $' $iii)" ]; then # checking if the pattern <>N exists
				echo "list $iii is in unprocessable format: $(grep -m1 '<>[0-9]* $' $iii)" >&2
				echo "run tidy1.sh or tidy2.sh first" >&2
				exit 1
			elif [ -n "$(grep -m1 '[0-9]*\.[0-9]' $iii)" ]; then # checking if the pattern N.N exists
				echo "Error! list $iii is likely list processed with statistic.pl." >&2
				echo "It is not suited for use in substring reduction, as frequency must be the first number after the n-gram" >&2
				exit 1
			fi
		else
			echo "Warning: lists with n-grams across sentence boundaries can lead to unexpected results in substring reduction." >&2
			transform_t2n $iii
		fi
	done

# check if the lists were given in the correct order, i.e. from bigrams to trigrams, etc.
if [ $(head -1 $arg1 | awk -v RS=">" 'END {print NR - 1}') -ge $(head -1 $arg2 | awk -v RS=">" 'END {print NR - 1}') ]; then
	echo "Error: argument lists are not supplied in the right order." >&2
	echo "start with bigram lists and move to trigrams, etc." >&2
	usage
	exit 1
fi





#### assign names to arguments
if [ "$number_of_arguments" == "17" ]; then
	T=$arg17
	Tm1=$arg16
	Tm2=$arg15
	Tm3=$arg14
	Tm4=$arg13
	Tm5=$arg12
	Tm6=$arg11
	Tm7=$arg10
	Tm8=$arg9
	Tm9=$arg8
	Tm10=$arg7
	Tm11=$arg6
	Tm12=$arg5
	Tm13=$arg4
	Tm14=$arg3
	Tm15=$arg2
	Tm16=$arg1
elif [ "$number_of_arguments" == "16" ]; then
	T=$arg16
	Tm1=$arg15
	Tm2=$arg14
	Tm3=$arg13
	Tm4=$arg12
	Tm5=$arg11
	Tm6=$arg10
	Tm7=$arg9
	Tm8=$arg8
	Tm9=$arg7
	Tm10=$arg6
	Tm11=$arg5
	Tm12=$arg4
	Tm13=$arg3
	Tm14=$arg2
	Tm15=$arg1
elif [ "$number_of_arguments" == "15" ]; then
	T=$arg15
	Tm1=$arg14
	Tm2=$arg13
	Tm3=$arg12
	Tm4=$arg11
	Tm5=$arg10
	Tm6=$arg9
	Tm7=$arg8
	Tm8=$arg7
	Tm9=$arg6
	Tm10=$arg5
	Tm11=$arg4
	Tm12=$arg3
	Tm13=$arg2
	Tm14=$arg1
elif [ "$number_of_arguments" == "14" ]; then
	T=$arg14
	Tm1=$arg13
	Tm2=$arg12
	Tm3=$arg11
	Tm4=$arg10
	Tm5=$arg9
	Tm6=$arg8
	Tm7=$arg7
	Tm8=$arg6
	Tm9=$arg5
	Tm10=$arg4
	Tm11=$arg3
	Tm12=$arg2
	Tm13=$arg1
elif [ "$number_of_arguments" == "13" ]; then
	T=$arg13
	Tm1=$arg12
	Tm2=$arg11
	Tm3=$arg10
	Tm4=$arg9
	Tm5=$arg8
	Tm6=$arg7
	Tm7=$arg6
	Tm8=$arg5
	Tm9=$arg4
	Tm10=$arg3
	Tm11=$arg2
	Tm12=$arg1
elif [ "$number_of_arguments" == "12" ]; then
	T=$arg12
	Tm1=$arg11
	Tm2=$arg10
	Tm3=$arg9
	Tm4=$arg8
	Tm5=$arg7
	Tm6=$arg6
	Tm7=$arg5
	Tm8=$arg4
	Tm9=$arg3
	Tm10=$arg2
	Tm11=$arg1
elif [ "$number_of_arguments" == "11" ]; then
	T=$arg11
	Tm1=$arg10
	Tm2=$arg9
	Tm3=$arg8
	Tm4=$arg7
	Tm5=$arg6
	Tm6=$arg5
	Tm7=$arg4
	Tm8=$arg3
	Tm9=$arg2
	Tm10=$arg1
elif [ "$number_of_arguments" == "10" ]; then
	T=$arg10
	Tm1=$arg9
	Tm2=$arg8
	Tm3=$arg7
	Tm4=$arg6
	Tm5=$arg5
	Tm6=$arg4
	Tm7=$arg3
	Tm8=$arg2
	Tm9=$arg1
elif [ "$number_of_arguments" == "9" ]; then
	T=$arg9
	Tm1=$arg8
	Tm2=$arg7
	Tm3=$arg6
	Tm4=$arg5
	Tm5=$arg4
	Tm6=$arg3
	Tm7=$arg2
	Tm8=$arg1
elif [ "$number_of_arguments" == "8" ]; then
	T=$arg8
	Tm1=$arg7
	Tm2=$arg6
	Tm3=$arg5
	Tm4=$arg4
	Tm5=$arg3
	Tm6=$arg2
	Tm7=$arg1
elif [ "$number_of_arguments" == "7" ]; then
	T=$arg7
	Tm1=$arg6
	Tm2=$arg5
	Tm3=$arg4
	Tm4=$arg3
	Tm5=$arg2
	Tm6=$arg1
elif [ "$number_of_arguments" == "6" ]; then
	T=$arg6
	Tm1=$arg5
	Tm2=$arg4
	Tm3=$arg3
	Tm4=$arg2
	Tm5=$arg1
elif [ "$number_of_arguments" == "5" ]; then
	T=$arg5
	Tm1=$arg4
	Tm2=$arg3
	Tm3=$arg2
	Tm4=$arg1
elif [ "$number_of_arguments" == "4" ]; then
	T=$arg4
	Tm1=$arg3
	Tm2=$arg2
	Tm3=$arg1
elif [ "$number_of_arguments" == "3" ]; then
	T=$arg3
	Tm1=$arg2
	Tm2=$arg1
elif [ "$number_of_arguments" == "2" ]; then
	T=$arg2
	Tm1=$arg1
fi


# display processing information
if [ "$verbose" == "true" ]; then
echo "T is $T"
echo "Tm1 is $Tm1"
if [ -e "$Tm2" ]; then
	echo "Tm2 is $Tm2"
fi
if [ -e "$Tm3" ]; then
	echo "Tm3 is $Tm3"
fi
if [ -e "$Tm4" ]; then
	echo "Tm4 is $Tm4"
fi
if [ -e "$Tm5" ]; then
	echo "Tm5 is $Tm5"
fi
if [ -e "$Tm6" ]; then
	echo "Tm6 is $Tm6"
fi
if [ -e "$Tm7" ]; then
	echo "Tm7 is $Tm7"
fi
if [ -e "$Tm8" ]; then
	echo "Tm8 is $Tm8"
fi
if [ -e "$Tm9" ]; then
	echo "Tm9 is $Tm9"
fi
if [ -e "$Tm10" ]; then
	echo "Tm10 is $Tm10"
fi
if [ -e "$Tm11" ]; then
	echo "Tm11 is $Tm11"
fi
if [ -e "$Tm12" ]; then
	echo "Tm12 is $Tm12"
fi
if [ -e "$Tm13" ]; then
	echo "Tm13 is $Tm13"
fi
if [ -e "$Tm14" ]; then
	echo "Tm14 is $Tm14"
fi
if [ -e "$Tm15" ]; then
	echo "Tm15 is $Tm15"
fi
if [ -e "$Tm16" ]; then
	echo "Tm16 is $Tm16"
fi
fi


# check if target lists exists
if [ -a $Tm1-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm1-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm1-$T.substrd $Tm1-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm2-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm2-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm2-$T.substrd $Tm2-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm3-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm3-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm3-$T.substrd $Tm3-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm4-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm4-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm4-$T.substrd $Tm4-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm5-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm5-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm5-$T.substrd $Tm5-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm6-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm6-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm6-$T.substrd $Tm6-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm7-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm7-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm7-$T.substrd $Tm7-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm8-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm8-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm8-$T.substrd $Tm8-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm9-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm9-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm9-$T.substrd $Tm9-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm10-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm10-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm10-$T.substrd $Tm10-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm11-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm11-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm11-$T.substrd $Tm11-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm12-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm12-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm12-$T.substrd $Tm12-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm13-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm13-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm13-$T.substrd $Tm13-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm14-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm14-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm14-$T.substrd $Tm14-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm15-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm15-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm15-$T.substrd $Tm15-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
if [ -a $Tm16-$T.substrd ] ; then
	echo "$Tm1-$T.substrd exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $Tm16-$T.substrd
	elif [ $GETCH == n ] ; then
		mv $Tm16-$T.substrd $Tm16-$T.substrd.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi


#### consolidate T and T-1 levels

# to preserve original lists, make a backup of shorter list
cp $Tm1 $Tm1.bkup

# if $T includes more than one number after n-gram, this needs to be removed
if [ -n $(head -1 $T | cut -f 3) ]; then
	cp $T $T.bkup
	cut -f 1,2 $T.bkup > $T
fi

# call on substring routine to consolidate T and T-1
if [ "$verbose" == "true" ]; then
	echo "consolidating $Tm1 $T"
fi
substring_routine $Tm1 $T

# if there only were 2 lists, assemble final list and exit
if [ "$number_of_arguments" == "2" ]; then
	cat $T $Tm1 | sort > $Tm1-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm1-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
		mv $T.bkup $T 2> /dev/null
		mv $Tm1.bkup $Tm1 2> /dev/null
	fi
	
	# negative frequency warning
	#if [ "$neg_freq_counter" -gt 0 ]; then
	#	echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename"  >&2
	#fi
	
	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-2 level

# to preserve original lists, make a backup of shorter list
cp $Tm2 $Tm2.bkup

# call on substring routine to consolidate T and T-2
if [ "$verbose" == "true" ]; then echo "consolidating $Tm2 $T"; fi
substring_routine $Tm2 $T

# call on substring routine to consolidate T-1 and T-2
if [ "$verbose" == "true" ]; then echo "consolidating $Tm2 $Tm1"; fi
substring_routine $Tm2 $Tm1

# if there only were 3 lists, assemble final list and exit
if [ "$number_of_arguments" == "3" ]; then
	cat $T $Tm1 $Tm2 | sort > $Tm2-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm2-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	fi

	# negative frequency warning
	#if [ "$neg_freq_counter" -gt 0 ]; then
	#	echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename"  >&2
	#fi
	
	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done

	exit 0
fi


#### consolidate T-3 level

# to preserve original lists, make a backup of shorter list
cp $Tm3 $Tm3.bkup

# call on substring routine to consolidate T and T-3
if [ "$verbose" == "true" ]; then echo "consolidating $Tm3 $T"; fi
substring_routine $Tm3 $T

# call on substring routine to consolidate T-1 and T-3
if [ "$verbose" == "true" ]; then echo "consolidating $Tm3 $Tm1"; fi
substring_routine $Tm3 $Tm1

# call on substring routine to consolidate T-2 and T-3
if [ "$verbose" == "true" ]; then echo "consolidating $Tm3 $Tm2"; fi
substring_routine $Tm3 $Tm2

# if there only were 4 lists, assemble final list and exit
if [ "$number_of_arguments" == "4" ]; then
	cat $T $Tm1 $Tm2 $Tm3 | sort > $Tm3-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm3-$T.substrd"
	fi
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	fi
	
	# negative frequency warning
	#if [ "$neg_freq_counter" -gt 0 ]; then
	#	echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename"  >&2
	#fi
	
	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-4 level

# to preserve original lists, make a backup of shorter list
cp $Tm4 $Tm4.bkup

# call on substring routine to consolidate T and T-4
if [ "$verbose" == "true" ]; then echo "consolidating $Tm4 $T"; fi
substring_routine $Tm4 $T

# call on substring routine to consolidate T-1 and T-4
if [ "$verbose" == "true" ]; then echo "consolidating $Tm4 $Tm1"; fi
substring_routine $Tm4 $Tm1

# call on substring routine to consolidate T-2 and T-4
if [ "$verbose" == "true" ]; then echo "consolidating $Tm4 $Tm2"; fi
substring_routine $Tm4 $Tm2

# call on substring routine to consolidate T-3 and T-4
if [ "$verbose" == "true" ]; then echo "consolidating $Tm4 $Tm3"; fi
substring_routine $Tm4 $Tm3

# if there only were 5 lists, assemble final list and exit
if [ "$number_of_arguments" == "5" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 | sort > $Tm4-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm4-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-5 level

# to preserve original lists, make a backup of shorter list
cp $Tm5 $Tm5.bkup

# call on substring routine to consolidate T and T-5
if [ "$verbose" == "true" ]; then echo "consolidating $Tm5 $T"; fi
substring_routine $Tm5 $T

# call on substring routine to consolidate T-1 and T-5
if [ "$verbose" == "true" ]; then echo "consolidating $Tm5 $Tm1"; fi
substring_routine $Tm5 $Tm1

# call on substring routine to consolidate T-2 and T-5
if [ "$verbose" == "true" ]; then echo "consolidating $Tm5 $Tm2"; fi
substring_routine $Tm5 $Tm2

# call on substring routine to consolidate T-3 and T-5
if [ "$verbose" == "true" ]; then echo "consolidating $Tm5 $Tm3"; fi
substring_routine $Tm5 $Tm3

# call on substring routine to consolidate T-4 and T-5
if [ "$verbose" == "true" ]; then echo "consolidating $Tm5 $Tm4"; fi
substring_routine $Tm5 $Tm4

# if there only were 6 lists, assemble final list and exit
if [ "$number_of_arguments" == "6" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5| sort > $Tm5-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm5-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-6 level

# to preserve original lists, make a backup of shorter list
cp $Tm6 $Tm6.bkup

# call on substring routine to consolidate T and T-6
if [ "$verbose" == "true" ]; then echo "consolidating $Tm6 $T"; fi
substring_routine $Tm6 $T

# call on substring routine to consolidate T-1 and T-6
if [ "$verbose" == "true" ]; then echo "consolidating $Tm6 $Tm1"; fi
substring_routine $Tm6 $Tm1

# call on substring routine to consolidate T-2 and T-6
if [ "$verbose" == "true" ]; then echo "consolidating $Tm6 $Tm2"; fi
substring_routine $Tm6 $Tm2

# call on substring routine to consolidate T-3 and T-6
if [ "$verbose" == "true" ]; then echo "consolidating $Tm6 $Tm3"; fi
substring_routine $Tm6 $Tm3

# call on substring routine to consolidate T-4 and T-6
if [ "$verbose" == "true" ]; then echo "consolidating $Tm6 $Tm4"; fi
substring_routine $Tm6 $Tm4

# call on substring routine to consolidate T-5 and T-6
if [ "$verbose" == "true" ]; then echo "consolidating $Tm6 $Tm5"; fi
substring_routine $Tm6 $Tm5

# if there only were 7 lists, assemble final list and exit
if [ "$number_of_arguments" == "7" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 | sort > $Tm6-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm6-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi

#### consolidate T-7 level

# to preserve original lists, make a backup of shorter list
cp $Tm7 $Tm7.bkup

# call on substring routine to consolidate T and T-7
if [ "$verbose" == "true" ]; then echo "consolidating $Tm7 $T"; fi
substring_routine $Tm7 $T

# call on substring routine to consolidate T-1 and T-7
if [ "$verbose" == "true" ]; then echo "consolidating $Tm7 $Tm1"; fi
substring_routine $Tm7 $Tm1

# call on substring routine to consolidate T-2 and T-7
if [ "$verbose" == "true" ]; then echo "consolidating $Tm7 $Tm2"; fi
substring_routine $Tm7 $Tm2

# call on substring routine to consolidate T-3 and T-7
if [ "$verbose" == "true" ]; then echo "consolidating $Tm7 $Tm3"; fi
substring_routine $Tm7 $Tm3

# call on substring routine to consolidate T-4 and T-7
if [ "$verbose" == "true" ]; then echo "consolidating $Tm7 $Tm4"; fi
substring_routine $Tm7 $Tm4

# call on substring routine to consolidate T-5 and T-7
if [ "$verbose" == "true" ]; then echo "consolidating $Tm7 $Tm5"; fi
substring_routine $Tm7 $Tm5

# call on substring routine to consolidate T-6 and T-7
if [ "$verbose" == "true" ]; then echo "consolidating $Tm7 $Tm6"; fi
substring_routine $Tm7 $Tm6

# if there only were 8 lists, assemble final list and exit
if [ "$number_of_arguments" == "8" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 | sort > $Tm7-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm7-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi

#### consolidate T-8 level

# to preserve original lists, make a backup of shorter list
cp $Tm8 $Tm8.bkup

# call on substring routine to consolidate T and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $T"; fi
substring_routine $Tm8 $T

# call on substring routine to consolidate T-1 and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $Tm1"; fi
substring_routine $Tm8 $Tm1

# call on substring routine to consolidate T-2 and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $Tm2"; fi
substring_routine $Tm8 $Tm2

# call on substring routine to consolidate T-3 and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $Tm3"; fi
substring_routine $Tm8 $Tm3

# call on substring routine to consolidate T-4 and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $Tm4"; fi
substring_routine $Tm8 $Tm4

# call on substring routine to consolidate T-5 and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $Tm5"; fi
substring_routine $Tm8 $Tm5

# call on substring routine to consolidate T-6 and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $Tm6"; fi
substring_routine $Tm8 $Tm6

# call on substring routine to consolidate T-7 and T-8
if [ "$verbose" == "true" ]; then echo "consolidating $Tm8 $Tm7"; fi
substring_routine $Tm8 $Tm7

# if there only were 9 lists, assemble final list and exit
if [ "$number_of_arguments" == "9" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 | sort > $Tm8-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm8-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-9 level

# to preserve original lists, make a backup of shorter list
cp $Tm9 $Tm9.bkup

# call on substring routine to consolidate T and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $T"; fi
substring_routine $Tm9 $T

# call on substring routine to consolidate T-1 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm1"; fi
substring_routine $Tm9 $Tm1

# call on substring routine to consolidate T-2 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm2"; fi
substring_routine $Tm9 $Tm2

# call on substring routine to consolidate T-3 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm3"; fi
substring_routine $Tm9 $Tm3

# call on substring routine to consolidate T-4 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm4"; fi
substring_routine $Tm9 $Tm4

# call on substring routine to consolidate T-5 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm5"; fi
substring_routine $Tm9 $Tm5

# call on substring routine to consolidate T-6 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm6"; fi
substring_routine $Tm9 $Tm6

# call on substring routine to consolidate T-7 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm7"; fi
substring_routine $Tm9 $Tm7

# call on substring routine to consolidate T-8 and T-9
if [ "$verbose" == "true" ]; then echo "consolidating $Tm9 $Tm8"; fi
substring_routine $Tm9 $Tm8

# if there only were 10 lists, assemble final list and exit
if [ "$number_of_arguments" == "10" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 | sort > $Tm9-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm9-$T.substrd"
	fi

	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-10 level

# to preserve original lists, make a backup of shorter list
cp $Tm10 $Tm10.bkup

# call on substring routine to consolidate T and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $T"; fi
substring_routine $Tm10 $T

# call on substring routine to consolidate T-1 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm1"; fi
substring_routine $Tm10 $Tm1

# call on substring routine to consolidate T-2 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm2"; fi
substring_routine $Tm10 $Tm2

# call on substring routine to consolidate T-3 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm3"; fi
substring_routine $Tm10 $Tm3

# call on substring routine to consolidate T-4 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm4"; fi
substring_routine $Tm10 $Tm4

# call on substring routine to consolidate T-5 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm5"; fi
substring_routine $Tm10 $Tm5

# call on substring routine to consolidate T-6 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm6"; fi
substring_routine $Tm10 $Tm6

# call on substring routine to consolidate T-7 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm7"; fi
substring_routine $Tm10 $Tm7

# call on substring routine to consolidate T-8 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm8"; fi
substring_routine $Tm10 $Tm8

# call on substring routine to consolidate T-9 and T-10
if [ "$verbose" == "true" ]; then echo "consolidating $Tm10 $Tm9"; fi
substring_routine $Tm10 $Tm9

# if there only were 11 lists, assemble final list and exit
if [ "$number_of_arguments" == "11" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 $Tm10 | sort > $Tm10-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm10-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	mv $Tm10.bkup $Tm10 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-11 level

# to preserve original lists, make a backup of shorter list
cp $Tm11 $Tm11.bkup

# call on substring routine to consolidate T and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $T"; fi
substring_routine $Tm11 $T

# call on substring routine to consolidate T-1 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm1"; fi
substring_routine $Tm11 $Tm1

# call on substring routine to consolidate T-2 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm2"; fi
substring_routine $Tm11 $Tm2

# call on substring routine to consolidate T-3 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm3"; fi
substring_routine $Tm11 $Tm3

# call on substring routine to consolidate T-4 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm4"; fi
substring_routine $Tm11 $Tm4

# call on substring routine to consolidate T-5 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm5"; fi
substring_routine $Tm11 $Tm5

# call on substring routine to consolidate T-6 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm6"; fi
substring_routine $Tm11 $Tm6

# call on substring routine to consolidate T-7 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm7"; fi
substring_routine $Tm11 $Tm7

# call on substring routine to consolidate T-8 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm8"; fi
substring_routine $Tm11 $Tm8

# call on substring routine to consolidate T-9 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm9"; fi
substring_routine $Tm11 $Tm9

# call on substring routine to consolidate T-10 and T-11
if [ "$verbose" == "true" ]; then echo "consolidating $Tm11 $Tm10"; fi
substring_routine $Tm11 $Tm10

# if there only were 12 lists, assemble final list and exit
if [ "$number_of_arguments" == "12" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 $Tm10 $Tm11 | sort > $Tm11-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm11-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	mv $Tm10.bkup $Tm10 2> /dev/null
	mv $Tm11.bkup $Tm11 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done

	exit 0
fi


#### consolidate T-12 level

# to preserve original lists, make a backup of shorter list
cp $Tm12 $Tm12.bkup

# call on substring routine to consolidate T and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $T"; fi
substring_routine $Tm12 $T

# call on substring routine to consolidate T-1 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm1"; fi
substring_routine $Tm12 $Tm1

# call on substring routine to consolidate T-2 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm2"; fi
substring_routine $Tm12 $Tm2

# call on substring routine to consolidate T-3 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm3"; fi
substring_routine $Tm12 $Tm3

# call on substring routine to consolidate T-4 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm4"; fi
substring_routine $Tm12 $Tm4

# call on substring routine to consolidate T-5 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm5"; fi
substring_routine $Tm12 $Tm5

# call on substring routine to consolidate T-6 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm6"; fi
substring_routine $Tm12 $Tm6

# call on substring routine to consolidate T-7 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm7"; fi
substring_routine $Tm12 $Tm7

# call on substring routine to consolidate T-8 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm8"; fi
substring_routine $Tm12 $Tm8

# call on substring routine to consolidate T-9 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm9"; fi
substring_routine $Tm12 $Tm9

# call on substring routine to consolidate T-10 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm10"; fi
substring_routine $Tm12 $Tm10

# call on substring routine to consolidate T-11 and T-12
if [ "$verbose" == "true" ]; then echo "consolidating $Tm12 $Tm11"; fi
substring_routine $Tm12 $Tm11

# if there only were 13 lists, assemble final list and exit
if [ "$number_of_arguments" == "13" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 $Tm10 $Tm11 $Tm12 | sort > $Tm12-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm12-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	mv $Tm10.bkup $Tm10 2> /dev/null
	mv $Tm11.bkup $Tm11 2> /dev/null
	mv $Tm12.bkup $Tm12 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-13 level

# to preserve original lists, make a backup of shorter list
cp $Tm13 $Tm13.bkup

# call on substring routine to consolidate T and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $T"; fi
substring_routine $Tm13 $T

# call on substring routine to consolidate T-1 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm1"; fi
substring_routine $Tm13 $Tm1

# call on substring routine to consolidate T-2 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm2"; fi
substring_routine $Tm13 $Tm2

# call on substring routine to consolidate T-3 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm3"; fi
substring_routine $Tm13 $Tm3

# call on substring routine to consolidate T-4 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm4"; fi
substring_routine $Tm13 $Tm4

# call on substring routine to consolidate T-5 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm5"; fi
substring_routine $Tm13 $Tm5

# call on substring routine to consolidate T-6 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm6"; fi
substring_routine $Tm13 $Tm6

# call on substring routine to consolidate T-7 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm7"; fi
substring_routine $Tm13 $Tm7

# call on substring routine to consolidate T-8 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm8"; fi
substring_routine $Tm13 $Tm8

# call on substring routine to consolidate T-9 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm9"; fi
substring_routine $Tm13 $Tm9

# call on substring routine to consolidate T-10 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm10"; fi
substring_routine $Tm13 $Tm10

# call on substring routine to consolidate T-11 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm11"; fi
substring_routine $Tm13 $Tm11

# call on substring routine to consolidate T-12 and T-13
if [ "$verbose" == "true" ]; then echo "consolidating $Tm13 $Tm12"; fi
substring_routine $Tm13 $Tm12

# if there only were 14 lists, assemble final list and exit
if [ "$number_of_arguments" == "14" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 $Tm10 $Tm11 $Tm12 $Tm13 | sort > $Tm13-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm13-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	mv $Tm10.bkup $Tm10 2> /dev/null
	mv $Tm11.bkup $Tm11 2> /dev/null
	mv $Tm12.bkup $Tm12 2> /dev/null
	mv $Tm13.bkup $Tm13 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-14 level

# to preserve original lists, make a backup of shorter list
cp $Tm14 $Tm14.bkup

# call on substring routine to consolidate T and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $T"; fi
substring_routine $Tm14 $T

# call on substring routine to consolidate T-1 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm1"; fi
substring_routine $Tm14 $Tm1

# call on substring routine to consolidate T-2 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm2"; fi
substring_routine $Tm14 $Tm2

# call on substring routine to consolidate T-3 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm3"; fi
substring_routine $Tm14 $Tm3

# call on substring routine to consolidate T-4 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm4"; fi
substring_routine $Tm14 $Tm4

# call on substring routine to consolidate T-5 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm5"; fi
substring_routine $Tm14 $Tm5

# call on substring routine to consolidate T-6 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm6"; fi
substring_routine $Tm14 $Tm6

# call on substring routine to consolidate T-7 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm7"; fi
substring_routine $Tm14 $Tm7

# call on substring routine to consolidate T-8 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm8"; fi
substring_routine $Tm14 $Tm8

# call on substring routine to consolidate T-9 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm9"; fi
substring_routine $Tm14 $Tm9

# call on substring routine to consolidate T-10 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm10"; fi
substring_routine $Tm14 $Tm10

# call on substring routine to consolidate T-11 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm11"; fi
substring_routine $Tm14 $Tm11

# call on substring routine to consolidate T-12 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm12"; fi
substring_routine $Tm14 $Tm12

# call on substring routine to consolidate T-13 and T-14
if [ "$verbose" == "true" ]; then echo "consolidating $Tm14 $Tm13"; fi
substring_routine $Tm14 $Tm13

# if there only were 15 lists, assemble final list and exit
if [ "$number_of_arguments" == "15" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 $Tm10 $Tm11 $Tm12 $Tm13 $Tm14| sort > $Tm14-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm14-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	mv $Tm10.bkup $Tm10 2> /dev/null
	mv $Tm11.bkup $Tm11 2> /dev/null
	mv $Tm12.bkup $Tm12 2> /dev/null
	mv $Tm13.bkup $Tm13 2> /dev/null
	mv $Tm14.bkup $Tm14 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-15 level

# to preserve original lists, make a backup of shorter list
cp $Tm15 $Tm15.bkup

# call on substring routine to consolidate T and T-15
if [ "$verbose" == "true" ]; then echo "$Tm15 $T"; fi
substring_routine $Tm15 $T

# call on substring routine to consolidate T-1 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm1"; fi
substring_routine $Tm15 $Tm1

# call on substring routine to consolidate T-2 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm2"; fi
substring_routine $Tm15 $Tm2

# call on substring routine to consolidate T-3 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm3"; fi
substring_routine $Tm15 $Tm3

# call on substring routine to consolidate T-4 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm4"; fi
substring_routine $Tm15 $Tm4

# call on substring routine to consolidate T-5 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm5"; fi
substring_routine $Tm15 $Tm5

# call on substring routine to consolidate T-6 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm6"; fi
substring_routine $Tm15 $Tm6

# call on substring routine to consolidate T-7 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm7"; fi
substring_routine $Tm15 $Tm7

# call on substring routine to consolidate T-8 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm8"; fi
substring_routine $Tm15 $Tm8

# call on substring routine to consolidate T-9 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm9"; fi
substring_routine $Tm15 $Tm9

# call on substring routine to consolidate T-10 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm10"; fi
substring_routine $Tm15 $Tm10

# call on substring routine to consolidate T-11 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm11"; fi
substring_routine $Tm15 $Tm11

# call on substring routine to consolidate T-12 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm12"; fi
substring_routine $Tm15 $Tm12

# call on substring routine to consolidate T-13 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm13"; fi
substring_routine $Tm15 $Tm13

# call on substring routine to consolidate T-14 and T-15
if [ "$verbose" == "true" ]; then echo "consolidating $Tm15 $Tm14"; fi
substring_routine $Tm15 $Tm14

# if there only were 16 lists, assemble final list and exit
if [ "$number_of_arguments" == "16" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 $Tm10 $Tm11 $Tm12 $Tm13 $Tm14 $Tm15 | sort > $Tm15-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm15-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	mv $Tm10.bkup $Tm10 2> /dev/null
	mv $Tm11.bkup $Tm11 2> /dev/null
	mv $Tm12.bkup $Tm12 2> /dev/null
	mv $Tm13.bkup $Tm13 2> /dev/null
	mv $Tm14.bkup $Tm14 2> /dev/null
	mv $Tm15.bkup $Tm15 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi


#### consolidate T-16 level

# to preserve original lists, make a backup of shorter list
cp $Tm16 $Tm16.bkup

# call on substring routine to consolidate T and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $T"; fi
substring_routine $Tm16 $T

# call on substring routine to consolidate T-1 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm1"; fi
substring_routine $Tm16 $Tm1

# call on substring routine to consolidate T-2 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm2"; fi
substring_routine $Tm16 $Tm2

# call on substring routine to consolidate T-3 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm3"; fi
substring_routine $Tm16 $Tm3

# call on substring routine to consolidate T-4 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm4"; fi
substring_routine $Tm16 $Tm4

# call on substring routine to consolidate T-5 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm5"; fi
substring_routine $Tm16 $Tm5

# call on substring routine to consolidate T-6 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm6"; fi
substring_routine $Tm16 $Tm6

# call on substring routine to consolidate T-7 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm7"; fi
substring_routine $Tm16 $Tm7

# call on substring routine to consolidate T-8 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm8"; fi
substring_routine $Tm16 $Tm8

# call on substring routine to consolidate T-9 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm9"; fi
substring_routine $Tm16 $Tm9

# call on substring routine to consolidate T-10 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm10"; fi
substring_routine $Tm16 $Tm10

# call on substring routine to consolidate T-11 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm11"; fi
substring_routine $Tm16 $Tm11

# call on substring routine to consolidate T-12 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm12"; fi
substring_routine $Tm16 $Tm12

# call on substring routine to consolidate T-13 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm13"; fi
substring_routine $Tm16 $Tm13

# call on substring routine to consolidate T-14 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm14"; fi
substring_routine $Tm16 $Tm14

# call on substring routine to consolidate T-15 and T-16
if [ "$verbose" == "true" ]; then echo "consolidating $Tm16 $Tm15"; fi
substring_routine $Tm16 $Tm15

# if there only were 17 lists, assemble final list and exit
if [ "$number_of_arguments" == "17" ]; then
	cat $T $Tm1 $Tm2 $Tm3 $Tm4 $Tm5 $Tm6 $Tm7 $Tm8 $Tm9 $Tm10 $Tm11 $Tm12 $Tm13 $Tm14 $Tm15 $Tm16 | sort > $Tm16-$T.substrd
	if [ "$verbose" == "true" ]; then
		echo "substring reduction complete. see $Tm16-$T.substrd"
	fi
	
	# restore backups
	if [ "$restore_backup" == "true" ]; then
	mv $T.bkup $T 2> /dev/null
	mv $Tm1.bkup $Tm1 2> /dev/null
	mv $Tm2.bkup $Tm2 2> /dev/null
	mv $Tm3.bkup $Tm3 2> /dev/null
	mv $Tm4.bkup $Tm4 2> /dev/null
	mv $Tm5.bkup $Tm5 2> /dev/null
	mv $Tm6.bkup $Tm6 2> /dev/null
	mv $Tm7.bkup $Tm7 2> /dev/null
	mv $Tm8.bkup $Tm8 2> /dev/null
	mv $Tm9.bkup $Tm9 2> /dev/null
	mv $Tm10.bkup $Tm10 2> /dev/null
	mv $Tm11.bkup $Tm11 2> /dev/null
	mv $Tm12.bkup $Tm12 2> /dev/null
	mv $Tm13.bkup $Tm13 2> /dev/null
	mv $Tm14.bkup $Tm14 2> /dev/null
	mv $Tm15.bkup $Tm15 2> /dev/null
	mv $Tm16.bkup $Tm16 2> /dev/null
	fi
	
	# negative frequency warning
#	if [ "$neg_freq_counter" -gt 0 ]; then
#		echo "Warning: $neg_freq_counter negative frequencies encountered! see $output_filename" >&2
#	fi

	# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
	for list in $(ls *.substrd)
	do
		if [ -n "$(grep -m 1 HYPH $list)" ]; then
			sed 's/HYPH/-/g' $list > $list-
			mv $list- $list
		fi
	done
	
	exit 0
fi
