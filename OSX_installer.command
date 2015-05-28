#!/bin/bash -

##############################################################################
# installer (c) Andreas Buerki 2015, licensed under the EUPL V.1.1.
version="0.1"
####

# define functions
help ( ) {
	echo "
Usage: $(basename $0)  [OPTIONS]
Example: $(basename $0)  -u
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
	V)	echo "$(basename $0)	-	version $version"
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
# check if there is a space in home:
if [ "$(grep -o ' ' <<<$HOME)" ]; then
	echo "The home directory contains a space: $HOME" >&2
	echo "This will cause problems during installation." >&2
	echo "See https://www.cygwin.com/ml/cygwin/2007-09/msg00423.html on how to change this in Cygwin.">&2
	echo "Installation aborted" >&2
	exit 1
fi

# check what platform we're under
platform=$(uname -s)
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	sourcedir="$0"
else
	sourcedir="$(dirname $0)"
fi
# check it's in its proper directory
if [ "$(grep 'SubString' <<<"$sourcedir")" ]; then
	:
elif [ "$sourcedir" == "." ]; then
	sourcedir=$(pwd)
	if [ "$(grep 'SubString' <<<$sourcedir)" ]; then
		:
	else
		echo "This installer script appears to have been moved out of its original directory. Please move it back into its original directory and run it again." >&2
		exit 1
	fi	
else
	echo "This installer script appears to have been moved out of its original directory. Please move it back into its original directory and run it again." >&2
	exit 1
fi


# set path
# echo "current path: $PATH"
# work out if $HOME has a space and fix accordingly
if [ "$(egrep -o "$HOME/bin" <<<$PATH)" ]; then
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
fi

# make sure source dir has no spaces in it
if [ "$(grep ' ' <<<$sourcedir)" ]; then
	sourcedir="$(sed -e 's/ /\\ /g' -e 's/\\\\/\\/g' <<<$sourcedir)"
fi

# remove old installations
echo "Checking for existing installations..."
for file in $(ls $sourcedir/*.sh); do
	filename="$(basename $file)"
	existing="$(which $filename)"
	if [ "$existing" ]; then
		echo "removing $existing"
		rm -f $existing 2>/dev/null || sudo rm $existing
	fi
	existing=""
done

if [ "$uninstall" ]; then
	exit 0
fi

# install files
DESTINATION="${HOME}/bin"
echo "Installing files to $HOME/bin"
mkdir -p ${DESTINATION}
cp $sourcedir/*.sh $DESTINATION/ || problem=true
if [ "$problem" ]; then
	echo "Installation encountered problems. Manual installation may be required." >&2
	exit 1
fi


echo "Installation complete. The following files were placed in $HOME/bin:"
ls $(dirname $0)/*.sh
echo ""
sleep 10
# Exit from the script with success (0)
# exit 0
#__ARCHIVE__
# Find __ARCHIVE__ maker, read archive content and decompress it
#ARCHIVE=$(awk '/^__ARCHIVE__/ {print NR + 1; exit 0; }' "${0}")
#tail -n+${ARCHIVE} "${0}" | tar xp Jv -C ${DESTINATION}
# copy files to destination