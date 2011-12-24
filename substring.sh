#!/bin/bash -

##############################################################################
# substring.sh (c) Andreas Buerki 2011, licensed under the EUPL V.1.1.
version="0.8.2"
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
#				consolidated list now retains document counts and/or other numbers
#				that follow the n-gram frequency, adjusted mktemp command not throw
#				errors under the Xubuntu version



# define help function
help ( ) {
	echo "
Usage:    $(basename $0) [OPTIONS] [-u uncut_list]+ FILE+
Options:  -v verbose (output will not appear on stdout if -v is active)
          -h help
          -o specify an output filename (and location)
          -k keep intermediate files
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


# define rename_to_tmp function
# this function renames all the lists given as arguments into the N.lst format
rename_to_tmp ( ) {
# RENAME LISTS
	if [ "$verbose" == "true" ]; then
		echo "selecting lists"
	fi

	# create a copy of each argument list in the simple N.lst format
	for file in $@
	do
		# extract n of n-gram list
		nsize=$(head -1 $file | awk -v RS="<>" 'END {print NR - 1}')
		# create a copy named N.lst if N is more than 1
		if [ $nsize -gt 1 ]; then
			if [ "$verbose" == "true" ]; then
				echo $nsize.lst
			fi
			# replace any n-gram initial hyphens with 'HYPH'
			sed 's/^-/HYPH/g' < $file > $SCRATCHDIR/$nsize.lst
			# count the number of lists copied
			(( number_of_lists += 1 ))
			
		# if it's not an empty list
		elif [ -s $file ]; then
			echo "Error: format of $file not recognised" >&2
			exit 1
		# if it's an empty list, do nothing
		else
			:
		fi
	done
}


# define prep_stage function
# this function uses uncut (or less severely cut) versions of the input
# lists to improve the accuracy of the frequency consolidation
prep_stage ( ) {

# put name of first arg in variable uncut_list and shift args
uncut_list=$1
shift


#check that nsize of first argument is as expected
if [ "$(head -1 $1 | awk -v RS="<>" 'END {print NR - 1}')" == "$start_list" ]; then
	:
else
	echo "unexpected format in $1"
	exit 1
fi
# use value of start_list as nsize
nsize=$start_list

# initialise variables
total=$(cat $1 | wc -l)
current=0

# inform user
if [ "$verbose" == "true" ]; then
	echo "looking for potentialy missing superstrings"
	echo -n "processing line $current of $total"
fi


for line in $(sed 's/	.*//g' < $1)
	do
		
		# inform user
		if [ "$verbose" == "true" ]; then
		if [ "$current" -lt "10" ]; then
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		elif [ "$current" -lt "100" ]; then
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		else
				(( current +=1 ))
				echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b $current of $total"
		fi
		fi
		# step 1
		# cut off the rightmost word
		# put the number of words to keep in the variable $extent
		# (this would be the n-size of the current list minus 1)
		extent=$(expr $nsize - 1)

		right_cut=$(echo $line | cut -d '<' -f 1-$extent)
		
		# step 2
		# search for a string with anything as leftmost item, followed by
		# the string that had its rightmost word cut off
		# and put the result in the variable 'left_new'
		left_new=$(grep "<>$right_cut" $1 | cut -f 1)
		
	
		if [ -n "$(echo $left_new)" ]; then # check if anything was found
			
			# step 3
			# for each of the lines found,
			# cobble together the projected superstring (that is: the original line with
			# the leftmost word of the string with anything as the leftmost item)
			# and check if it exists in list given as second argument
			for left in $left_new ; do

				superstring=$(grep $(echo "$(echo $left | cut -d '<' -f 1)<>$line") $2)
				
				# step 4
				# check if superstring was found
				if [ -n "$(echo $superstring)" ]; then
					if [ "$hyperverbose" == "true" ]; then
						echo "superstring $superstring exists"
					fi
				else
					if [ "$hyperverbose" == "true" ]; then
						echo "hypothetical superstring $(echo "$(echo $left \
						| cut -d '<' -f 1)<>$line") does not exist."
					fi
					
					# write hypothetical superstrings that could not be found to a list
					echo "$(echo "$(echo $left | cut -d '<' -f 1)<>$line")	not found in $2" \
					>> $SCRATCHDIR/no_superstring.lst
				fi
				done
		fi
		
	done

# insert line break on screen
if [ "$verbose" == "true" ]; then
	echo " "
fi

# use uncut list provided to check no_superstring list against
	if [ "$verbose" == "true" ]; then
		echo "checking no_superstring.lst against $uncut_list ..."
	fi

	if [ -a $SCRATCHDIR/no_superstring.lst ]; then
	for line in $(cut -f 1 $SCRATCHDIR/no_superstring.lst)
		do		
			uncut_superstring=$(grep "$line" $uncut_list)
			
			if [ -n "$(echo $uncut_superstring)" ]; then
				echo $uncut_superstring >> $SCRATCHDIR/transfer.lst
				grep -v "^$line	" $SCRATCHDIR/no_superstring.lst > $SCRATCHDIR/no_superstring.lst.tmp
				mv $SCRATCHDIR/no_superstring.lst.tmp $SCRATCHDIR/no_superstring.lst
			fi
		done
	else
		if [ "$verbose" == "true" ]; then
			echo "no further potential superstrings identifiable."
		fi
	fi


# add the contents of transfer.lst to $2
# which should be the list with longer n-grams
if [ -a $SCRATCHDIR/transfer.lst ]; then
		if [ "$verbose" == "true" ]; then
			echo "restoring contents of transfer.lst to $(basename $2) ..."
		fi
		# take the contents of transfer.lst and restore the tabs
		# that were converted into spaces during processing
		# then add it to $2
		cat $SCRATCHDIR/transfer.lst | sed 's/ /	/g' >> $2
fi

# remove no_superstring.lst and transfer.lst not to interfere wit next iteration
rm $SCRATCHDIR/no_superstring.lst 2> /dev/null
#mv rm $SCRATCHDIR/transfer.lst $HOME/Desktop
rm $SCRATCHDIR/transfer.lst 2> /dev/null
}




# define consolidate function
# this function does the pairwise consolidation of n-gram lists
consolidate ( ) {

if [ "$verbose" == "true" ]; then
	# create variables for user feedback
	total=$(wc -l "$1" | sed 's/^ *\([0-9]*\).*/\1/g')
	currentline=1
fi

# look at things line by line
# spaces in the lines need to be got rid of
# so an underscore is inserted between n-gram, frequency count
# and document count or other remaining numbers
for line in $(sed 's/	/_/g' < "$1")
	do
			# create variable with line frequency of line in argument 1
			freq1=$(echo $line | cut -d "_" -f 2)
			# create variable with any remaining numbers such as document count
			remaining_numbers=$(echo $line | cut -d "_" -f 3-10 | sed -e 's/_/ /g' -e 's/^/ /g')

			# search the second argument for corresponding lines and put
			# their frequency in variable line2freq
			# this must happen in 2 steps to make sure we're not matching
			# unintended strings
			
			# create searchline
			searchline="$(echo $line | sed 's/_[0-9]*//g')"
			
			# match strings that have words to the right of the search string
			freq2_right=$(expr $(grep "^$searchline" "$2" | \
			cut -f 2 | sed 's/^\([0-9]*\)$/\1 +/g') 0)
			
			# match strings that have words to the left or ON BOTH SIDES of the search string
			freq2_left_middle=$(expr $(grep "<>$searchline" "$2" | \
			cut -f 2 | sed 's/^\([0-9]*\)$/\1 +/g') 0)
			
			# add up the frequencies of all matching strings
			freq2=$(expr $freq2_right + $freq2_left_middle)
		
			# this is explained as follows: (starting after report to user)
			# 1 the current line has its freq information cut off
			# 2 a grep search is done with the remaining line 1 in the list given as
			#   second argument
			# 3 the result is piped to cut and only the freq is retained
			# 4 this has a space and a '+' added to it with sed
			# 5 expr is called to evaluate the expression (a '0' is added at
			# 6 the end so that the string to be evaluated doesn't end in a plus
			# 7 the result of the evaluation is retained in the variable freq2
		
		
			# deduct freq from arg 2 line from freq arg 1 line
			# put the new freq-value into the newfreq variable
			newfreq=$(expr $freq1 - $freq2)
			
			# flag up if there are negative frequencies and log them

			if [ $newfreq -lt 0 ]; then
				# echo "Caution: negative frequencies"
				echo $searchline	$newfreq$remaining_numbers >> $neg_freq_list_name
				((neg_freq_counter +=1))
			fi
			
			# now line 1 and its new frequency are written to a temporary file
			# unless the frequency is zero or less, in which case the string is not written
			# unless the -m option was invoked in which case those strings are written
			# as well
			
			# create file so that it is there even if nothing is later written to it
			touch "$1".tmp
			
			if [ "$show_minus_zero_freq" == "true" ] ; then
				echo $searchline	$newfreq$remaining_numbers >> "$1".tmp
			else
				if [ $newfreq -gt 0 ]; then
					echo $searchline	$newfreq$remaining_numbers >> "$1".tmp
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

#################################end define functions########################

# analyse options
while getopts hkmo:u:vV opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	k)	keep_intermediate_files=true
		;;
	m)	show_minus_zero_freq=true # this includes neg_freq sequences in final output
		;;
	o)	special_outdir=$OPTARG
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
		echo "Copyright (c) 2010-2011 Andreas Buerki"
		echo "licensed under the EUPL V.1.1"
		exit 0
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


# check if uncut list was provided
if [ -z "$(echo $uncut1)" ]; then
	# if not, set no_prep_stage to true
	no_prep_stage=true
	if [ "$verbose" == "true" ]; then
		echo "running without preparatory stage"
	fi
	# if uncut list provided, check if (first) uncut list exists and is greater than 0
elif [ -s $uncut1 ]; then
	# check n of uncut lists
	if [ "$verbose" == "true" ]; then
		echo "checking n of uncut lists"
	fi
	i="$number_of_uncut_lists"
	while [ $i -gt 0 ]; do
		if [ -s $(eval echo \$uncut$i) ]; then
			eval nsize_u$i=$(head -1 $(eval echo \$uncut$i) | awk -v RS="<>" 'END {print NR - 1}')
			if [ "$verbose" == "true" ]; then
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
	im1=$(expr $number_of_uncut_lists - 1 )
	while [ $im1 -gt 0 ]; do
		if [ $(eval echo \$nsize_u$i) -eq $(expr $(eval echo \$nsize_u$im1) + 1) ]; then
			(( i -= 1 ))
			(( im1 -= 1 ))
		else
			echo " " >&2
			echo "Error: uncut lists do not appear to have consecutive n-gram lengths." >&2
			exit 1
		fi
	done
	if [ "$verbose" == "true" ]; then
		echo "... test passed"
	fi
	
	# establish n-size of first uncut list 
	# and report error if unsuitable
	uncutnsize=$(head -1 $uncut1 | awk -v RS="<>" 'END {print NR - 1}')
	if [ "$uncutnsize" -lt 3 ]; then
		echo 'Error: the first uncut list must be a list of n-grams such that n > 2' >&2
		exit 1
	fi
else
	# if provided list does not exist report error and exit
	echo "$uncut1 could not be found or is empty" >&2
	exit 1
fi
	
# RENAME n-gram lists into N.lst format and put them in the SCRATCHDIR
rename_to_tmp $@

# check if at least 2 lists were supplied and warn if more than 16 were supplied
if [ $number_of_lists -lt 2 ]; then
	echo "Error: please supply at least two valid n-gram lists" >&2
	usage
	rm -r $SCRATCHDIR
	exit 1
elif [ $number_of_lists -gt 16 ]; then
	echo "Warning: over 16 n-gram lists supplied, this will take time" >&2
fi

# check if lists are consecutive with regard to n-size
if [ "$verbose" == "true" ]; then
	echo "checking whether n of n-gram lists are consecutive"
fi
n=$(expr $number_of_lists + 1)
while [ $n -gt 1 ]; do
	if [ -s $SCRATCHDIR/$n.lst ]; then
		if [ "$verbose" == "true" ]; then
			echo -n "$n "
		fi
		(( n -= 1 ))
	else
		echo " " >&2
		echo "Error: list with $n-grams is missing. Check that n-gram lists of consecutive n are provided." >&2
		exit 1
	fi
done
if [ "$verbose" == "true" ]; then
	echo "... test passed"
fi

# if prep stage is requested,
# check that the greatest n of uncut lists is at most n of cut lists +1 and at least n
if [ "$no_prep_stage" == "true" ]; then
	:
else
	n=$(expr $number_of_lists + 1)
	nu=$(eval echo \$nsize_u$number_of_uncut_lists)
	if [ $n -eq $nu ]; then
		:
	elif [ $(expr $n + 1 ) -eq $nu ]; then
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
		elif [ $(expr $n + 1 ) -eq $nu ]; then
			:
		else
			echo "Error: the largest n of uncut lists is $nu, the largest n of cut lists is $n"  >&2
			exit 1
		fi
	fi
fi

if [ "$no_prep_stage" == "true" ]; then
	if [ "$verbose" == "true" ]; then
		echo "running without preparatory stage"
	fi
else



##### starting prep_stage procedure #####
		
		
		#$number_of_uncut_lists
		
		# establish which list we are starting from
		# that is, one smaller than n-size of first uncut list
		start_list=$(expr $uncutnsize - 1)
		
		# establish next argument up
		next_list=$uncutnsize
		
		#initialise uncut list counter
		uncut_count=1

		
		## start prep_stage loop
		# while a next uncut list exists
		while [ -a "$(eval echo \$uncut$uncut_count)" ]; do
	
	
			# check if files exist
			if [ -a $SCRATCHDIR/$start_list.lst ];then
				:
			else
				echo "Error: $SCRATCHDIR/$start_list.lst does not exist" >&2
				exit 1
			fi
			if [ -a $SCRATCHDIR/$next_list.lst ];then
				:
			else
				# if it does not exist, we create the list
				touch $SCRATCHDIR/$next_list.lst
				(( number_of_lists += 1 ))
			fi
	
			if [ "$verbose" == "true" ]; then
				echo "running prep_stage $(eval echo \$uncut$uncut_count) \
				$start_list.lst $next_list.lst"
			fi
			prep_stage $(eval echo \$uncut$uncut_count) $SCRATCHDIR/$start_list.lst \
			$SCRATCHDIR/$next_list.lst

			# move uncut counter forward
			(( uncut_count += 1 ))
			# move other counters forward
			(( start_list +=1 ))
			(( next_list +=1 ))
	
		done
		
fi

##### end of prep_stage #####

# check if neg_freq.lst exists and put resulting filename in neg_freq_list_name variable
add_to_name neg_freq.lst
neg_freq_list_name="$output_filename"

# check we kept track of number of lists correctly
if [ $number_of_lists -eq "$(ls $SCRATCHDIR/*.lst | wc -l)" ]; then
	:
else
	echo "confusion in number of lists: we counted $number_of_lists, \
	but there are $(ls $SCRATCHDIR/*.lst) lists in $SCRATCHDIR." >&2
	exit 1
fi

# report to user
if [ "$verbose" == "true" ]; then
	echo "$number_of_lists lists to be consolidated"
fi

# name n-gram lists with the 'argN' variable
current=1 # create count variable for naming
for ii in $(ls $SCRATCHDIR/*.lst) # for all lists
	do
		if [ -s $ii ]; then # if they are non empty
			eval arg$current=$ii # create variable with the name of the list
			((current +=1))
		fi
	done

# if list with longest n-grams includes more than one number after n-gram,
# this needs to be removed
if [ -n $(head -1 $(eval echo \$arg$number_of_lists) | cut -f 3) ]; then
	cut -f 1,2 $(eval echo \$arg$number_of_lists) > $(eval echo \$arg$number_of_lists).alt
	mv $(eval echo \$arg$number_of_lists).alt $(eval echo \$arg$number_of_lists)
fi


####### start consolidation #######

# initialise indices
longlistindex="$number_of_lists"
longlistminusindex=$(expr $longlistindex - 1)

# start loops
until [ 1 -gt $longlistminusindex ]
do
	if [ "$verbose" == "true" ]; then
		echo "---------------------------------------------"
		echo "consolidating $(basename $(eval echo \$arg$longlistminusindex)) \
		$(basename $(eval echo \$arg$longlistindex))"
	fi
	consolidate $(eval echo \$arg$longlistminusindex) $(eval echo \$arg$longlistindex)
	
	secondarylonglistindex=$(expr $longlistindex - 1)
	until [ $longlistminusindex -eq $secondarylonglistindex ]; do
		if [ "$verbose" == "true" ]; then
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
# assuming T = 6-grams
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


# assemble final list

# check if target list exists
add_to_name $(echo $(basename $arg1)-$(basename $(eval \
echo \$arg$number_of_lists).substrd))
outlist=$output_filename

list_to_print=$number_of_lists

until [ $list_to_print -lt 1 ]; do
	cat $(eval echo \$arg$list_to_print) >> $SCRATCHDIR/$outlist
	(( list_to_print -= 1 ))
done

# sort output list
sort $SCRATCHDIR/$outlist > $SCRATCHDIR/$outlist.sorted

# if HYPH appears in a list instead of a real hyphen, replace HYPH with -
# if -o option is active, output file to specified directory
# if -v and -o options are off, send list to STOUT so it can be piped
# if -v option is on, but -o is off, write list to default output file
if [ -n "$special_outdir" ]; then
	# check if such a file already exists and change name accordingly
	add_to_name $special_outdir
	special_outdir="$output_filename"
	if [ "$verbose" == "true" ]; then
		echo "writing output list to $special_outdir."
	fi
	if [ -n "$(grep -m 1 HYPH $SCRATCHDIR/$outlist.sorted)" ]; then
		sed 's/HYPH/-/g' $SCRATCHDIR/$outlist.sorted > $special_outdir
	else
		mv $SCRATCHDIR/$outlist.sorted $special_outdir
	fi
elif [ "$verbose" == "true" ]; then
	if [ -n "$(grep -m 1 HYPH $SCRATCHDIR/$outlist.sorted)" ]; then
		sed 's/HYPH/-/g' $SCRATCHDIR/$outlist.sorted > $outlist
	else
		mv $SCRATCHDIR/$outlist.sorted $outlist
	fi
	echo "writing output list to $(pwd)/$outlist."
else # that is, if neither -v nor -o options are active
	 # display the result (so it can be piped by the user)
	if [ -n "$(grep -m 1 HYPH $SCRATCHDIR/$outlist.sorted)" ]; then
		sed 's/HYPH/-/g' $SCRATCHDIR/$outlist.sorted
	else
		cat $SCRATCHDIR/$outlist.sorted
	fi
fi
######## end of consolidation procedure

# if -k option is active, move intermediate files to a special directory in the pwd
if [ "$keep_intermediate_files" == "true" ]; then
	add_to_name intermediate_files
	mkdir $output_filename
	if [ "$verbose" == "true" ]; then
		echo "moving intermediate files to $output_filename"
	fi
	mv $SCRATCHDIR/* $output_filename/
fi

# delete temp directory
rm -r $SCRATCHDIR

# negative frequency warning
if [ -n "$neg_freq_counter" ]; then
	echo "$neg_freq_counter negative frequencies encountered. see $neg_freq_list_name"  >&2
fi
# display time of completion
if [ "$verbose" == "true" ]; then
	echo "operation completed $(date)."
fi
