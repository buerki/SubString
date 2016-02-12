#!/bin/bash -
##############################################################################
# TP_filter.sh
copyright="Copyright (c) 2016 Cardiff University, 2009, 2013-2015 Andreas Buerki"
# licensed under the EUPL V.1.1.
version='0.8.6'
####
# DESCRRIPTION: provides a interface for manual TP-FP filtering
# SYNOPSIS:     TP-filter.sh FILE
# NOTES: 		
# OPTIONS: 	    none
##############################################################################
# date		 v.		change
# 2013-12-27 0.8	added proper handling of lines that include underscores
# 2015-05-10 0.8.3	added -t option

# define help function
help ( ) {
	echo "
Usage: $(basename $0) [OPTIONS] FILE
example: $(basename $0) joined.tidy
options: -r only displays result (several argument files may be provided)
         -t display result in terms of tokens
         -o use other rating scheme, not TP/FP
         -h help
         -V display version information
"
}
# define getch function (reads the first character input from the keyboard)
getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}
# define get_tokens function
get_tokens ( ) {
TP=$(echo "$(grep "T$" $1 | cut -f 2 | sed 's/$/ +/g' ) 0" | tr '\n' ' '| sed 's/  / /g' |bc)
FP=$(echo "$(grep "F$" "$1" | cut -f 2 | sed 's/$/ +/g' ) 0" | tr '\n' ' '| sed 's/  / /g' |bc)
U=$(echo "$(grep "U$" "$1" | cut -f 2 | sed 's/$/ +/g' ) 0" | tr '\n' ' '| sed 's/  / /g' |bc)
total=$(echo "$TP + $FP + $U" | bc)
}
# define get_types function
get_types ( ) {
TP=$(grep "T$" "$1" | wc -l | sed 's/ //g')
FP=$(grep "F$" "$1" | wc -l | sed 's/ //g')
U=$(grep "U$" "$1" | wc -l | sed 's/ //g')
total=$(expr $TP + $FP + $U)
}
# define get_categories function
get_categories ( ) {
cats=$(sed 's/.*\(.\)$/\1/g' "$1" | sort | uniq)
}
# define report_categories function
report_categories ( ) {
for cat in $cats;do
	if [ "$tokens" ]; then
		stat=$(echo "$(grep "$cat$" "$1" | cut -f 2 | sed 's/$/ +/g' ) 0" | tr '\n' ' '| sed 's/  / /g' |bc)
		total=$(echo "$(cut -f 2 "$1" | sed 's/$/ +/g' ) 0" | tr '\n' ' '| sed 's/  / /g' |bc)
	else
		stat=$(grep "$cat$" "$1" | wc -l | sed 's/ //g')
		total=$(wc -l < "$1")
	fi
	echo "   $cat                 $(echo "$stat * 100 / $total" | sed 's/ //g' | bc)% ($stat items)"
done
}
# define secondary_menu function
secondary_menu ( ) {
					printf "\033c"
					echo " "
					echo " "
					echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
					echo " "
					echo " "
					if [ -z "$other" ]; then
						echo "          (t) designate true"
						echo "          (f) designate false"
					fi
					echo "          (s) skip current item"
}
############### END defining functions ########################################

# analyse options
while getopts hVort opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "licensed under the EUPL V.1.1"
		echo "written by Andreas Buerki"
		exit 0
		;;
	o)	other=true
		;;
	r)	results_only=true
		;;
	t)	tokens=true
		;;
	esac
done
shift $((OPTIND -1))
# check if files exist and, unless -r option active, no more than 1 file is provided
for file; do
	if [ -e "$file" ]; then
		:
	else
		echo "$file not found"
		exit 1
	fi
done
if [ $# -gt 1 ] && [ -z "$results_only" ]; then
	echo "only the first argument list will be processed" >&2
fi
# check if list has been processed
if [ -z "$other" ] && [ -n "$(head -n 1 "$1" | egrep "[TFU]$" | cut -f 1 )" ] ; then
	resume=true
elif [ "$other" ] && [ "$(head -n 1 "$1" | egrep "[[:alpha:]]$" | cut -f 1 )" ]; then
	resume=true
fi
################## process for results-only option ############################
if [ "$results_only" ]; then
	if [ "$other" ]; then echo "-r option not available in conjuction with -o."
>&2;exit 0;fi
	echo "file / TPs / % / undecided $(if [ "$tokens" ]; then echo "  (tokens)";fi)"
	for file; do
		# check if files were processed and issue error if not
		if [ -n "$(head -n 1 "$file" | egrep "[TFU]$" | cut -f 1 )" ] ; then
			# prepare statistics
			if [ "$tokens" ]; then
				get_tokens "$file"
			else
				get_types "$file"
			fi
			echo "$(basename "$file") / $TP / $(expr \( $TP \* 100 \) / $total )% / $U"
		else
			echo "$file is not TP annotated ----------"
		fi
	done
	exit 0
fi
################## END process for results-only option #######################
if [ "$resume" == "true" ]; then
	# prepare statistics
	if [ "$other" ]; then
		get_categories "$1"
	else
	# prepare statistics
		if [ "$tokens" ]; then
			get_tokens "$1"
		else
			get_types "$1"
		fi
	fi
	printf "\033c"
	echo " "
	echo " "
	echo "statistics so far:$(if [ "$tokens" ]; then echo "  (tokens)";fi)"
	echo " "
	echo " "
	if [ "$other" ]; then
		report_categories "$1"
	else
		echo "                     $(expr \( $TP \* 100 \) / $total )% ($TP items) TP"
		echo "                     $(expr \( $FP \* 100 \) / $total )% ($FP items) FP"
		echo "                     $(expr \( $U \* 100 \) / $total )% ($U items) undecided"
	fi
	echo " "
	echo " "
	echo "resuming $(if [ -z "$other" ]; then echo "TP filtering ";fi)in 1 second"
	echo " "
	echo " "
	echo " "
	sleep 1
	# backup original list
	cp "$1" $1.bkup
	# check if target list exists
	if [ -a "$1.tpfltd" ] ; then
		echo "$1.tpfltd exists. overwrite? (y/n)"
		getch
		if [ $GETCH == y ] ; then
			rm "$1.tpfltd"
		else
			echo "exited without changing anything"
			exit 0
		fi
	fi
	# put lines already processed into the new output file
	egrep "[^U]$" $1.bkup > "$1.tpfltd"
	# put undecided lines into a tmp file and replace tabs with underscores
	egrep "U$" $1.bkup | sed 's/	.$//g' | sed -e 's/_/UNDERSCORE/g' -e 's/	/_/g'  > "$1.tmp"
else
	# create tmp file with underscores instead of tabs
	sed -e 's/_/UNDERSCORE/g' -e 's/	/_/g' "$1" > "$1.tmp"

	# check if target list exists
	if [ -a "$1.tpfltd" ] ; then
		echo "$1.tpfltd exists. overwrite? (y/n)"
		getch
		if [ $GETCH == y ] ; then
			rm "$1.tpfltd"
		else
			echo "exited without changing anything"
			exit 0
		fi
	fi
fi
# start time
start=$(date)
# start for in loop
for line in $(cat "$1.tmp")
do
	(( progress += 1 ))
	if [ "$copyundesignatedly" ] ; then
		echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
	else
		printf "\033c"
		echo $progress
		echo " "
		echo " "
		echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
		echo " "
		echo " "
		if [ "$other" ]; then
			echo "      Enter designation or one of the following commands:"
		else
			echo "          (t) designate true"
			echo "          (f) designate false"
		fi
		echo "          (s) | (u) skip current item"
		echo "          (b) back to previous item"
		echo " "
		echo "          (r) review all designations up to now"
		echo "          (l) resume later"
		echo "          (x) exit and discard all designations"
		getch
			case $GETCH in
			t|T)	echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					;;
			f|F)	echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					;;
			s|S)	echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					;;
			b|B)	printf "\033c"
					previous=$(tail -n 1 "$1.tpfltd")
					echo "previous item was"
					echo " "
					echo "$(echo "$previous" | cut -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g')   $( echo "$previous" | sed 's/.*\(.\)/\1/g')"
					echo " "
					echo " "
					echo " "
					if [ -z "$other" ]; then 
						echo "          (t) change to true"
						echo "          (f) change to false"
					fi
					echo "          (u) change to undesignated"
					echo "          (n) no change, carry on"
					getch
						case $GETCH in
						t|T)	sed '$d' < "$1.tpfltd" > $TMPDIR/TPtmp ; mv $TMPDIR/TPtmp "$1.tpfltd"
								echo "$(echo $previous | sed 's/	.$//g')	T" >> "$1.tpfltd"
								printf "\033c"
								secondary_menu
								getch
								if [ $GETCH == t ] ; then
									echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								elif [ $GETCH == f ] ; then
									echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								else
									echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								fi
								;;
						f|F)	sed '$d' < "$1.tpfltd" > $TMPDIR/TPtmp ; mv $TMPDIR/TPtmp "$1.tpfltd"
								echo "$(echo $previous | sed 's/	.$//g')	F" >> "$1.tpfltd"
								printf "\033c"
								secondary_menu
								getch
								if [ $GETCH == t ] ; then
									echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								elif [ $GETCH == f ] ; then
									echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								else
									echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								fi
								;;
						u|U)	sed '$d' < "$1.tpfltd" > $TMPDIR/TPtmp ; mv $TMPDIR/TPtmp "$1.tpfltd"
								echo "$(echo $previous | sed 's/	.$//g')	U" >> "$1.tpfltd"
								printf "\033c"
								secondary_menu
								getch
								if [ $GETCH == t ] ; then
									echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								elif [ $GETCH == f ] ; then
									echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								else
									echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								fi
								;;
						n|N)	printf "\033c"
								secondary_menu
								getch
								if [ $GETCH == t ] ; then
									echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								elif [ $GETCH == f ] ; then
									echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								else
									echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								fi
								;;
						*)	if [ -z "$other" ] || [ -z "$GETCH" ]; then
								sed '$d' < "$1.tpfltd" > $TMPDIR/TPtmp ; mv $TMPDIR/TPtmp "$1.tpfltd"
								echo "$(echo $previous | sed 's/	.$//g')	U" >> "$1.tpfltd"
								printf "\033c"
								secondary_menu
								getch
								if [ $GETCH == t ] ; then
									echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								elif [ $GETCH == f ] ; then
									echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								else
									echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
								fi
							else
								sed '$d' < "$1.tpfltd" > $TMPDIR/TPtmp ; mv $TMPDIR/TPtmp "$1.tpfltd"
								echo "$(echo $previous | sed 's/	.$//g')	$GETCH" >> "$1.tpfltd"
							fi
							;;
						esac
					;;				
			r|R)	printf "\033c"
					cat "$1.tpfltd"
					echo " "
					echo " "
					echo "press any key to continue"
					getch
					printf "\033c"
					echo " "
					echo " "
					echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
					echo " "
					if [ -z "$other" ]; then
						echo "          (t) designate true"
						echo "          (f) designate false"
					fi
					echo "          (s) skip current item"
					getch
					if [ $GETCH == t ] || [ $GETCH == T ]; then
						echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					elif [ $GETCH == f ] || [ $GETCH == F ]; then
						echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					elif [ $GETCH == u ] || [ $GETCH == U ]; then
						echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					elif [ "$other" ]; then
						echo "$line	$GETCH" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					else
						echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					fi
					;;
			l|L)	echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g'  >> "$1.tpfltd"
					echo "copying remaining lines ..."
					copyundesignatedly=true
					;;
			x|X)	mv "$1.tpfltd" $HOME/.Trash
					rm "$1.tmp"
					exit 0
					;;
			*)		if [ -z "$other" ]; then
					echo "$GETCH was not a valid choice. Try again."
					getch
					if [ $GETCH == t ] ; then
						echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					elif [ $GETCH == f ] ; then
						echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					else
						echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					fi
					elif [ -z "$GETCH" ]; then
						echo "$line	U" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					else
						echo "$line	$GETCH"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$1.tpfltd"
					fi
					;;
			esac
	fi
done
# tidy up
rm "$1.tmp"
# prepare statistics
if [ "$other" ]; then
	get_categories "$1.tpfltd"
else	
	if [ "$tokens" ]; then
		get_tokens "$1.tpfltd"
	else
		get_types "$1.tpfltd"
	fi
fi
printf "\033c"
echo " "
echo " "
echo "statistics:$(if [ "$tokens" ]; then echo "  (tokens)";fi)"
echo " "
echo " "
if [ "$other" ]; then
		report_categories "$1.tpfltd"
else
	echo "                     $(expr \( $TP \* 100 \) / $total )% ($TP items) TP"
	echo "                     $(expr \( $FP \* 100 \) / $total )% ($FP items) FP"
	echo "                     $(expr \( $U \* 100 \) / $total )% ($U items) undecided"
fi
echo " "
echo " "
echo " "
echo "start:	$start"
echo "end:	$(date)"

if [ "$resume" == "true" ] ; then
	mv "$1.tpfltd" "$1"
	rm "$1.bkup"
fi

# tidy up
if [ -e "$1.tmp" ]; then
	rm "$1.tmp"
fi