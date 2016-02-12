#!/bin/bash -
##############################################################################
# en_filter.sh
copyright="Copyright (c) 2016 Cardiff University, 2015 Andreas Buerki"
# licensed under the EUPL V.1.1.
####
version="1.5.1"
# DESCRRIPTION: lexico-structural filter for English language data
# define help function
help ( ) {
	echo "
DESCRRIPTION: en-filter.sh filters n-grams lists according to a lexico-structural filter
SYNOPSIS: $(basename $0) [OPTIONS] FILE+
DEPENDENCIES: consolidate.sh
OPTIONS:    -h  help
            -v  verbose
            -V  version
            -d	include document counts in output (see consolidate.sh)
"
}
# define add_to_name function
add_to_name ( ) {
#####
# this function checks if a file name (given as argument) exists and
# if so appends a number to the end so as to avoid overwriting existing
# files of the name as in the argument or any with the name of the argument
# plus an incremented count appended.
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
# analyse options
while getopts dhvV opt
do
	case $opt	in
	d)	doc='-d'
		;;
	v)	verbose=true
		verb='-v'
		;;
	V)	echo "$(basename $0)	-	version $version"
		echo "$copyright"
		echo "licensed under the EUPL V.1.1"
		echo "written by Andreas Buerki"
		exit 0
		;;
	h)	help
		exit 0
		;;
	esac
done
shift $((OPTIND -1))
# check that input files exist
for file in $@; do
	if [ -s $file ]; then
		:
	else
		echo "ERROR: could not open $file"
		exit 1
	fi
done
#
######
# start of programme
# create scratch directory
SCRATCHDIR=$(mktemp -dt pilotparserXXX)
# if mktemp fails, use a different method to create the SCRATCHDIR
if [ "$SCRATCHDIR" == "" ] ; then
	mkdir ${TMPDIR-/tmp/}pilot-parser.1$$
	SCRATCHDIR=${TMPDIR-/tmp/}pilot-parser.1$$
fi
for files in $@
	do
		add_to_name $files.$version.enfltd
		outfile="$output_filename"
##############################################################################
# filter part 1
sed -E -e 's/NE·NE/NE/g' \
-e 's/NE·NE/NE/g' \
-e 's/NE·NE/NE/g' \
-e 's/NE·NE/NE/g' \
-e 's/NE·NE/NE/g' \
-e 's/%··%/%/g' \
-e 's/%·%/%/g' \
-e 's/€··€/€/g' \
-e 's/NUM·NUM·/NUM·/g' \
-e 's/NUM·NUM·/NUM·/g' \
-e 's/NUM·NUM·/NUM·/g' \
-e 's/^[[:digit:]]+/NUM/g' \
-e 's/·[[:digit:]]+/·NUM/g' \
-e 's/··/·/g' \
-e 's/NUM·NUM·/NUM·/g' \
-e "/(^(\(|\))·[^·]*·	|^[^·]*·(\(|\))·	)/d" \
-e "/^[^\(]*·\)·[[:alnum:]]*·/d" \
-e "/[^\(]*·\(·[[:alnum:]]*·[^\)]* /d" \
-e "/\(·[^\)]*	/s/\(·//g" \
-e "s/^\)·//g" \
-e "/^[^\(]*\)/s/\)·//g" \
-e "s/\(·	//g" $files > $SCRATCHDIR/$outfile
# filter parts 2 and 3
egrep -v "(\
E9E9E9|\
\/·	|\
^%·'·|\
^%·NE·	|\
^&·NE·	|\
^&·amp·	|\
^'·[^·]·	|\
^(NE·)+	|\
^(NUM·)+	|\
^\(·\)|·\(·\)|\
^-·|\
^-·|^HYPH·|^—·|^–·|\
^/·(NUM·)+/·|\
^/·/·|·/·/·|\
^/·NE|\
^NE·|\
^NUM·\(·|\
^NUM·\)·|\
^[^·]·'·	|\
^\+·NE|\
^\+·\+·NE|\
^_|\
^·|\
·'·	|^'·|\
·-·	|\
·-·	|·HYPH·	|·—·	|·–·	|\
·/·	|^/·|\
·_|\
·–·	|\
^	[[:digit:]]*)" $SCRATCHDIR/$outfile |\
egrep -v "(\
^and·|^\+·|\
^but·|\
^for·the·[^·]*·	|\
^from·the·|\
·he·	|\
^people·|\
·she·	|\
^than·|\
^that·|\
^their·|\
^them·|\
·they·	|\
^the·[^·]*·of·	|\
^to·[^·]*·the·	|\
^we·|\
^what·|\
·when·	|\
·where·	|\
^which·[^·]*·	|\
^[^·]*·which·	|\
^who·|\
^you·	|\
·and·	|\
·a·	|\
·by·	|\
·for	|\
·from·	|\
·her·	|\
·he·	|\
·his·	|\
·in·	|\
·its·	|\
·it·	|\
·my·	|\
·our·	|\
·their·	|\
·the·	|\
·to·	|\
·your·	|\
·been·	|\
·be·	|\
·are·[^·]*·	|\
·had·	|\
·has·	|\
·have·	|\
·is·	|\
·was·	|\
^had·)" > $outfile
consolidate.sh -r $doc $verb $outfile
done