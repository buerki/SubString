#!/bin/bash -
##############################################################################
# random_lines.sh
copyright="Copyright (c) 2016 Cardiff University, 2010 Andreas Buerki"
# licensed under the EUPL V.1.1.
version="1.0"
####
# DESCRRIPTION: This script produces random lines from documents
#				(for use in TP/FP-tests
#               see TP-FP_lists_procedure.txt for details
# supply path to source list as argument
# SYNOPSIS:     random_lines.sh [OPTIONS] PATH_TO_SOURCE_LIST
# OPTIONS:      -v verbose mode
#				-n specify number of lines to be extracted
#               -s send output to standard out instead of a file
#
##############################################################################
# History
# 
###

# define help function
help ( ) {
	echo "
DESCRRIPTION: This script produces random lines from documents and puts them into
              a document in the pwd with the extension .random0000
SYNOPSIS:     $(basename $0) [OPTIONS] FILE
OPTIONS:      -v verbose mode
              -n specify number of lines to be extracted
              -s send output to standard out instead of a file
"
}

# define usage function
usage ( ) {
	echo "
Usage:    $(basename $0) FILE
Example:  $(basename $0) 80s-90s-2-7.cut.([0-9]|[1][0-2]).1.substrd
"
}
# analyse options
while getopts hn:vVs opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	v)	verbose=true
		;;
	n)	number=$OPTARG
		;;
	s)	stout=true
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "licensed under the EUPL V.1.1"
		echo "written by Andreas Buerki"
		exit 0
		;;
	esac
done
# check what platform we're under
platform=$(uname -s)
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	CYGWIN=true
elif [ "$(grep 'Darwin' <<< $platform)" ]; then
	extended="-E"
	DARWIN=true
else
	LINUX=true
fi
# define progress counter variable
progress=0
shift $((OPTIND -1))
if [ $# -lt 1 ] ; then
	echo "Error: please supply path to input list as argument"
	usage
fi
if [ -z "$number" ] ; then
	echo 'Please specify number of lines to be extracted' ; read number
fi
if [ "$verbose" == "true" ] ; then
	echo "processing $1 ..."
fi
# derive output name
ext="$(egrep -o '\.[[:alnum:]]+$' <<<"$1")"
new="$(sed "s/$ext//" <<< "$1")"
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	if [ "$stout" == "true" ] ; then
		sort --random-sort "$1" | head -$number | sed 's/^[0-9]* //'
	else
		sort --random-sort "$1" | head -$number | sed 's/^[0-9]* //' > "$new.random$number$ext"
	fi
else
	if [ "$stout" == "true" ] ; then
		awk 'BEGIN {srand()} {printf "%05.0f %s \n",rand()*999999, $0; }' "$1" | sort -n | head -$number | sed 's/^[0-9]* //'
	else
		awk 'BEGIN {srand()} {printf "%05.0f %s \n",rand()*999999, $0; }' "$1" | sort -n | head -$number | sed 's/^[0-9]* //' > "$new.random$number$ext"
	fi
	if [ "$verbose" == "true" ] ; then
		echo "$number random lines out of $1 written to $new.random$number$ext"
	fi
fi