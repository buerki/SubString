#!/bin/bash -
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin" # needed for Cygwin
##############################################################################
# installer (c) Andreas Buerki 2015, licensed under the EUPL V.1.1.
version="0.3"
####

## set installation variables
export title="SubString"
export components="substring.sh listconv.sh length-adjust.sh cutoff.sh"
export DESTINATION="${HOME}/bin"

# define functions
help ( ) {
	echo "
Usage: $(basename $(sed 's/ //g' <<<$0))  [OPTIONS]
Example: $(basename $(sed 's/ //g' <<<$0))  -u
IMPORTANT: this script should not be moved outside of its original directory.
           (it will stop working if it is moved)
Options:   -u	uninstalls the software
           -V   displays version information
           -p   only attempts to set path
"
}

# analyse options
while getopts hpuV opt
do
	case $opt	in
	h)	help
		exit 0
		;;
	u)	uninstall=true
		;;
	p)	pathonly=true
		;;
	V)	echo "$(basename $(sed 's/ //g' <<<$0))	-	version $version"
		echo "Copyright (c) 2015 Andreas Buerki"
		echo "licensed under the EUPL V.1.1"
		exit 0
		;;
	esac
done
echo ""
echo "Installer"
echo "---------"
echo ""
#sourcedir="$(pwd)"
#pwd
#echo $origdir
#echo $PATH
#echo "home: $HOME"

# check what platform we're under
platform=$(uname -s)
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	CYGWIN=true
fi

export sourcedir="$(dirname $0)"
if [ "$sourcedir" == "." ]; then
	sourcedir=$(pwd)
fi
echo "sourcedir is $sourcedir"

# check it's in its proper directory
if [ "$(grep "$title" <<<"$sourcedir")" ]; then
	:
else
	echo "This installer script appears to have been moved out of its original directory. Please move it back into its original directory and run it again." >&2
	exit 1
fi


# set path
# echo "current path: $PATH"
# from now on, commands are executed from a subshell with -l (login) option
# (needed for Cygwin)
bash -lc 'if [ "$(egrep -o "$HOME/bin" <<<$PATH)" ]; then
echo "Path already set."
elif [ -e ~/.bash_profile ]; then
	cp "${HOME}/.bash_profile" "${HOME}/.bash_profile.bkup"
	echo "">> "${HOME}/.bash_profile"
	echo "export PATH="\${PATH}:${HOME}/bin"">> "${HOME}/.bash_profile"
	echo "Setting path in ~/.bash_profile"
	echo "Logout and login may be required before new path takes effect."
else
	cp "${HOME}/.profile" "${HOME}/.profile.bkup"
	echo "">> "${HOME}/.profile"
	echo "export PATH="$\{PATH}:${HOME}/bin"">> "${HOME}/.profile"
	echo "Setting path in ~/.profile"
	echo "Logout and login may be required before new path takes effect."
fi

echo ""
if [ "$pathonly" ]; then
	exit 0
fi'

# make sure source dir has no spaces in it
#if [ "$(grep ' ' <<<$sourcedir)" ]; then
#	sourcedir="$(sed -e 's/ /\\ /g' -e 's/\\\\/\\/g' <<<$sourcedir)"
#fi

# remove old installations
bash -lc 'echo "Checking for existing installations..."
for file in $components; do
	existing="$(which $file)"
	if [ "$existing" ]; then
		echo "removing $existing"
		rm -f $existing 2>/dev/null || sudo rm $existing
	fi
	existing=""
done'

if [ "$uninstall" ]; then
	exit 0
fi

# install files
echo ""
echo "Installing files to $HOME/bin"
mkdir -p ${DESTINATION}
for file in $components; do
	cp "$sourcedir/$file" $DESTINATION/ || problem=true
	if [ "$problem" ]; then
		echo "Installation encountered problems. Manual installation may be required." >&2
		exit 1
	fi
done

echo "The following files were placed in $HOME/bin:"
echo "$components" | tr ' ' '\n'
echo ""
echo "Installation complete."
sleep 10
