#!/bin/bash -

##############################################################################
# substrd.sh (c) Andreas Buerki 2011, licensed under the EUPL V.1.1.
####
# DESCRRIPTION: performs frequency consolidation among different length n-grams
#				for options see -h
# SYNOPSIS: 	substrd.sh [OPTIONS] directory cutoff-regex
#				in case of -m option, the arguments need to be specified instead
#				of the regex: 
#				substrd.sh [OPT] -u uncut_list [-u uncut_list] dir args
# DEPENDENCIES: cutoff.sh / prep_stage.sh / core_substring.sh
##############################################################################
# history
# date			change
# 13/01/2011	added -d option
# 05/02/2011	added -u and -s options
# 31/03/2011    removed -d option and renamed script to substrd.sh
# 19/04/2011	added options -3 and -c and changed bit where super-overlap is
#				called (it now is sensitive to presence or absence of lists from
#				5.lst upwards, rather than assuming lists are present to 7.lst)
# 20/04/2011	adjusted -o option to just omit prep_stage.sh, but execute
#				the remaining steps, built a check into the automatic routine
#				to give warnings if filenames result in a conflict.
# 29/04/2011	added automatic activation of -o option if no 5-gram lists
#				are present, output is now displayed on screen unless the -v
#				option is active and intermediate lists are deleted unless the
#				-k option is active. -s option renamed into -m.
# 30/04/2011	moved all error messages to stderr



# define help function
help ( ) {
	echo "
Usage:    $(basename $0) [OPTIONS] DIRECTORY cutoff-regex
		  in case of -m option, the arguments need to be specified instead
		  of the regex: 
		  $(basename $0) [OPTIONS] -u uncut_list [-u uncut_list] DIRECTORY args
Options:  -v verbose (output will not appear on stdout if -v is active)
          -h help
          -c REGEX cutoff-regex for uncut lists
          -3 uncut lists automatically cut at frequency 3
          -r only execute renaming stage
          -o omits prep_stage.sh
          -n omits core_substring.sh
          -u use uncut list[s] provided (includes -m option)
          -m manual mode (all input lists must be specified)
          -k keep intermediate files
Notes:	  the output is put in a .substrd file in the DIRECTORY provided. Unless
		  the -v option is active, output is additionally sent to stdout
		  if neither -c nor -3 options are invoked, the preparatory stage is run with an automatic cutoff frequency of 1.
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


# define exists function (checks if target files exists)
exists ( ) {
if [ -a $1 ] ; then
	echo "$1 exists. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $1
	elif [ $GETCH == n ] ; then
		mv $1 $1.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi
}

# define rename_open function
# this function renames all the lists given as arguments into the N.lst format
rename_open ( ) {
# RENAME LISTS
	if [ "$verbose" == "true" ]; then
		echo "renaming lists"
	fi
	# putting names of files to be copied into the to_copy variable (cut lists)
	to_copy=$@
	# create a copy of each argument list in the simple N.lst format
	for file in $to_copy
	do
		# extract N
		N=$(head -1 $file | awk -v RS=">" 'END {print NR - 1}')
		# create a copy named N.lst if N is more than 1
		if [ $N -gt 1 ]; then
			if [ "$verbose" == "true" ]; then
				echo creating $N.lst
			fi
			cp $file $N.lst 2> /dev/null
		elif [ -s $file ]; then
			echo "Error: format of $file not recognised" >&2
			exit 1
		else
			:
		fi
	done
}

# define rename function
# this function renames all files ending in ')' into the N.lst format
rename ( ) {
# RENAME LISTS
	if [ "$verbose" == "true" ]; then
		echo "renaming lists"
	fi
	# putting names of files to be copied into the to_copy variable (cut lists)
	to_copy=$(ls *\))
	
	# create a copy of each list in the simple N.lst format
	for file in $to_copy
	do
		# extract N
		N=$(head -1 $file | awk -v RS=">" 'END {print NR - 1}')
		# create a copy named N.lst if N is more than 1
		if [ $N -gt 1 ]; then
			if [ "$verbose" == "true" ]; then
				echo creating $N.lst
			fi
			exists $N.lst 
			cp $file $N.lst
		fi
	done
	# putting names of files to be copied into the to_copy variable (uncut lists)
	

	to_copy=$(ls *\.1)

	# create a copy of each uncut list in the N.uncut.lst format
	if [ "$omit_superoverlap" = "true" ]; then
		:
	else
	for file in $to_copy
	do
		# extract N
		Nbar=$(head -1 $file | awk -v RS=">" 'END {print NR - 1}')
		# create a copy named N.lst
		if [ "$verbose" == "true" ]; then
			echo creating $Nbar.uncut.lst
		fi
		exists $Nbar.uncut.lst
		cp $file $Nbar.uncut.lst
	
		# if no N.lst was created, but an Nbar list, create empty N.lst
		if [ -e $Nbar.lst ]; then
			:
		else
			if [ "$verbose" == "true" ]; then
				echo creating $Nbar.lst
			fi
			exists $Nbar.lst
			touch $Nbar.lst
		fi
	done
	fi
}

overlap ( ) {
# this function is identical to overlap.sh except that lines 1-108 were
# replaced by the three lines of code immediately below.

# put name of first arg in variable uncut_list and shift args
uncut_list=$1
shift


# check if target lists exists
if [ -a $2.o ] ; then
	echo "$2.o exist. overwrite? (y/n/exit)" >&2
	getch
	if [ $GETCH == y ] ; then
		rm $2.o
	elif [ $GETCH == n ] ; then
		mv $2.o $2.o.bkup
		echo "appended .bkup to original list" >&2
	else
		echo "exited without changing anything" >&2
		exit 0
	fi
fi


# initialise variables
list_n_size=$(head -1 $1 | awk -v RS=">" 'END {print NR - 1}')
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
		#if [ "$verbose" == "true" ]; then
		#	
		#	echo "processing line $current of $total"
		#fi
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
		
		# step 1
		# cut off the rightmost word
		# put the number of words to keep in the variable $extent
		# (this would be the n-size of the current list minus 1
		extent=$(expr $list_n_size - 1)

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
			for left in $left_new
				do




				
				
				
				
				superline=$(grep $(echo "$(echo $left | cut -d '<' -f 1)<>$line") $2)
				
				
				# step 4
				# check if projected superstring exists
				if [ -n "$(echo $superline)" ]; then
					if [ "$hyperverbose" == "true" ]; then
						echo "superline $superline exists"
					fi
				else
					if [ "$hyperverbose" == "true" ]; then
						echo "predicted superline $(echo "$(echo $left \
						| cut -d '<' -f 1)<>$line") does not exist."
					fi
					
					# write projected superstrings that could not be found to a list
					echo "$(echo "$(echo $left | cut -d '<' -f 1)<>$line")	not found in $2" \
					>> no_superstring.lst
				fi
				done
		fi
		
	done

# insert line break on screen
echo " "

# if the -u option is active, use uncut list provided to check no_superstring list against
if [ "$use_uncut" == "true" ]; then

	if [ "$verbose" == "true" ]; then
		echo "checking no_superstring.lst against $uncut_list ..."
	fi

	if [ -a no_superstring.lst ]; then
	for line in $(cut -f 1 no_superstring.lst)
		do
		
			real_superline=$(grep "$line" $uncut_list)
			
			if [ -n "$(echo $real_superline)" ]; then
				echo $real_superline >> transfer.lst
				grep -v "^$line	" no_superstring.lst > no_superstring.lst.tmp
				mv no_superstring.lst.tmp no_superstring.lst
			fi
		done
	else
		if [ "$verbose" == "true" ]; then
			echo "no further potential superstrings identifiable."
		fi
	fi
fi


# if the -r option is active, add the contents of transfer.lst to $2
# which should be the larger list
if [ "$restore" == "true" ]; then
	if [ -a transfer.lst ]; then
		if [ "$verbose" == "true" ]; then
			echo "restoring contents of transfer.lst to $2 ..."
		fi
		# take the contents of transfer.lst and restore the tabs
		# that were converted into spaces during processing
		# then add it to $2
		cat transfer.lst | sed 's/ /	/g' >> $2
	fi
	mv $2 $2.o

fi

}

#################################end define functions########################

# analyse options
while getopts hvronc:13u:m opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	v)	verbose=true
		;;
	r)	rename=true
		;;
	o)	omit_superoverlap=true
		;;
	n)	omit_substring=true
		;;
	1)	uncut_1=true
		;;
	3)	uncut_3=true
		;;
	c)	cut_regex=$OPTARG
		;;
	u)	(( iteration += 1 ))
		if [ $iteration -eq 1 ]; then
			uncut1=$OPTARG
		elif [ $iteration -eq 2 ]; then
			uncut2=$OPTARG
		elif [ $iteration -eq 3 ]; then
			uncut3=$OPTARG
		elif [ $iteration -eq 4 ]; then
			uncut4=$OPTARG
		elif [ $iteration -eq 5 ]; then
			uncut5=$OPTARG
		else
			echo "no more than 5 uncut lists allowed" >&2
			exit 1
		fi
		specify=true
		use_uncut=true
		;;
	m)	specify=true
		;;
	k)	keep_intermediate_files=true
		;;
	esac
done

shift $((OPTIND -1))

#change to action directory
cd $1

if [ "$rename" == "true" ]; then
	rename
	exit 0
fi

###################### procedure for -m option #################################
if [ "$specify" == "true" ]; then
	if [ "$verbose" == "true" ]; then
		echo "running with specified lists"
	fi
	# check if uncut list was provided
	if [ -z "$(echo $uncut1)" ]; then
		# if not, set no_superoverlap to true
		no_superoverlap=true
		if [ "$verbose" == "true" ]; then
			echo "no uncut list provided"
		fi
	# if provided, check if (first) provided uncut list exists
	elif [ -a $uncut1 ]; then
		# if so, establish n-size of first uncut list 
		# and report error if unsuitable
		uncutlist_n_size=$(head -1 $uncut1 | awk -v RS=">" 'END {print NR - 1}')
		if [ "$uncutlist_n_size" -lt 3 ]; then
			echo "Error: the first uncut list must a 3-gram list or longer" >&2
			exit 1
		fi
	else
		# if provided list does not exist report error and exit
		echo "$uncut1 could not be found" >&2
		exit 1
	fi

	
	# shift past first arg which is directory
	shift
	
	# put remaining arguments in variable lists
	arg_lists="$@"
	export arg_lists
	
	# put number of arguments in variable num_of_lists
	num_of_lists=$(echo $lists | wc -w)
	
	
	
	# RENAME lists into N.lst format
	rename_open $arg_lists

	
	
	
	if [ "$no_superoverlap" == "true" ]; then
		if [ "$verbose" == "true" ]; then
			echo "no uncut lists being considered"
		fi
	else
		### super_overlap procedure
		
		# establish which list we are starting from
		# that is, one smaller than n-size of first uncut list
		startarg=$uncutlist_n_size
		(( startarg -=1 ))
		
		# establish next argument up
		nextarg=$startarg
		(( nextarg +=1 ))
		
		# check if arguments exist
		if [ -a $startarg.lst ];then
			:
		else
			echo "Error: $startarg.lst does not exist" >&2
			exit 1
		fi
		if [ -a $nextarg.lst ];then
			:
		else
			echo "Error: $nextarg.lst does not exist" >&2
			exit 1
		fi
	
		## run first iteration of overlap
		cp $nextarg.lst $nextarg.lst.bkup

		# set correct settings for overlap function
		use_uncut=true
		restore=true
		if [ "$verbose" == "true" ]; then
			echo "running overlap $uncut1 $startarg.lst $nextarg.lst"
		fi
		overlap $uncut1 $startarg.lst $nextarg.lst
		
		rm no_superstring.lst 2> /dev/null
		rm transfer.lst 2> /dev/null
		
		## start overlap loop

		#initialise uncut list counter
		uncut_count=2

		# while a next uncut list exists
		while [ -a "$(eval echo \$uncut$uncut_count)" ]; do
	
			# move counts forward
			(( startarg +=1 ))
			(( nextarg +=1 ))
	
			# check if files exist
			if [ -a $startarg.lst.o ];then
				:
			else
				echo "Error: $startarg.lst.o does not exist" >&2
				exit 1
			fi
			if [ -a $nextarg.lst ];then
				:
			else
				echo "Error: $nextarg.lst does not exist" >&2
				exit 1
			fi
	
	
			cp $nextarg.lst $nextarg.lst.bkup
	
			if [ "$verbose" == "true" ]; then
				echo "running overlap $(eval echo \$uncut$uncut_count) $startarg.lst.o $nextarg.lst"
			fi
			overlap $(eval echo \$uncut$uncut_count) $startarg.lst.o $nextarg.lst

			rm no_superstring.lst 2> /dev/null
			rm transfer.lst 2> /dev/null
			
			# move uncut counter forward
			(( uncut_count += 1 ))
	
		done
		
		# convert .o lists back to regular name
		for file in $(ls *.o)
		do
			new_name=$(echo $file | cut -d '.' -f 1-2)
			mv $file $new_name
		done
	fi
	
	if [ "$verbose" == "true" ]; then
		echo "running core_substring.sh -v"
		core_substring.sh -v \
		$(if [ -a 2.lst ]; then echo 2.lst; fi) \
		$(if [ -a 3.lst ]; then echo 3.lst; fi) \
		$(if [ -a 4.lst ]; then echo 4.lst; fi) \
		$(if [ -a 5.lst ]; then echo 5.lst; fi) \
		$(if [ -a 6.lst ]; then echo 6.lst; fi) \
		$(if [ -a 7.lst ]; then echo 7.lst; fi) \
		$(if [ -a 8.lst ]; then echo 8.lst; fi) \
		$(if [ -a 9.lst ]; then echo 9.lst; fi)
	else
		core_substring.sh \
		$(if [ -a 2.lst ]; then echo 2.lst; fi) \
		$(if [ -a 3.lst ]; then echo 3.lst; fi) \
		$(if [ -a 4.lst ]; then echo 4.lst; fi) \
		$(if [ -a 5.lst ]; then echo 5.lst; fi) \
		$(if [ -a 6.lst ]; then echo 6.lst; fi) \
		$(if [ -a 7.lst ]; then echo 7.lst; fi) \
		$(if [ -a 8.lst ]; then echo 8.lst; fi) \
		$(if [ -a 9.lst ]; then echo 9.lst; fi)
	fi
	
	# inform user
	if [ "$verbose" == "true" ]; then
		echo "operation completed $(date)."
	fi
	
	# unless in verbose mode, display the result (so it can be piped by the user)
	if [ "$verbose" == "true" ]; then
		:
	else
		cat *substrd
	fi
	
	exit 0
fi

###################### END procedure for -m option #############################

# put names of original files in variable
original_files=$(ls *)

if [ "$verbose" == "true" ]; then
	echo "preparing to consolidate the following lists:"
	echo "$original_files"
fi

# check if -o option should be active because there are no 5-grams
for file in ./*
	do
		# extract N
		N=$(head -1 $file | awk -v RS=">" 'END {print NR - 1}')
		# if N=5 found, set variable $found to 1 and break out of loop
		if [ $N -eq 5 ]; then
			found=1
			break
		else
			found=0
		fi
	done

if [ "$found" == "0" ]; then
	omit_superoverlap=true
fi



# if -o option is active
if [ "$omit_superoverlap" == "true" ]; then
	# if -o active, CUTOFF only main lists
	if [ "$verbose" == "true" ]; then
		echo "running cutoff.sh -d 1 -f $2 $(ls *)"
	fi
	cutoff.sh -d 1 -f $2 *

# if -o option is NOT active
else

	# CUTOFF uncut lists
	if [ "$uncut_3" == "true" ]; then
		if [ "$verbose" == "true" ]; then
			echo "running cutoff.sh -d 1 -f '([1-3])' *"
		fi
		cutoff.sh -d 1 -f '([1-3])' *

	elif [ -n "$cut_regex" ]; then
		if [ "$verbose" == "true" ]; then
			echo "running cutoff.sh -d 1 -f $cut_regex *"
		fi
		cutoff.sh -d 1 -f $cut_regex *
	else
		if [ "$verbose" == "true" ]; then
			echo "running cutoff.sh -d 1 -f 1 *"
		fi
		cutoff.sh -d 1 -f 1 *
	fi


	# CUTOFF main lists
	if [ "$verbose" == "true" ]; then
		echo "running cutoff.sh -f $2 *\.1"
	fi
	# check if more than 9 lists ending in .1
	if [ "$(ls *\.1 | wc -w)" -gt "9" ]; then
		echo "POTENTIAL FILE NAME CONFLICT: there are more than 9 lists ending in .1 ($(ls *\.1)" >&2
		echo "Is this correct? (y/n)" >&2
		getch
		if [ $GETCH == y ] ; then
			:
		elif [ $GETCH == n ] ; then
			echo "exiting..." >&2
			exit 1
		else
			echo "exited without changing anything" >&2
			exit 0
		fi
	fi
	cutoff.sh -f $2 *\.1
fi


# RENAME LISTS
# if target names exist, append 'original' to their name
if [ -a 2.lst ]; then
	mv 2.lst 2.original.lst
fi
if [ -a 3.lst ]; then
	mv 3.lst 3.original.lst
fi
if [ -a 4.lst ]; then
	mv 4.lst 4.original.lst
fi
if [ -a 5.lst ]; then
	mv 5.lst 5.original.lst
fi
if [ -a 6.lst ]; then
	mv 6.lst 6.original.lst
fi
if [ -a 7.lst ]; then
	mv 7.lst 7.original.lst
fi
if [ -a 8.lst ]; then
	mv 8.lst 8.original.lst
fi
if [ -a 9.lst ]; then
	mv 9.lst 9.original.lst
fi

# now rename
# if -o option is active
if [ "$omit_superoverlap" == "true" ]; then
	rename_open *1
	
# if -o option is NOT active
else
	rename 
fi

# checking if 5.lst exists
if [ -a 5.lst ]; then 
	:
else
	# if not, -o must be turned on if it's not already
	if [ "$omit_superoverlap" == "true" ]; then
		:
	else
		omit_superoverlap=true
		# inform user
		echo "no 5-grams were found. This is either because no 5-gram was specified or because there are no 5-grams at the cutoff chosen. The preparatory stage is skipped." >&2
	fi
fi

# SUPER_OVERLAP
if [ "$omit_superoverlap" = "true" ]; then
	:
else
	if [ "$verbose" == "true" ]; then
		echo "running prep_stage.sh -vu 5.uncut.lst 4.lst 5.lst $(if [ -a 6.lst ]; then echo 6.lst; fi) $(if [ -a 7.lst ]; then echo 7.lst; fi) $(if [ -a 8.lst ]; then echo 8.lst; fi) $(if [ -a 9.lst ]; then echo 9.lst; fi)"
		prep_stage.sh -vu 5.uncut.lst 4.lst 5.lst \
		$(if [ -a 6.lst ]; then echo 6.lst; fi) \
		$(if [ -a 7.lst ]; then echo 7.lst; fi) \
		$(if [ -a 8.lst ]; then echo 8.lst; fi) \
		$(if [ -a 9.lst ]; then echo 9.lst; fi)
		# exit if there was an error
		if [ $? -ne 0 ]; then
			exit 1
		fi
	else
		prep_stage.sh -u 5.uncut.lst 4.lst 5.lst \
		$(if [ -a 6.lst ]; then echo 6.lst; fi) \
		$(if [ -a 7.lst ]; then echo 7.lst; fi) \
		$(if [ -a 8.lst ]; then echo 8.lst; fi) \
		$(if [ -a 9.lst ]; then echo 9.lst; fi)
		# exit if there was an error
		if [ $? -ne 0 ]; then
			exit 1
		fi
	fi

	# convert .o lists back to regular name
	for file in $(ls *.o)
	do
		new_name=$(echo $file | cut -d '.' -f 1-2)
		mv $file $new_name
	done
fi

# SUBSTRING
if [ "$omit_substring" = "true" ]; then
	echo "complete"
	exit 0
else
	if [ "$verbose" == "true" ]; then
		echo "running core_substring.sh -v"
		core_substring.sh -v \
		$(if [ -a 2.lst ]; then echo 2.lst; fi) \
		$(if [ -a 3.lst ]; then echo 3.lst; fi) \
		$(if [ -a 4.lst ]; then echo 4.lst; fi) \
		$(if [ -a 5.lst ]; then echo 5.lst; fi) \
		$(if [ -a 6.lst ]; then echo 6.lst; fi) \
		$(if [ -a 7.lst ]; then echo 7.lst; fi) \
		$(if [ -a 8.lst ]; then echo 8.lst; fi) \
		$(if [ -a 9.lst ]; then echo 9.lst; fi)
	else
		core_substring.sh \
		$(if [ -a 2.lst ]; then echo 2.lst; fi) \
		$(if [ -a 3.lst ]; then echo 3.lst; fi) \
		$(if [ -a 4.lst ]; then echo 4.lst; fi) \
		$(if [ -a 5.lst ]; then echo 5.lst; fi) \
		$(if [ -a 6.lst ]; then echo 6.lst; fi) \
		$(if [ -a 7.lst ]; then echo 7.lst; fi) \
		$(if [ -a 8.lst ]; then echo 8.lst; fi) \
		$(if [ -a 9.lst ]; then echo 9.lst; fi)
	fi
fi

if [ "$verbose" == "true" ]; then
	echo "operation completed $(date)."
fi

# unless in verbose mode, display the result (so it can be piped by the user)
if [ "$verbose" == "true" ]; then
	:
else
	cat *substrd
fi

# tidy up directory unless -k option is active
if [ "$keep_intermediate_files" == "true" ]; then
	:
else
	mkdir keep
	mv $original_files keep
	mv *bkup keep 2> /dev/null
	mv *substrd keep 2> /dev/null
	mv *neg_freq* keep 2> /dev/null
	rm * 2> /dev/null
	mv keep/* .
	rm -r keep
fi