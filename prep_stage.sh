#!/bin/bash -

##############################################################################
# prep_stage.sh (c) Andreas Buerki 2010-2011, licensed under the EUPL V.1.1.
####
# DESCRRIPTION: runs overlap.sh -vru for all lists given as arguments
# SYNOPSIS: prep_stage.sh [-v] -u uncut_list input_lists
#
# OPTIONS:
# -v	verbose mode
# -u ARG	mandatory option; provide uncut list as argument to -u
# -n    no_superstring.lst retained (for diagnostic purposes)
# -t    transfer.lst retained (for diagnostic purposes)
#
# NOTES: this script only works if lists are named like this: N.anything (i.e.
#        starting with the N-size, followed by a dot and anything after that
#
#
#
##############################################################################
# History
# date			change
# 21/09/2010	integrated overlap.sh as function and added -t option
# 11/01/2011	made progress information update on the spot and have the script
#				exit more gracefully (w/o errors) when there are no more superstrings
# 22/04/2011	renamed script to prep_stage.sh (previously it was named super_overlap.sh)
# 30/04/2011	errors channelled to stderr
###

#### define functions
help ( ) {
	echo "
Usage: $(basename $0) [-v] -u uncut_list input_lists
Example: $(basename $0) -vu 5.lst.cut.1.1 4.lst 5.lst 6.lst 7.lst
Options: 
-v	verbose mode
-u ARG	mandatory option; provide uncut list as argument to -u
-n    no_superstring.lst retained (for diagnostic purposes)

note: assumes that lists are named in this format: N.anything
      where N is n-gram length
"
}


usage ( ) {
	help
}


getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}


overlap ( ) {
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

# if the -u option is active, use to uncut list provided to check the no_superstring list against
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

# end of functions





# analyse options
while getopts hvu:nt opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	v)	verbose=true
		;;
	V)	hyperverbose=true
		verbose=true
		;;
	u)	use_uncut=true
		uncut_list=$OPTARG
		;;
	n)	retain_nosuperstring=true
		;;
	t)	retain_transfer_lists=true
		;;
	esac
done

shift $((OPTIND -1))





# check if uncut list was provided
if [ -z "$uncut_list" ]; then
	echo "Error: please provide an uncut list with -u ARG" >&2
	exit 1
fi

# check if arguments exist
if [ -a $uncut_list ];then
	:
else
	echo "Error: $uncut_list does not exist" >&2
	exit 1
fi
if [ -a $1 ];then
	:
else
	echo "Error: $1 does not exist" >&2
	exit 1
fi
if [ -a $2 ];then
	:
else
	echo "Error: $2 does not exist" >&2
	exit 1
fi




# extract naming format for uncut_list
uncut_format=$(echo $uncut_list | cut -d "." -f 2-20)

# establish n-gram length of $1
nsize=$(echo $2 | cut -d "." -f 1)


# check if at least 2 arguments left
if [ -z "$2" ]; then
	echo "Error: provide at least 2 arguments" >&2
	exit 1
fi

cp $2 $2.bkup

restore=true
overlap $uncut_list $1 $2

if [ "$retain_nosuperstring" == "true" ]; then
	mv no_superstring.lst no_superstring.lst.$nsize
else
	rm no_superstring.lst 2> /dev/null
fi

if [ "$retain_transfer_lists" == "true" ]; then
	mv transfer.lst transfer.lst.$nsize
else
	rm transfer.lst
fi


# move arguments on by one
shift

while [ -n "$2" ]; do
	
	(( nsize += 1 ))
	
	# check if files exist
	if [ -a $2 ];then
		:
	else
		echo "Error: $2 does not exist" >&2
		exit 1
	fi
	if [ -a $nsize.$uncut_format ];then
		:
	else
		echo "Error: $nsize.$uncut_format does not exist" >&2
		exit 1
	fi
	
	
	cp $2 $2.bkup
	
	overlap $nsize.$uncut_format $1.o $2


	if [ "$retain_nosuperstring" == "true" ]; then
		mv no_superstring.lst no_superstring.lst.$nsize
	else
		rm no_superstring.lst 2> /dev/null
	fi

	if [ "$retain_transfer_lists" == "true" ]; then
		mv transfer.lst transfer.lst.$nsize
	else
		rm transfer.lst 2> /dev/null
	fi
	
	# move arguments on by one
	shift
done


if [ "$verbose" == "true" ]; then
	echo "complete."
fi