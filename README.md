![alt](icon.png)
SubString v0.9.1 
================

The SubString package is a set of Unix Shell scripts used to consolidate frequencies of word n-grams of different length. In the process, the frequencies of substrings are reduced by the frequencies of their superstrings and a consolidated list with n-grams of different length is produced without an inflation of the overall word count. The functions performed by this package will primarily be of interest to linguists and computational linguists working on formulaic language, multi-word sequences and other phraseological phenomena.

A. Frequency Consolidation
--------------------------

To illustrate how frequency consolidation among different length n-grams proceeds, let us assume we have as input the n-grams in (1)a. These will have been extracted from a corpus and their frequency of occurrence in the corpus is indicated by the number succeeding each n-gram.

The 4-gram 'have a lovely time' occurs with a frequency of 15. The trigrams 'have a lovely' and 'a lovely time' occur 58 and 44 times respectively. 15 of those occurrences are, however, occurrences as part of the superstring 'have a lovely time' (since they are substrings of 'have a lovely time'). To get the consolidated frequency of occurrence for 'have a lovely' and 'a lovely time' (i.e. the occurrences of these trigrams on their own, NOT counting when they occur in a longer string), we therefore deduct the frequency of their superstring (15) from their own frequency. This results a consolidated frequency of 43 for 'have a lovely' (i.e. 58 minus 15) and 29 for 'a lovely time' (i.e. 44 minus 15), as shown in (1)b.

The remaining bigrams ('have a', 'a lovely' and 'lovely time') are also substrings of 'have a lovely time' and therefore also need to have their frequency reduced by 15 (resulting in a frequency of 34692 for 'have a', 86 for 'a lovely' and 30 for 'lovely time'. In addition, 'have a' and 'a lovely' are substrings of 'have a lovely' and therefore the frequency of 'have a lovely' which is now 43, needs to be deducted from their frequencies. This results in a new frequency of 34649 for 'have a' and 43 for 'a lovely'. 'a lovely' and 'lovely time' are furthermore substrings of 'a lovely time' and consequently need to have their frequencies reduced by that of 'a lovely time' (i.e. by 29): the consolidated frequency of 'a lovely' is now 14, that of 'lovely time' is 1. The output of the frequency consolidation is shown in (1)b.

       (1)a                          (1)b
       
       have a lovely time  15        have a lovely time   15
       have a lovely       58        have a lovely        43
       a lovely time       44        a lovely time        29
       have a           34707        have a            34649
       a lovely           101        a lovely             14
       lovely time         45        lovely time           1

A more in-depth theoretical description and justification of the algorithm is currently in preparation. See also O'Donnell (2011) at
http://icame.uib.no/ij35/Matthew_Brook_ODonnell.pdf for a discussion of issues
involved and alternative approaches.


B. Components
-------------

The current release of the SubString package contains the following components:

*	`substring.sh`     The main script for user interaction

*	`cutoff.sh`        Performs frequency cut-offs

*	`listconv.sh`      Can be used to convert input lists to required format
                    
*	`README.txt`       this document

*	`test_data`        a directory containing test data

*	`EUPL.pdf`         a copy of the European Union Public License under which SubString is licensed.


C. Installation
---------------

SubString was tested on MacOS X (v. 10.6 and 10.7) and Ubuntu Linux (versions Xubuntu 9.04 and 10.04), but should run on all platforms that can run a bash script.

Generally, all scripts (i.e. the files ending in .sh) should be placed in a location that is in the user's $PATH variable (or the location should be added to the $PATH variable) so they can be called from the command line. A good place to put the scripts might be /usr/local/bin.

Detailed instructions of how to do this are given here for MacOS and Ubuntu:

1. open the Terminal application 
      MacOS X: in Applications/Utilities
      Ubuntu Linux: via menu Applications>Accessories>Terminal
2. type: `mkdir /usr/local/bin`	(it may say 'File exists', that's fine)
3. type: `echo $PATH` (if you can see /usr/local/bin somewhere in the
      output, move to step 8, if not carry on with the next step)
4. type: `cd $HOME`
      type: `cp .profile .profile.bkup` (if it says there no such file,
      that's fine)
5. type: `vi .profile`
6. move to an empty line and press the i key, then enter the
      following: `PATH=/usr/local/bin:$PATH`
7. press ESC, then type `:wq!`
8. move into the SubString directory. This can be done by typing `cd `      (make sure there is a space after `cd `) and then dragging the SubString folder onto the Terminal window and pressing return.
9. type: `sudo cp *.sh /usr/local/bin` (you will need to enter an admin password)

      Done!

The installation can be verified by calling each script's help function for the command line of a Terminal window:

1. open a new terminal window

2. Type `substring.sh -h` and hit enter. Try the same with `cutoff.sh -h` and `listconv.sh -h.`

3. If the help texts appear, all is in order.

For further tests, you may wish to run SubString on the test data (see next section)


D. Operation
------------


**LISTCONV.SH**

substring.sh (below) requires n-gram lists to be formatted in the following fashion: n<>gram<>	0[	0]
That is, an n-gram (with constituents either delimied by diamonds (as shown) or the unicode character interpunct (middle dot)), followed by a tab and the frequency count, optionally followed by another tab and a document count. This script can be used to convert n-gram lists into this format. listconv.sh is able to convert output lists created with the N-Gram Processor (http://buerki.github.io/ngramprocessor), the Ngram Statistics Package (Text-NSP, <http://ngram.sourceforge.net>) or those created by NGramTools (http://homepages.inf.ed.ac.uk/lzhang10/ngram.html or http://morphix-nlp.berlios.de/manual/node28.html).

To convert an n-gram list, simply supply the names of the files to
be converted as arguments: 

	listconv.sh FILE+

Where FILE+ is the name of one or more lists to be converted (if the list is not in the current working directory, the path needs to be indicated as well, i.e. /path/to/directory/list.lst). listconv.sh will convert the lists and create a backup of the original unconverted lists with the suffix .bkup in the same directory. More information on listconv.sh is available from the help function of listconv.sh which is called by typing listconv.sh -h



**CUTOFF.SH**

cutoff.sh can be used to enforce frequency-cut-offs on n-gram lists prior to consolidation. This is how cutoff.sh is used:

	cutoff.sh -f '(CUTOFF REGEX)' FILE+
	
Where '(CUTOFF REGEX)' stands for a regular expression detailing the frequency cut-off to be applied. This needs to be quoted (i.e. have '( )' around it). Cut-off frequencies need to cover the frequencies that one wishes to filter out. For example, if all n-grams with a frequency of less then 10 should be filtered out, the appropriate regular expression would be '([0-9])'. Further examples are:

			<11      '([0-9]|[1][0])'
			<12      '([0-9]|[1][0-1])'
			<13      '([0-9]|[1][0-2])'
			<14      '([0-9]|[1][0-3])'
			<15      '([0-9]|[1][0-4])'
			<16      '([0-9]|[1][0-5])'
			<26      '([1-9]|1[0-9]|2[012345])'

FILE+ again stands for one or more n-gram lists that should be frequency-filtered.
	


**SUBSTRING.SH**

substring.sh is the script that manages the frequency consolidation. Before detailing its operation, it is useful to highlight three areas of detail on how substring.sh handles frequency consolidation.

Firstly, n-gram lists extracted from a source document usually need to be filtered to be useful. Various filters are employed for this purpose including the use of minimal frequencies of occurrence or threshold values of statistical association measures. substring.sh accepts lists that have already been filtered in one way or another. For frequency filtering, the script cutoff.sh, which is included in the SubString package, can be used as explained above.

Secondly, regardless of the type of filter applied, frequency consolidation with substrd.sh can be performed more accurately if the script has access to the unfiltered (or less severely filtered) n-gram lists as well as the filtered lists given as input. This applies to cases where n-gram lists of length n=5 and above are involved. substring.sh therefore includes an optional preparatory stage which looks up certain n-grams in unfiltered lists prior to frequency consolidation in order to resolve overlaps between n-grams. The script can also be run without this preparatory stage.

Thirdly, n-gram lists to be consolidated by substring.sh need to conform to the following conditions:

1. only one length of n-gram per input list (i.e. bigrams must be in
   a separate input file from trigrams from 4-grams, etc.).
2. minimally 2 input lists must be provided
3. it is strongly recommended that n-gram lists do not contain
   n-grams across sentence boundaries
4. input lists must be of the format n<>gram<>	0[	0]
 
that is, the words of the n-grams are separated by '<>' then a tab follows, then the FREQUENCY COUNT. Optionally, a tab and possibly some more information may follow. This additional information could be document counts or measures of association strength. It is important to note that only the first number after the n-gram (which is assumed to be the frequency) is consolidated and will appear in the consolidated output list. The only exception to this is if the -d option (see below) is active, in which case it is assumed that the number following the frequency is a document count (i.e. a count of the number of documents in which the n-gram appears) and it will appear in the output list.

To convert lists into the required input format use listconv.sh as described above.


To consolidate n-gram lists, substring.sh is called like this:
	
		substring.sh [OPTIONS] FILE+
	
FILE+ again stands for the input lists, i.e. the lists that should be consolidated. The options will be discussed as we go along. A simple example, involving the data in example (1)a above, can be run as follows: (the necessary input lists are supplied in the directory SubString/test_data/example1)
	
1) move to the directory example1 in the test_data directory
2) type the following and press enter:
	
		substring.sh 2-gram.lst 3-gram.lst 4-gram.lst
	
substring.sh now takes the input lists, consolidates them and displays the consolidated output which should correspond to the result in example (1)b (although listed in a different order). The output is sorted according to the n-grams themselves, rather than their frequency. To have the output sorted in decending order of frequency (n-gram with highest frequency first), use the -f option:

		substring.sh -f 2-gram.lst 3-gram.lst 4-gram.lst

Now the n-grams appear in the order of frequency. To see processing information, the -v option can be invoked. While the -v option is active, the result will not be displayed on screen (as it would be mingled with the processing information that is being displayed). Instead, the result is put in an output file in the current working directory: 2.lst-4.lst.substrd. The default name for the consolidated list ends in .substrd, but depending on the input lists, the preceding part of the name will be different. It is possible to specify where the output list should go and how it should be named by invoking the -o option followed by output file name (and a path if desired). This holds regardless of whether the -v option is active. Here's an example:
	
	substring.sh -vo $HOME/Desktop/OUT.lst 2-gram.lst 3-gram.lst 4-gram.lst
	
This will name the consolidated list 'OUT.lst' and place it in the user's desktop directory. The default .substrd - suffixed file in the working directory is not created.

A more complex example is the following. Input lists for this example are provided in SubString/test_data/example2. The lists with the extension .cut.([0-9]) have been frequency-filtered with cutoff.sh and contain only n-grams with a minimum frequency of 10. The lists without extension contain unfiltered lists of n-grams.

1. move to the directory example2 in the test_data directory
2. type the following (all on one line), then press enter:

		substring.sh -v 2-grams.cut.\(\[0-9\]\) 3-grams.cut.\(\[0-9\]\) 4-grams.cut.\(\[0-9\]\) 5-grams.cut.\(\[0-9\]\) 6-grams.cut.\(\[0-9\]\) 7-grams.cut.\(\[0-9\]\)
	
substring.sh takes longer to process the lists this time because the amount of data is larger (lists are based on about 120,000 words of text). The output (the .substrd file) is again placed in the current directory. The output list will not contain any 7-grams because there are none above the chosen cutoff of 9 (the list 7-grams.cut.([0-9]) is in fact empty) and there is only one 6-gram above the cutoff. The list produced should be identical to 2.lst-6.lst.substrd-GOLD1 found in the directory example2. The consolidation will have produced some n-grams with frequencies below 10. To make sure the list only contains n-grams with a frequency of at least 10, cutoff.sh can be used to remove any n-grams below this frequency.
	
As mentioned earlier, frequency consolidation can be performed more accurately if the script has access to the unfiltered (or less severely filtered) n-gram lists as well as the filtered lists given as input. Unfiltered lists (or less severely filtered lists) are supplied using the -u option (u stands for 'unfiltered'). Each unfiltered list to be considered needs to be passed separately and the -u option will only accept lists of n-grams such that n > 3 (i.e. unfiltered lists of 4-grams and longer n-grams). Using the example data in example2, the unfiltered lists are passed like this:

	substring.sh -v -u 4-grams -u 5-grams -u 6-grams -u 7-grams 2-grams.cut.\(\[0-9\]\) 3-grams.cut.\(\[0-9\]\) 4-grams.cut.\(\[0-9\]\) 5-grams.cut.\(\[0-9\]\) 6-grams.cut.\(\[0-9\]\) 7-grams.cut.\(\[0-9\]\)
	
The list produced should be identical to 2.lst-6.lst.substrd-GOLD2 found in the directory example2. This list will be slightly different from the previous one. It now contains a few 7-grams because these were taken from the unfiltered lists supplied and integrated into the results. Again, to make sure we only have n-grams with a frequency of at least 10, cutoff.sh can be used to remove n-grams. When unfiltered (or less severely filtered) lists are supplied, they should be passed so that they parallel each of the filtered input lists (except for bigram and trigram lists which must not be matched with unfiltered lists): if we supply an unfiltered 4-gram list, we should also supply an unfiltered 5-gram list, 6-gram list, etc. up to the maximum length of filtered n-gram lists supplied to the script. It is recommended that the unfiltered lists supplied are minimally filtered to exclude n-grams with frequency 1. When processing very large amounts of data, it will be more convenient to limit unfiltered lists to n-grams of a minimum frequency of 3 or even more. This can be achieved using the cutoff.sh script to filter unfiltered lists prior to consolidation.
	
In the data of example2, the inclusion of unfiltered lists did not alter the result by much. In some cases, especially when processing large amounts of data and using high cut-off frequencies, the provision of additional unfiltered lists can improve the accuracy of the consolidation more significantly. However, even with the use of additional unfiltered lists, it is sometimes unavoidable that the frequency consolidation of some n-grams is inaccurate, resulting in them receiving negative frequencies. This is caused by an insufficient resolution of overlapping n-grams and cannot be automatically resolved. In such cases the n-grams concerned are not listed in the output file but instead are written to a special output file named 'neg_freq.lst' which is also placed in the current working directory. The user is also notified of the fact if the -v option is active.

Running substring.sh on the data in the 'example3' directory of the test_data folder as shown below will result in a neg_freq.lst being created:

	substring.sh -v -u 4-grams -u 5-grams 2-grams.cut.\(\[0-3\]\) 3-grams.cut.\(\[0-3\]\) 4-grams.cut.\(\[0-3\]\) 5-grams.cut.\(\[0-3\]\)

The output list should be identical to 2.lst-5.lst.substrd.GOLD1 in the example3 directory. The input lists in the 'example3' directory contain a document count (i.e. a count of the number of documents each n-gram appears in) in addition to the frequency of each n-gram. This information is not normally carried over to the consolidated list. If the -d option is passed to substring.sh, however, the document counts (which must appear after the frequency, separated by a tab) appear in the consolidated list. The document counts are adjusted if necessary so that they maximally equal the frequency of a consolidated n-gram, though they might of course be lower than that. To make document counts appear in the consolidated list, enter:

	substring.sh -v -d -u 4-grams -u 5-grams 2-grams.cut.\(\[0-3\]\) 3-grams.cut.\(\[0-3\]\) 4-grams.cut.\(\[0-3\]\) 5-grams.cut.\(\[0-3\]\)

The list produced should be identical to 2.lst-5.lst.substrd.GOLD2.

E. Known Issues
---------------

None reported at this time. Issues can be raised at http://github.com/buerki/SubString/issues


F. Warning
----------

SubString is still at beta stage. It is recommended that data to be processed are backed up before the software is used. Further, as article 7 of of EUPL states, the Work is a work in progress, which is continuously improved by numerous contributors. It is not a finished work and may therefore contain defects or “bugs” inherent to this type of software development.
For the above reason, the Work is provided under the Licence on an “as is” basis and without warranties of any kind concerning the Work, including without limitation merchantability, fitness for a particular purpose, absence of defects or errors, accuracy, non-infringement of intellectual property rights other than copyright as stated in Article 6 of this Licence.
This disclaimer of warranty is an essential part of the Licence and a condition for the grant of any rights to the Work.


G. Copyright, licensing, download
---------------------------------

SubString is (c) 2011-2013 Andreas Buerki, licensed under the EUPL V.1.1. (the European Union Public License).

The project resides at http://buerki.github.com/SubString/ and new versions will be posted there. A mirror is kept at https://developer.berlios.de/projects/substrd . Suggestions and feedback are welcome. To be notified of new releases, go to https://github.com/buerki/SubString, click on the 'Watch' button and sign in.
