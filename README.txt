SubString 0.7.1 (https://github.com/andy740/SubString)
======================================================

The SubString package is a set of Unix Shell scripts used to consolidate
frequencies of word n-grams of different length. In the process, the
frequencies of substrings are reduced by the frequencies of their
superstrings and a consolidated list with n-grams of different length is
produced without an inflation of the overall word count. The functions
performed by this package will primarily be of interest to linguists and
computational linguists working on formulaic language, multi-word
sequences and other phraseological phenomena.

A. Frequency Consolidation
--------------------------

To illustrate how frequency consolidation among different length n-grams
proceeds, let us assume we have as input the n-grams in (1)a. These will
have been extracted from a corpus and their frequency of occurrence in
the corpus is indicated by the number succeeding each n-gram.

The 4-gram 'have a lovely time' occurs with a frequency of 15. The
trigrams 'have a lovely' and 'a lovely time' occur 58 and 44 times
respectively. 15 of those occurrences are, however, occurrences as part
of the superstring 'have a lovely time' (since they are substrings of
'have a lovely time'). To get the consolidated frequency of occurrence
for 'have a lovely' and 'a lovely time' (i.e. the occurrences of these
trigrams on their own, NOT counting when they occur in a longer string),
we therefore deduct the frequency of their superstring (15) from their
own frequency. This results a consolidated frequency of 43 for 'have a
lovely' (i.e. 58 minus 15) and 29 for 'a lovely time' (i.e. 44 minus
15), as shown in (1)b.

The remaining bigrams ('have a', 'a lovely' and 'lovely time') are also
substrings of 'have a lovely time' and therefore also need to have their
frequency reduced by 15 (resulting in a frequency of 34692 for 'have a',
86 for 'a lovely' and 30 for 'lovely time'. In addition, 'have a' and 'a
lovely' are substrings of 'have a lovely' and therefore the frequency of
'have a lovely' which is now 43, needs to be deducted from their
frequencies. This results in a new frequency of 34649 for 'have a' and
43 for 'a lovely'. 'a lovely' and 'lovely time' are furthermore
substrings of 'a lovely time' and consequently need to have their
frequencies reduced by that of 'a lovely time' (i.e. by 29): the
consolidated frequency of 'a lovely' is now 14, that of 'lovely time' is
1. The output of the frequency consolidation is shown in (1)b.

(1) a	have a lovely time	15      b	have a lovely time	15
		have a lovely		58			have a lovely		43
		a lovely time		44			a lovely time		29
		have a			 34707			have a			 34649
		a lovely		   101			a lovely			14
		lovely time			45			lovely time			 1

A more in-depth theoretical description and justification of the
algorithm is currently in preparation.


B. Components
-------------

The current release of the SubString package contains the following
components:

substrd.sh          The main script for user interaction

cutoff.sh           Performs frequency cut-offs

listconv.sh         Can be used to convert input lists of n-grams
                    into the format required by substrd.sh
core_substring.sh   Contains the core algorithm and is called by
                    substrd.sh during processing
prep_stage.sh       Is called by substrd.sh if a preparatory processing
                    stage is requested (default)
README.txt          this document

test_data           a folder with test data

EUPL.pdf            a copy of the European Union Public License under
                    which SubString is licensed.


C. Installation
---------------

SubString was tested on MacOS 10.6 Snow Leopard and Ubuntu Linux, but
should run on all platforms that can run a bash script.

Generally, all scripts (i.e. the files ending in .sh) should be placed
in a location that is in the user's $PATH variable (or the location
should be added to the $PATH variable) so they can be called from the
command line. A good place to put the scripts might be /usr/bin.

Detailed instructions of how to do this are given here for MacOS and
Ubuntu:
	1) open the Terminal application 
	   MacOS X: in Applications/Utilities
	   Ubuntu Linux: via menu Applications>Accessories>Terminal
	2) type: cd $HOME
	3) type: mkdir /usr/bin	(it may say 'File exists', that's fine)
	4) type: echo $PATH (if you can see /usr/bin somewhere in the
       output, move to step 9, if not carry on with the next step)
	5) type: cp .profile .profile.bkup (if it says there no such file,
       that's fine)
	6) type: vi .profile
	7) move to an empty line and press the i key, then enter the
       following: PATH=/usr/bin:$PATH
	8) press ESC, then type :wq!
	9) move into the SubString directory. This can be done by typing cd
       (make sure there is a space after cd) and then dragging the SubString
       folder onto the Terminal window and pressing return.
	10)type: sudo cp *.sh /usr/bin (you will need to enter an admin
       password)
   Done!

The installation can be verified by calling each script's help function
for the command line of a Terminal window:

1) open a new terminal window

2) Type substrd.sh -h and hit enter. Try the same with core_substring.sh
   -h, prep_stage.sh -h, cutoff.sh -h and listconv.sh -h.

3) If the help texts appear, all is in order.

For further tests, you may wish to run SubString on the test data (see
next section)


D. Operation
------------

INPUT LISTS
SubString accepts n-gram lists as input for frequency consolidation.
Input lists must conform to the following conditions:

1)	only one length of n-gram per input list (i.e. bigrams must be in
    a separate input file from trigrams from 4-grams, etc.).
2)	minimally 2 input lists, maximally 16 input lists (recommended:
    around 7)
3)	it is strongly recommended that n-gram lists do not contain
    n-grams across sentence boundaries
4)	input lists must be of the format n<>gram<>	0[	0]
	that is, the words of the n-grams are separated by '<>' then a tab
    follows, then the frequency count. Optionally, a tab and possibly some
    other numbers follow, like document counts or measures of association
    strength. To convert lists into this format use listconv.sh as described
    below.



LISTCONV.SH
This script is used to convert n-gram lists into the format required
by SubString. listconv.sh is able to convert output lists created with
the NGram Statistics Package (Text-NSP, <http://ngram.sourceforge.net>)
or those created by NGramTools (http://homepages.inf.ed.ac.uk/lzhang10/
ngram.html or http://morphix-nlp.berlios.de/manual/node28.html).

To convert an n-gram list, simply supply the names of the files to
be converted as arguments: 

	listconv.sh list.lst

Where list.lst is the name of the list to be converted (if the list
is not in the current working directory, the path needs to be indicated
as well, i.e. /path/to/directory/list.lst). listconv.sh will convert the
list and create a backup of the original unconverted list with the
suffix .bkup in the same directory. To convert more than one list at the
same time, its name (or path) is added to the line above, i.e.
listconv.sh list1.lst list2.lst list3.lst. More information on
listconv.sh is available from the help function of listconv.sh which is
called by typing listconv.sh -h



SUBSTRD.SH
subsrd.sh is the script that manages the frequency consolidation.
Before detailing its operation, it is useful to highlight two areas of
detail on how substrd.sh handles frequency consolidation.

Firstly, n-gram lists extracted from a source document usually need
to be filtered to be useful. Various filters are employed for this
purpose including the use of minimal frequencies of occurrence or
threshold values of statistical association measures. substrd.sh is able
to apply a frequency filter during consolidation or it can accept lists
that have already been filtered in one way or another.

Secondly, regardless of the type of filter applied, frequency
consolidation with substrd.sh can be performed more accurately if the
script has access to the unfiltered n-gram lists (or less severely
filtered n-gram lists) as well as the filtered lists given as input.
This applies to cases where n-gram lists of length n=5 and above are
involved. substrd.sh therefore includes an optional preparatory stage
which looks up certain n-grams in unfiltered lists prior to frequency
consolidation in order to resolve overlaps between n-grams. The script
can also be run without this preparatory stage.

substrd.sh has two basic modes of operation: automatic and manual.
Each is discussed in turn:


1) automatic mode
In its default automatic mode, the script operates as follows:
	
		substrd.sh [OPTIONS] DIR 'CUTOFF REGEX'
	
At this stage the only relevant option is -v (for verbose
operation which displays processing information). DIR stands for the
directory in which the n-gram lists are located. In automatic mode, this
directory MUST contain ALL n-gram lists to be consolidated AND ONLY
them. No other files should be present in the directory or substrd.sh
will get confused. '(CUTOFF REGEX)' stands for a regular expression
detailing the frequency cut-off to be applied. This needs to be quoted
(i.e. have '( )' around it). Cut-off frequencies need to cover the
frequencies that one wishes to filter out. For example, if all n-grams
with a frequency of less then 10 should be filtered out, the appropriate
regular expression would be '([0-9])'. Further examples are:
			<11      '([0-9]|[1][0])'
			<12      '([0-9]|[1][0-1])'
			<13      '([0-9]|[1][0-2])'
			<14      '([0-9]|[1][0-3])'
			<15      '([0-9]|[1][0-4])'
			<16      '([0-9]|[1][0-5])'
			<26      '([1-9]|1[0-9]|2[012345])'
	
A simple example, involving the data in example (1)a above can be run as
follows: (the necessary input lists are supplied in the directory 
SubString/test_data/simple_example)
	
	1) move to the directory simple_example in the test_data directory
	2) type the following:
	
		substrd.sh -v . '([0-9]|[1][0])'
	
The dot means 'current directory'. substrd.sh now takes input
lists, applies the cut-off specified and consolidates the lists. When
substrd.sh has finished work, an additional file will be in the
specified input directory: 2.lst-4.lst.substrd. This is the consolidated
output list and should correspond to the result in example (1)b. The
consolidated list will always in end .substrd, but depending on the
input lists the preceding part of the name will be different.
	
As long as the -v option is active, the output of the script
will only go to a file with the extension .substrd in the directory
specified as input directory. If the -v is NOT active, the output is
displayed on screen (as well as put in the .substrd file) and can be
piped elsewhere.
	
A more complex example is the following. Input lists for this
example are provided in SubString/test_data/example1. 

		1) move to the directory example1 in the test_data directory
		2) type the following:
	
		substrd.sh -v . '([0-9])'
	
substrd.sh takes substantially longer to process the lists this
time because the amount of data is larger (based on n-grams of about
120,000 words of text) and because the preparatory stage is now
activated (it activates automatically when there are lists of 5-grams
and above among the lists to be consolidated). The output (the .substrd
file) is again placed in the specified directory. The output list will
not contain any 7-grams because there are none above the chosen cutoff
of 9 (i.e. '([0-9])') and there is only one 6-gram above the cutoff.
	
As mentioned earlier, the preparatory stage looks up certain
n-grams in unfiltered lists (i.e. in the input lists prior to the
application of the cutoff). By default, n-grams are only looked up if
their frequency is at least 2. When processing very large amounts of
data, it will be more convenient to limit the looking up to n-grams of a
minimum frequency of 3 or even more. If only n-grams with a frequency of
at least 3 should be looked up, the option -3 may be passed (i.e.
substrd.sh -v -3 . '([0-9])'). Any other frequency threshold for the
lookup of n-grams can be set by using the -c option followed by a
regular expression (i.e. substrd.sh -v -c '([0-4])' . '([0-9])').
	
Apart from the -v -3 and -c options introduced above, there is
one more important option for operation in automatic mode:
	
		-o	this omits the preparatory stage
	
To try this out, it is necessary to either delete or move the
output list (2.lst-6.lst.substrd), so that the directory again only
contains the lists to be consolidated. Then substrd.sh can be run with
the -o option:
	
		substrd.sh -vo . '([0-9])'
	
Again, the output list is put in the designated directory. In
the example data, this does not alter the result by much (if the output
files are compared, it can be seen that without preparatory stage there
is one less n-gram in the list). In some cases, especially when
processing large amounts of data and using high cut-off frequencies, use
of the preparatory stage can improve the accuracy of the consolidation.
However, even with the use of the preparatory stage it is sometimes
unavoidable that the frequency consolidation of some n-grams is
inaccurate, resulting in them receiving negative frequencies. This is
caused by an insufficient resolution of overlapping n-grams and cannot
be automatically resolved. In such cases the n-grams concerned are not
listed in the output file but instead are written to a special output
file named 'neg_freq.lst' which is also placed in the input directory.
If the -v option is active, the user is alerted to the issue. Running
substrd.sh -vo . '([0-9])' on the data in 'example2' in the test_data
folder will result in a neg_freq.lst being created.
	

2)	manual mode
To gain more complete control over the parameters of the
consolidation, the script can also be operated in a manual mode. In
manual mode, no cut-offs are applied by substrd.sh, instead it is
assumed that lists have already been filtered and are simply to be
consolidated. Each input list needs to be specified (as well as the
directory in which the lists reside) and if the preparatory stage is to
be used, all uncut lists to be considered must also be specified. The
manual mode is called by passing the -m option and specifying the input
lists as follows:
	
		substrd.sh -vm . 2-grams 3-grams 4-grams 5-grams 6-grams 7-grams
	
The example3 directory (in the test_data directory) contains
lists that have already been filtered and can now be consolidated in
manual mode using the model above.

Operation in manual mode, just like in the automatic mode,
produces as output a .substrd file in the designated directory. If the
preparatory stage is to be used while operating in manual mode, each of
the uncut lists to be searched needs to be passed to the script using
the -u option as follows: (using the -u option implies the -m option, so
-m does not need to be passed)
	
		substrd.sh -v -u 5-grams.uncut -u 6-grams.uncut -u 7-grams.uncut
        . 2-grams 3-grams 4-grams 5-grams 6-grams 7-grams
	
When substrd.sh asks whether to overwrite '6.lst-7.lst.substrd',
n should be pressed. After substrd.sh is run, one might wish to re-apply
a minimum frequency threshold as some of the consolidated n-grams will
now have frequencies below the cut-off. This can be done using cutoff.sh
(see below).


	
CUTOFF.SH
	cutoff.sh is used in the automatic mode of substrd.sh to enforce
frequency-cut-offs. It can also be used on its own for the same purpose
(for example in connection with the manual mode of substrd.sh. Cut-off
frequencies are passed as regular expressions in the same way as they
are passed in the automatic mode in substrd.sh (see above), for example
like this:

	cutoff.sh -f '([0-9]|[1][0-5])' list1.txt list2.txt


E. Known Issues
---------------

N-grams with hyphens (-) or apostrophes (') in initial position can
cause the script to throw errors in some cases. If this happens, it is
recommended that hyphens and apostrophies are replaced with a
placeholder and restored after processing.


F. Warning
----------

SubString 0.7 is at beta stage. It is recommended that all important
data are backed up before the script is used.


G. Copyright, licensing, download and mailing list
--------------------------------------------------

SubString 0.7.1 is (c) 2010-2011 Andreas Buerki, licensed under the EUPL
V.1.1. (the European Union Public License) as open source software.

The project is at https://github.com/andy740/SubString.
Suggestions and feedback are welcome.
