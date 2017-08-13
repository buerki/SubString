#!/bin/bash -
##############################################################################
# TP_filter.sh
copyright="Copyright (c) 2016-17 Cardiff University, 2009, 2013-2015 Andreas Buerki
licensed under the EUPL V.1.1."
version='0.8.8'
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
options: -g use gradation rating scheme
         -r only displays result (several argument files may be provided)
         -a auxiliary mode: suppress all but rating dialogues
         -t display result in terms of tokens
         -f use free rating scheme, not TP/F
         -h help
         -p SEP provide word separator used in input n-gram lists
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
S=$(echo "$(grep "S$" "$1" | cut -f 2 | sed 's/$/ +/g' ) 0" | tr '\n' ' '| sed 's/  / /g' |bc)
total=$(echo "$TP + $FP + $S" | bc)
}
# define get_types function
get_types ( ) {
TP=$(grep -o "T$" "$1" | wc -l | sed 's/ //g')
FP=$(grep -o "F$" "$1" | wc -l | sed 's/ //g')
S=$(grep -o "S$" "$1" | wc -l | sed 's/ //g')
total=$(expr $TP + $FP + $S)
}
# define get_categories function
get_categories ( ) {
if [ "$gradation" ]; then
	cats=$(sed 's/.*\(..\)$/\1/g' "$1" | sort | uniq)
else 
	cats=$(sed 's/.*\(.\)$/\1/g' "$1" | sort | uniq)
fi
}
# define get_separator function
get_separator ( ) {
# checking input list to derive separator
# check if -p option is active and if so, use that separator
if [ "$separator" ]; then
	:
else
	testline=$(head -1 $infile.tmp)|| exit 1
	nsize=$(echo $testline | awk '{c+=gsub(s,s)}END{print c}' s='<>') 
	if [ "$nsize" -gt 0 ]; then
		separator='<>'
	else
		nsize=$(echo $testline | awk '{c+=gsub(s,s)}END{print c}' s='·')
		if [ "$nsize" -gt 0 ]; then
			separator='·'
		else
			nsize=$(echo $testline | awk '{c+=gsub(s,s)}END{print c}' s='_')
			if [ "$nsize" -gt 0 ]; then
				separator='_'	
			else
				echo "unknown separator in $testline" >&2
				exit 1
			fi
		fi
	fi
fi
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
	echo "                  $cat  $(echo "$stat * 100 / $total" | sed 's/ //g' | bc)% ($stat items)"
done
}
# define report_statistics function
report_statistics ( ) {
	# prepare T/F statistics
	if [ -z "$other" ]; then
		if [ "$tokens" ]; then
			get_tokens "$1"
		else
			get_types "$1"
		fi
	fi
	if [ "$other" ] || [ "$gradation" ]; then
		get_categories "$1"
		report_categories "$1"
		if [ "$gradation" ]; then
			echo
			echo "                  ------summary------"
			echo "                  T  $(expr \( $TP \* 100 \) / $total )% ($TP items)"
			echo "                  F  $(expr \( $FP \* 100 \) / $total )% ($FP items)"
			echo "                  S  $(expr \( $S \* 100 \) / $total )% ($S items) skipped"
		fi
	else
		echo "                  T  $(expr \( $TP \* 100 \) / $total )% ($TP items)"
		echo "                  F  $(expr \( $FP \* 100 \) / $total )% ($FP items)"
		echo "                  S  $(expr \( $S \* 100 \) / $total )% ($S items) skipped"
	fi
	echo " "
	echo " "
}
# define categorisation_options function
categorisation_options ( ) {
	if [ "$other" ]; then
		echo "      Enter designation (single letters only) or one of the following commands:"
	elif [ "$gradation" ]; then
		echo "          semantic unit?"
		echo 
#		echo "                        unsure"
#		echo "        NO <--------------|--------------> YES"
#		echo "            (1)  (2)  (3)   (4)  (5)  (6)"
#		echo
		echo "          (1) NO  [certain]"
		echo "          (2) NO  [quite certain]"
		echo "          (3) NO  [uncertain]"
		echo "          (4) YES [uncertain]"
		echo "          (5) YES [quite certain]"
		echo "          (6) YES [certain]"
		echo ""
	else
		echo "          (t) designate TRUE"
		echo "          (f) designate false"
	fi
}
# define secondary_menu function
secondary_menu ( ) {
printf "\033c"
echo " "
echo " "
echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
echo " "
echo " "
categorisation_options
echo
echo "          (s) skip current item"
getch
case $GETCH in
1)		echo "$line	1F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		;;
2)		echo "$line	2F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		;;
3)		echo "$line	3F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		;;
4)		echo "$line	4T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		;;
5)		echo "$line	5T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		;;
6)		echo "$line	6T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		;;
t|T)	if [ "$gradation" ]; then
			echo "$GETCH is not a valid choice. Skipped."
			echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		else
			echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		fi
		;;
f|F)	if [ "$gradation" ]; then
			echo "$GETCH is not a valid choice. Skipped."
			echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		else
			echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		fi
		;;
s|S)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		;;
*)		if [ -z "$other" ]; then
			echo "$GETCH was not a valid choice. Try again."
				getch
				case $GETCH in
				1)		echo "$line	1F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				2)		echo "$line	2F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				3)		echo "$line	3F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				4)		echo "$line	4T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				5)		echo "$line	5T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				6)		echo "$line	6T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				t|T)	if [ "$gradation" ]; then
							echo "$GETCH is not a valid choice. Skipped."
							echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						else
							echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						fi
						;;
				f|F)	if [ "$gradation" ]; then
							echo "$GETCH is not a valid choice. Skipped."
							echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						else
							echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						fi
						;;
				s|S)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				*)		echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				esac
		elif [ -z "$GETCH" ]; then
			echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		else
			echo "$line	$GETCH"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
		fi
		;;
esac					
}
# define case_gradation function
case_gradation ( ) {
	case $GETCH in
	1)		echo "$line	1F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	2)		echo "$line	2F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	3)		echo "$line	3F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	4)		echo "$line	4T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	5)		echo "$line	5T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	6)		echo "$line	6T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	s|S)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	b|B)	printf "\033c"
			previous="$(tail -n 1 "$infile.tpfltd")"
			echo "previous item was"
			echo " "
			echo "$(echo "$previous" | cut -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g')   $( echo "$previous" | sed 's/.*\(..\)$/\1/g')"
			echo " "
			echo " "
			echo " "
			categorisation_options
			echo
			echo "          (u) change to undesignated"
			echo "          (n) no change, carry on"
			getch
				case $GETCH in
				1)		categorisation="1F"
						back_categorisation_process "$infile"
						;;
				2)		categorisation="2F"
						back_categorisation_process "$infile"
						;;
				3)		categorisation="3F"
						back_categorisation_process "$infile"
						;;
				4)		categorisation="4T"
						back_categorisation_process "$infile"
						;;
				5)		categorisation="5T"
						back_categorisation_process "$infile"
						;;
				6)		categorisation="6T"
						back_categorisation_process "$infile"
						;;
				s|S)	categorisation="S"
						back_categorisation_process "$infile"
						;;
				n|N)	printf "\033c"
						secondary_menu
						;;
				*)		categorisation="S"
						back_categorisation_process "$infile"
						;;
				esac
			;;				
	r|R)	printf "\033c"
			cat "$infile.tpfltd"
			echo " "
			echo " "
			echo "press any key to continue"
			getch
			printf "\033c"
			echo " "
			echo " "
			echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
			echo " "
			secondary_menu
			;;
	l|L)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g'  >> "$infile.tpfltd"
			if [ "$auxiliary" ]; then
				echo "just a moment..."
			else
				echo "copying remaining lines ..."
			fi
			copyundesignatedly=TRUE
			;;
	x|X)	if [ "$auxiliary" ]; then
				echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g'  >> "$infile.tpfltd"
			else
				mv "$infile.tpfltd" $HOME/.Trash
				rm "$infile.tmp"
				exit 0
			fi
			;;
	*)		if [ -z "$other" ]; then
				echo "$GETCH was not a valid choice. Try again."
				getch
				case $GETCH in
					1)		echo "$line	1F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
					2)		echo "$line	2F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
					3)		echo "$line	3F"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
					4)		echo "$line	4T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
					5)		echo "$line	5T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
					6)		echo "$line	6T"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
					s|S)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
					*)		echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
							;;
				esac
			elif [ -z "$GETCH" ]; then
				echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			else
				echo "$line	$GETCH"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			fi
			;;
	esac
}
# define case_other function
case_other ( ) {
	case $GETCH in
	s|S)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	b|B)	printf "\033c"
			previous="$(tail -n 1 "$infile.tpfltd")"
			echo "previous item was"
			echo " "
			echo "$(echo "$previous" | cut -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g')   $( echo "$previous" | sed 's/.*\(..\)$/\1/g')"
			echo " "
			echo " "
			echo " "
			categorisation_options
			echo
			echo "          (u) change to undesignated"
			echo "          (n) no change, carry on"
			getch
				case $GETCH in
				s|S)	categorisation="S"
						back_categorisation_process "$infile"
						;;
				n|N)	printf "\033c"
						secondary_menu
						;;
				*)		categorisation="$GETCH"
						back_categorisation_process "$infile"
						;;
				esac
			;;				
	r|R)	printf "\033c"
			cat "$infile.tpfltd"
			echo " "
			echo " "
			echo "press any key to continue"
			getch
			printf "\033c"
			echo " "
			echo " "
			echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
			echo " "
			secondary_menu
			;;
	l|L)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g'  >> "$infile.tpfltd"
			if [ "$auxiliary" ]; then
				echo "just a moment ..."
			else
				echo "copying remaining lines ..."
			fi
			copyundesignatedly=TRUE
			;;
	x|X)	if [ "$auxiliary" ]; then
				echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g'  >> "$infile.tpfltd"
			else
				mv "$infile.tpfltd" $HOME/.Trash
				rm "$infile.tmp"
				exit 0
			fi
			;;
	*)		if [ -z "$GETCH" ]; then
				echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			else
				echo "$line	$GETCH"| sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			fi
			;;
	esac
}
# define case_TF function
case_TF ( ) {
	case $GETCH in
	t|T)	echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	f|F)	echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	s|S)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
			;;
	b|B)	printf "\033c"
			previous="$(tail -n 1 "$infile.tpfltd")"
			echo "previous item was"
			echo " "
			echo "$(echo "$previous" | cut -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g')   $( echo "$previous" | sed 's/.*\(..\)$/\1/g')"
			echo " "
			echo " "
			echo " "
			categorisation_options
			echo
			echo "          (s) change to skipped"
			echo "          (n) no change, carry on"
			getch
				case $GETCH in
				t|T)	categorisation="T"
						back_categorisation_process "$infile"
						;;
				f|F)	categorisation="F"
						back_categorisation_process "$infile"
						;;
				s|S)	categorisation="S"
						back_categorisation_process "$infile"
						;;
				n|N)	printf "\033c"
						secondary_menu
						;;
				*)		categorisation="S"
						back_categorisation_process "$infile"
						;;
				esac
			;;				
	r|R)	printf "\033c"
			cat "$infile.tpfltd"
			echo " "
			echo " "
			echo "press any key to continue"
			getch
			printf "\033c"
			echo " "
			echo " "
			echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
			echo " "
			secondary_menu
			;;
	l|L)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g'  >> "$infile.tpfltd"
			if [ "$auxiliary" ]; then
				echo "just a moment ..."
			else
				echo "copying remaining lines ..."
			fi
			copyundesignatedly=TRUE
			;;
	x|X)	if [ "$auxiliary" ]; then
				echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g'  >> "$infile.tpfltd"
			else
				mv "$infile.tpfltd" $HOME/.Trash
				rm "$infile.tmp"
				exit 0
			fi
			;;
	*)		echo "$GETCH was not a valid choice. Try again."
			getch
			case $GETCH in
				t|T)	echo "$line	T" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				f|F)	echo "$line	F" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				s|S)	echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
				*)		echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
						;;
			esac
			;;
	esac
}
# define back_categorisation_process function
back_categorisation_process ( ) {
	sed '$d' < "$infile.tpfltd" > $TMPDIR/TPtmp ; mv $TMPDIR/TPtmp "$infile.tpfltd"
	echo "$(echo $previous | sed 's/ [[:digit:]]*[[:alpha:]]$//g')	$categorisation" >> "$infile.tpfltd"
	printf "\033c"
	secondary_menu "$infile"
}
############### END defining functions ########################################

# analyse options
while getopts ahgfp:Vrt opt
do
	case $opt	in
	a)	auxiliary=TRUE
		;;
	h)	help
		exit 0
		;;
	g)	gradation=TRUE
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "written by Andreas Buerki"
		exit 0
		;;
	f)	other=TRUE
		;;
	p)	separator="$OPTARG"
		;;
	r)	results_only=TRUE
		;;
	t)	tokens=TRUE
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
# put input file name/path in to variable
infile="$1"
if [ $# -gt 1 ] && [ -z "$results_only" ]; then
	echo "only the first argument list will be processed" >&2
fi
# check if list has been processed
if [ "$(grep '.tpfltd' <<<"$infile")" ]; then
	resume=TRUE
elif [ -z "$other" ] && [ -n "$(head -n 1 "$infile" | egrep -o "[TFSU]$" )" ] ; then
	resume=TRUE
elif [ "$gradation" ] && [ -n "$(head -n 1 "$infile" | egrep -o "	[123456][TFSU]$" )" ] ; then
	resume=TRUE
elif [ "$other" ] && [ "$(head -n 1 "$infile" | egrep -o "[[:alpha:]]$" )" ]; then
	resume=TRUE
fi
# if resume, make sure we are resuming with correct categorisation system
if [ "$resume" ]; then
	if [ -z "$gradation" ] && [ "$(head -n 1 "$infile" | egrep -o "	[123456][TFSU]$" )" ] ; then
		gradation=TRUE
	elif [ -z "$other" ] && [ "$(head -n 1 "$infile" | egrep -o "	[[:alpha:]]$" | egrep -v "[TFSU]" )" ]; then
		other=TRUE
	fi
fi
################## process for results-only option ############################
if [ "$results_only" ]; then
	if [ "$other" ] || [ "$gradation" ]; then echo "-r option not available in conjuction with -f/-g."
>&2;exit 0;fi
	echo "file / TPs / % / undecided $(if [ "$tokens" ]; then echo "  (tokens)";fi)"
	for file; do
		# check if files were processed and issue error if not
		if [ -n "$(head -n 1 "$file" | egrep "[TFSU]$" | cut -f 1 )" ] ; then
			# prepare statistics
			if [ "$tokens" ]; then
				get_tokens "$file"
			else
				get_types "$file"
			fi
			echo "$(basename "$file") / $TP / $(expr \( $TP \* 100 \) / $total )% / $S"
		else
			echo "$file is not TP annotated ----------"
		fi
	done
	exit 0
fi
################## END process for results-only option #######################
if [ "$resume" ]; then
	if [ -z "$auxiliary" ]; then
		printf "\033c"
		echo " "
		echo " "
		echo "statistics so far:$(if [ "$tokens" ]; then echo "  (tokens)";fi)"
		echo " "
		echo " "
		report_statistics "$1"
		echo "resuming $(if [ -z "$other" ]; then echo "TP filtering ";fi)in 1 second"
		echo " "
		echo " "
		echo " "
		sleep 1.5
	fi
	# backup original list
	cp "$infile" "$infile.bkup"
	# check if target list exists
	if [ -a "$infile.tpfltd" ] ; then
		echo "$infile.tpfltd exists. overwrite? (y/n)"
		getch
		if [ $GETCH == y ] ; then
			rm "$infile.tpfltd"
		else
			echo "exited without changing anything"
			exit 0
		fi
	fi
	# put lines already processed into the new output file
	egrep "[^S]$" "$infile.bkup" > "$infile.tpfltd"
	# put undecided lines into a tmp file and replace tabs with underscores
	egrep "S$" "$infile.bkup" | sed 's/	.$//g' | sed -e 's/_/UNDERSCORE/g' -e 's/	/_/g'  > "$infile.tmp"
else
	# create tmp file with underscores instead of tabs
	sed -e 's/_/UNDERSCORE/g' -e 's/	/_/g' "$infile" > "$infile.tmp"

	# check if target list exists
	if [ -a "$infile.tpfltd" ] ; then
		echo "$infile.tpfltd exists. overwrite? (y/n)"
		getch
		if [ "$GETCH" == "y" ] ; then
			rm "$infile.tpfltd"
		else
			echo "exited without changing anything"
			exit 0
		fi
	fi
fi
# start time
start=$(date)
# start for in loop
for line in $(cat "$infile.tmp")
do
	(( progress += 1 ))
	if [ "$copyundesignatedly" ] ; then
		echo "$line	S" | sed -e 's/_/	/g' -e 's/UNDERSCORE/_/g' >> "$infile.tpfltd"
	else
		printf "\033c"
		echo $progress
		echo " "
		echo " "
		if [ "$auxiliary" ]; then
			get_separator
			echo $line | cut -d "_" -f 1 | sed -e "s/$separator/ /g" -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
		else
			echo $line | cut -d "_" -f 1 | sed -e 's/\<\>/ /g' -e 's/_/	/g' -e 's/UNDERSCORE/_/g'
		fi
		echo " "
		echo " "
		categorisation_options
		echo "          (s) skip current item"
		echo "          (b) back to previous item"
		echo " "
		echo "          (r) review all designations up to now"
		echo "          (l) resume later"
		if [ -z "$auxiliary" ]; then echo "          (x) exit and discard all designations"; fi
		getch
		if [ "$gradation" ]; then
			case_gradation
		elif [ "$other"]; then
			case_other
		else
			case_TF
		fi
	fi
done
# tidy up
rm "$infile.tmp"
if [ -z "$auxiliary" ]; then
	printf "\033c"
	echo " "
	echo " "
	echo "statistics:$(if [ "$tokens" ]; then echo "  (tokens)";fi)"
	echo " "
	echo " "
	report_statistics "$infile.tpfltd"
	echo "start:	$start"
	echo "end:	$(date)"
fi
if [ "$resume" == "TRUE" ] ; then
	mv "$infile.tpfltd" "$infile"
	rm "$infile.bkup"
fi

# tidy up
if [ -e "$infile.tmp" ]; then
	rm "$infile.tmp"
fi