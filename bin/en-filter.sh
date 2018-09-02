#!/bin/bash -
##############################################################################
# en-filter.sh
copyright="Copyright (c) 2016 Cardiff University, 2015 Andreas Buerki"
# licensed under the EUPL V.1.1.
####
version="1.5.3"
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
#######################
# this function checks if a file name (given as argument) exists and
# if so appends a number to the end so as to avoid overwriting existing
# files of the name as in the argument or any with the name of the argument
# plus an incremented count appended.
####
add_to_name ( ) {
count=
# establish extension
ext="$(egrep -o '\.[[:alnum:]]+$' <<<"$1")"
if [ "$ext" ]; then
	if [ -e "$1" ]; then
		add=-
		count=1
		new="$(sed "s/$ext//" <<< "$1")"
		while [ -e "$new$add$count$ext" ];do
			(( count += 1 ))
		done
	else
		count=
		add=
	fi
	output_filename="$(sed "s/$ext//" <<< "$1")$add$count$ext"
else
	if [ -e "$1" ]; then
		add=-
		count=1
		while [ -e "$1"-$count ]
			do
			(( count += 1 ))
			done
	else
		count=
		add=
	fi
	output_filename=$(echo ""$1"$add$count")
fi
}
#######################
# define add_windows_returns function
#######################
add_windows_returns ( ) {
sed 's/$//g' $1
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
# check what platform we're under
platform=$(uname -s)
extended="-r"
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	CYGWIN=true
elif [ "$(grep 'Darwin' <<< $platform)" ]; then
	extended="-E"
	DARWIN=true
else
	LINUX=true
fi
######
# start of programme
# create scratch directory
SCRATCHDIR=$(mktemp -dt enfilterXXX)
# if mktemp fails, use a different method to create the SCRATCHDIR
if [ "$SCRATCHDIR" == "" ] ; then
	mkdir ${TMPDIR-/tmp/}pilot-parser.1$$
	SCRATCHDIR=${TMPDIR-/tmp/}pilot-parser.1$$
fi
for files in $@
	do
		ext="$(egrep -o '\.[[:alnum:]]+$' <<<"$files")"
		files_woext="$(sed "s/$ext//" <<< "$files")"
		add_to_name $files_woext.$version.enfltd$ext
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
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	add_windows_returns "$outfile" > "$outfile."
	mv "$outfile." "$outfile"
fi
done