#!/bin/bash -
export PATH="$PATH:/usr/local/bin:/usr/bin:/bin" # needed for Cygwin
##############################################################################
# installer
copyright="Copyright (c) 2015-2018 Cardiff University"
# written by Andreas Buerki
version="0.4.3"
####
## set installation variables
export title="[Ss]ub[Ss]tring"
export components="substring.sh substring-B.sh length-adjust.sh cutoff.sh consolidate.sh en-filter.sh random_lines.sh TP-filter.sh listconv.sh"
export components2="substring-A.py libs/filetype/ft_ngp.py libs/filetype/ft_nsp.py"
export DESTINATION="/usr/local/bin"
export DESTINATION2="/" # for cygwin-only files
export DESTINATION3=
export cygwin_only="SSicon.ico"
export linux_only="SSicon.png"
export osx_only="SubString.app"
export licence="European Union Public Licence (EUPL) v. 1.1."
export URL="https://joinup.ec.europa.eu/community/eupl/og_page/european-union-public-licence-eupl-v11"
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
# define getch function (reads the first character input from the keyboard)
getch ( ) {
	OLD_STTY=$(stty -g)
	stty cbreak -echo
	GETCH=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
	stty $OLD_STTY 
}
# analyse options
while getopts dhpuV opt
do
	case $opt	in
	d)	diagnostic=true
		;;
	h)	help
		exit 0
		;;
	u)	uninstall=true
		;;
	p)	pathonly=true
		;;
	V)	echo "$(basename $(sed 's/ //g' <<<$0))	-	version $version"
		echo "$copyright"
		echo "licensed under the EUPL V.1.1"
		echo "written by Andreas Buerki"
		exit 0
		;;
	esac
done
echo ""
echo "Installer"
echo "---------"
echo ""
if [ "$diagnostic" ]; then
	echo "pwd is $(pwd)"
	echo "current path is $PATH"
	echo "home: $HOME"
fi
# check what platform we're under
platform=$(uname -s)
# and make adjustments accordingly
if [ "$(grep 'CYGWIN' <<< $platform)" ]; then
	CYGWIN=true
	bash -lc 'export USERNAME="$USERNAME"'
	# check if $HOME contains spaces
	if [ "$(grep ' ' <<<"$HOME")" ]; then
		echo "WARNING: Your Cygwin installation user name contains one or more spaces." >&2
	fi
elif [ "$(grep 'Darwin' <<< $platform)" ];then
	DARWIN=true
else
	LINUX=true
fi
# check if python 3 is installed
if [ -z "$uninstall" ]; then
	if [ -z "$(python --version 2> /dev/null| grep 3)" ] && [ -z "$(python3 --version 2> /dev/null | grep 3)" ]; then
		echo "WARNING: no python 3 installation was found on this computer. You must install it before module A can be used."
		echo
		echo "Press any key to continue with the installation"
		getch
		echo
		echo
	fi
fi
# check if mwetoolkit is installed
export mwetoolkitdir="$(dirname $(which candidates.py) 2> /dev/null)"
if [ -z "$uninstall" ]; then
	if [ -z "$mwetoolkitdir" ]; then
		# check if mwetoolkit is in pwd
		if [ "$(ls bin/candidates.py 2> /dev/null)" ]; then
			mwetookitdir=bin
		else
			components2=""
			echo "WARNING: No installation of mwetoolkit was found."
			echo "The substring-A module will not be installed."
			echo ""
			echo "After installing mwetoolkit (by moving the contents of its 'bin' directory into /usr/local/bin) re-run this installer. Alternatively, place 'substring-A.py' in the 'bin' directory inside the mwetoolkit directory, and 'ft_ngp.py', 'ft_nsp.py' into the 'bin/libs/filetype' directory inside the mwetoolkit directory."
			echo
			echo "Press any key to continue with the installation of remaining modules"
			getch
			echo
			echo
		fi
	fi
fi
DESTINATION3="$mwetoolkitdir"
# ascertain source directory
export sourcedir="$(dirname "$0")"
if [ "$(grep '^\.' <<<"$sourcedir")" ]; then
	sourcedir="$(pwd)/bin"
fi
if [ "$diagnostic" ]; then 
	echo "sourcedir is $sourcedir"
	echo "0 is $0"
	echo "dirname is $(dirname "$0")"
fi
if [ -z "$uninstall" ]; then
	# check it's in its proper directory
	if [ "$(grep "$title" <<<"$sourcedir")" ]; then
		:
	else
		echo "This installer script appears to have been moved out of its original directory. Please move it back into the $title directory and run it again." >&2
		sleep 2
		exit 1
	fi
###########
# getting agreement on licence
###########
	echo "This software is licensed under the open-source"
	echo "$licence"
	echo "The full licence is found at"
	echo "$URL or in the accompanying licence file."
	echo "Before installing and using the software, we ask"
	echo "that you agree to the terms of this licence."
	echo
	echo "If you agree, please type 'agree' and press ENTER,"
	echo "otherwise just press ENTER."
	read -p '> ' d < /dev/tty
	if [ "$d" != "agree" ]; then
		echo
		echo "Since the installation and use of this software requires"
		echo "agreement to the licence, installation cannot continue."
		sleep 2
		exit 1
	else
		echo "Thank you."
	fi
###########
# setting path
###########
	# set path
	# from now on, commands are executed from a subshell with -l (login) 
	# option (needed for Cygwin)
	bash -lc 'if [ "$(egrep -o "$DESTINATION" <<<$PATH)" ]; then
		echo "Path already set."
	elif [ -e ~/.bash_profile ]; then
		cp "${HOME}/.bash_profile" "${HOME}/.bash_profile.bkup"
		echo "">> "${HOME}/.bash_profile"
		echo "export PATH="\${PATH}:\"$DESTINATION\""">> "${HOME}/.bash_profile"
		echo "Setting path in ~/.bash_profile"
		echo "Logout and login may be required before new path takes effect."
	else
		cp "${HOME}/.profile" "${HOME}/.profile.bkup"
		echo "">> "${HOME}/.profile"
		echo "export PATH="$\{PATH}:$DESTINATION"">> "${HOME}/.profile"
		echo "Setting path in ~/.profile"
		echo "Logout and login may be required before new path takes effect."
	fi'
	if [ "$pathonly" ]; then
		exit 0
	fi
fi # fi from -z uninstall, above
###########
# removing old installations
###########
bash -lc 'echo "Checking for existing installations..."
for file in $components substring-processor.sh $components2; do
	existing="$(which $file 2>/dev/null)"
	if [ "$existing" ]; then
		echo "removing $existing"
		rm -f "$existing" 2>/dev/null || sudo rm "$existing"
		if [ "$CYGWIN" ]; then
			echo "removing $DESTINATION2$cygwin_only"
		elif [ "$LINUX" ]; then
			echo "removing $HOME/.icons/$linux_only"
		fi
	fi
	# remove programme file in usr/local/bin or $HOME/bin or other destination
	rm -f "/usr/local/bin/$file" 2>/dev/null
	rm -f "$HOME/bin/$file" 2>/dev/null
	rm -f "$DESTINATION/$file" 2>/dev/null
	existing=""
done'
if [ "$CYGWIN" ] && [ "$$cygwin_only" ]; then
	rm "$DESTINATION2$cygwin_only" 2>/dev/null
	rm /cygdrive/c/Users/"$USERNAME"/Desktop/SubString.lnk 2>/dev/null
elif [ "$DARWIN" ] && [ "$osx_only" ]; then
	rm -r /Applications/$osx_only 2>/dev/null
	rm -r $HOME/Desktop/$osx_only 2>/dev/null
elif [ "$linux_only" ]; then
	rm "$HOME/.icons/$linux_only" 2>/dev/null
	rm $HOME/Desktop/SubString.desktop 2>/dev/null
fi
if [ "$uninstall" ]; then
	exit 0
fi
##########
# install files
#########
# installing components
echo ""
echo "Installing files to $DESTINATION"
echo "It may be necessary to enter an admin password."
mkdir -p "$DESTINATION" 2> /dev/null|| sudo mkdir -p "$DESTINATION"
for file in $components; do
	cp "$sourcedir/$file" "$DESTINATION/" 2> /dev/null|| sudo cp "$sourcedir/$file" "$DESTINATION/"
	if [ "$problem" ]; then
		echo "Installation encountered problems. Manual installation may be required." >&2
		exit 1
	fi
done
if [ "$CYGWIN" ]; then
	cp "$sourcedir/$cygwin_only" "$DESTINATION2"
elif [ "$DARWIN" ]; then
	:
else
	mkdir $HOME/.icons 2>/dev/null
	cp "$sourcedir/$linux_only" $HOME/.icons
fi
echo "The following files were placed in $DESTINATION:"
echo "$components $(if [ "$CYGWIN" ]; then echo "$cygwin_only"; elif [ "$DARWIN" ]; then :;else echo "$linux_only placed in $HOME/.icons";fi)" | tr ' ' '\n'
echo ""
# installing components2
for file in $components2; do
		if [ "$diagnostic" ]; then
			echo "Copying $file to $DESTINATION3/$(dirname $file)"
		fi
		cp $sourcedir/$file $DESTINATION3/$(dirname $file) 2> /dev/null|| sudo cp $sourcedir/$file $DESTINATION3/$(dirname $file)
	done
if [ "$DESTINATION3" ]; then
	echo "The following files were placed in $DESTINATION3:"
	echo "$components2" | tr ' ' '\n'
fi
# create Windows shortcuts if under cygwin
if [ "$CYGWIN" ]; then
	cd "$sourcedir" 2>/dev/null
	mkshortcut -n SubString -i /SSicon.ico -w "$HOME" -a "-i /SSicon.ico /bin/bash -l /usr/local/bin/substring.sh" /bin/mintty
	read -t 10 -p 'Create shortcut on the desktop? (Y/n) ' d < /dev/tty
	if [ "$d" == "y" ] || [ "$d" == "Y" ] || [ -z "$d" ]; then
		cp ./SubString.lnk /cygdrive/c/Users/"$USERNAME"/Desktop/ || echo "Could not find desktop, shortcut created in $(pwd)."
	else
		echo "Created Windows shortcut in $(pwd)."
	fi
	cd - 2>/dev/null
	echo ""
	echo "Installation complete."
	echo "To start SubString, double-click on the SubString shortcut."
	echo "Feel free to move it anywhere convenient."
# create launcher if under Linux
elif [ "$LINUX" ]; then
	echo "[Desktop Entry]
Version=0.4
Encoding=UTF-8
Type=Application
Terminal=true
Name=SubString
Icon=SSicon
Exec="$DESTINATION/substring.sh"
StartupNotify=false" > $sourcedir/SubString.desktop
	chmod a+x $sourcedir/SubString.desktop
	read -t 10 -p 'Create launcher on the desktop? (Y/n) ' d < /dev/tty
	if [ "$d" == "y" ] || [ "$d" == "Y" ] || [ -z "$d" ]; then
		cp $sourcedir/SubString.desktop $HOME/Desktop/
	else
		echo "Launcher placed in $sourcedir."
	fi
	echo ""
	echo "Installation complete."
	echo "To start SubString, double-click on the SubString launcher."
	echo "Feel free to move it anywhere convenient."
# move launch script to appropriate place under OSX
elif [ "$DARWIN" ]; then
	cp -r "$sourcedir/$osx_only" /Applications || sudo cp -r "$sourcedir/$osx_only" /Applications 
	cp -r "$sourcedir/$osx_only" "$(dirname "$sourcedir")"
	echo "The application SubString was placed in your Applications folder."
	read -p 'Create icon on the desktop? (Y/n) ' d < /dev/tty
	if [ "$d" == "y" ] || [ "$d" == "Y" ] || [ -z "$d" ]; then
		cp -r "$sourcedir/$osx_only" $HOME/Desktop
	fi
	echo "Installation complete."
	echo
	echo "To start SubString, double-click on the SubString icon in your Applications folder $(if [ -e "$HOME/Desktop/$osx_only" ]; then echo "or on your desktop";fi)."
	echo "Feel free to move it anywhere convenient."
fi
sleep 10
echo "This window can now be closed."