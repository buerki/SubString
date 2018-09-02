#! /usr/bin/env python3
# -*- coding:UTF-8 -*-
################################################################################
#
# Copyright (c) 2018 Cardiff University; written by Vigneshwaran Muralidaran
#                                        and Andreas Buerki
# licensed under the EUPL V.1.1.
#
# substringA.py is written to work in conjunction with the mwetoolkit 
# (https://gitlab.com/mwetoolkit/mwetoolkit3)
#
################################################################################
"""
    This script consolidates the frequencies of a list of candidate MWEs 
    (i.e. n-grams). In the process, the frequencies of substrings are reduced
    by the frequencies of their superstrings and a consolidated list with n-grams 
    of different lengths is produced without an inflation of the overall word count.

    The input file needs to contain a list of MWE candidates, formatted in the
    XML format of the mwetoolkit3 (http://mwetoolkit.sourceforge.net/PHITE.php).

    Installation: 
    First the mwetoolkit itself must be installed, follow instructions at
    http://mwetoolkit.sourceforge.net/PHITE.php. Then place this script inside
    the 'bin' directory provided by mwetoolkit (or copy the contents of the 'bin' 
    directory as well as this script into a convenient location, such as 
    /usr/local/bin).
    
    Operation:
    Typically, this script would be used as a further filtering stage in a
    MWE extraction procedure using the mwetoolkit (after step 4, below):

        1) indexation of corpus using mwetoolkit:
            > index.py -v --from PlainCorpus -i index-enwiki/enwiki enwiki.txt

        2) extract MWE candidates using mwetoolkit:
            > candidates.py -n 2:9 -v -S --corpus-from=BinaryIndex index-enwiki/enwiki.info > wikicand.xml

        3) add frequencies of a corpus (needed for step 4) using mwetoolkit:
            > counter.py -v -sg -i index-enwiki/enwiki.info wikicand.xml > wikicand-count.xml

        4) apply frequency filter using mwetoolkit:
            > filter.py -v -t enwiki:3 wikicand-count.xml > wikicand-count-f2.xml

        5) frequency-consolidate list using this script:
            > substringA.py -zl wikicand-count-f2.xml > wikicand-consolidated.xml
    
    For help, run the script without any options or input files.
"""
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
from __future__ import absolute_import

from libs import util
from libs import filetype
import logging
import sys
     
################################################################################     
# GLOBALS     
version = "version: 1.0"
usage_string = """\
Usage: {progname} [OPTIONS] <input-file>
Performs frequency consolidation on MWE candidates in an input file.

The <input-file> must be formatted in mwetoolkit's XML format. See README for
more information.

OPTIONS may be:
    
--to <output-filetype-ext>
    Convert input to given filetype extension.
    (By default, keeps input in original format):
    {descriptions.output[ALL]}
    
-z OR --retainzero
    Retain candidates with zero frequency after frequency consolidation
    
-l OR --logfreqconsol
    Log the entities whose frequencies were adjusted during consolidation
    The log will be sent to standard out and also to a file named 'candidates_updated.xml'
    in the current directory.

-V OR --version
    display the version number of the script

{common_options}
"""
adjust_table = []
entity_number = 1
consolidation_logged = False
zero_retained = False

input_filetype_ext = None
output_filetype_ext = None
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
#handler = logging.FileHandler('candidates_updated.xml')
#handler.setLevel(logging.INFO)
#logger.addHandler(handler)

################################################################################

class SubstringAHandler(filetype.ChainedInputHandler):
    def before_file(self, fileobj, ctxinfo):
        if not self.chain:
            self.chain = self.make_printer(ctxinfo, output_filetype_ext)     
        self.chain.before_file(fileobj, ctxinfo)
        
    def after_file(self, fileobj, ctxinfo):
        sort_adjust_table(4)
        
        for printcand in adjust_table:
            if(len(printcand) > 5):
                to_print_2 = ""
                to_print_5 = ""
                to_print_1 = "<cand candid=\""+str(printcand[4])+"\">\n    <ngram>"  # candidates[4] - Candidate ID
                for wlst in printcand[1].word_list:
                    for fcounts in wlst.freqs:
                        to_print_2 += "<w surface=\""+wlst.surface+"\"><freq name=\"case1\" value=\""+str(fcounts.value)+"\" />"
                to_print_3 = "</w> <freq name=\"case1\" value=\""+str(printcand[3])+"\" /></ngram>\n"
                to_print_4 = "    <occurs>\n    <ngram>"
                for wlst in printcand[1].word_list:
                    to_print_5 += "<w surface=\""+wlst.surface+"\" /> "
                for wocc in printcand[1].occurs:
                    printsource = wocc.sources
                to_print_6 = "<freq name=\"case1\" value=\""+str(printcand[3])+"\" /><sources ids=\""+str(printsource)+"\" /> </ngram>\n    </occurs>\n" 
                to_print_7 = "</cand>\n"
                
                to_print = to_print_1+to_print_2+to_print_3+to_print_4+to_print_5+to_print_6+to_print_7
                logger.info(to_print)                   
            self.chain.handle(printcand[1],ctxinfo)
        self.chain.after_file(fileobj, ctxinfo)
        
    def _fallback_entity(self, entity, ctxinfo):
        """
        @param entity: The `Ngram` that is being read from the XML file.
        """
    
        global entity_number
        entity_list = []
        
        #for wlst in entity.word_list:
            #for fcounts in wlst.freqs:
                #print(wlst.surface,fcounts.value) #NGRAM TOKENS, TOKEN FREQUENCIES
            
        #print("NGram size "+str(len(entity)))     #NGRAM SIZE   
        
        for nfreq in entity.freqs:
            ngram_freq = nfreq.value               #NGRAM FREQUENCY   
           
        for mocc in entity.occurs:
            ngram_source = mocc.sources            #NGRAM INDICES
            for ngram_occ_freq in mocc.freqs:
                occ_freq_val = ngram_occ_freq.value 
        
        if(entity.freqs):                          #Input xml file; two different formats
            entity_list.append(len(entity))
            entity_list.append(entity)
            entity_list.append(ngram_source)
            entity_list.append(ngram_freq)
            entity_list.append(entity_number)
        else:
            entity_list.append(len(entity))
            entity_list.append(entity)
            entity_list.append(ngram_source)
            entity_list.append(occ_freq_val)
            entity_list.append(entity_number)
        
        update_adjust_table(entity_list)        # A global table; Sorted in descending order of frequency 
        entity = handle_frequency(entity)
        entity_number += 1
        
        
################################################################################
def handle_frequency(entity):
    global adjust_table
   
    for mocc in entity.occurs:
            ngram_source = mocc.sources
    
    ngram_size = len(entity)
   
    for e_tablelist in(adjust_table):
        if(e_tablelist[0] > ngram_size):    #CASE 1: Current candidate's ngram is smaller.
            for e_line_index in e_tablelist[2]:
                e_split = e_line_index.split(':')
                e_line_no = e_split[0]
                e_index = e_split[1].split(',')
                e_small = e_index[0]
                e_large = e_index[len(e_index)-1]
                
                for ngram_line_index in ngram_source:
                    ngram_split = ngram_line_index.split(':')
                    ngram_line_no = ngram_split[0]
                    ngram_index = ngram_split[1].split(',')
                    ngram_small = ngram_index[0]
                    ngram_large = ngram_index[len(ngram_index)-1]
                    # Adjust the frequency of the entry in Adjust Table 
                    if((int(e_line_no) == int(ngram_line_no)) and (int(ngram_small) >= int(e_small)) and (int(ngram_large) <= int(e_large))):
                        adjust_source_ids(entity, ngram_line_index)
                        adjust_freq(entity)
        if(e_tablelist[1] == entity):
            e_tablelist[3] = len(e_tablelist[2])
                        
        if(e_tablelist[0] < ngram_size):
            for ngram_line_index in ngram_source:
                ngram_split = ngram_line_index.split(':')
                ngram_line_no = ngram_split[0]
                ngram_index = ngram_split[1].split(',')
                ngram_small = ngram_index[0]
                ngram_large = ngram_index[len(ngram_index)-1]
                
                for e_line_index in e_tablelist[2]:
                    e_split = e_line_index.split(':')
                    e_line_no = e_split[0]
                    e_index = e_split[1].split(',')
                    e_small = e_index[0]
                    e_large = e_index[len(e_index)-1]
                    
                    if((int(e_line_no) == int(ngram_line_no)) and (int(e_small) >= int(ngram_small)) and (int(e_large) <= int(ngram_large))):
                        adjust_source_ids(e_tablelist[1], e_line_index)
                        adjust_freq(e_tablelist[1])
                        e_tablelist[3] = len(e_tablelist[2])    
    return entity

def adjust_source_ids(entity, ngram_line_index):
    for e_tablelist in (adjust_table):
        if(e_tablelist[1] == entity):
            for occurrence in e_tablelist[1].occurs:
                for source_ids in occurrence.sources:
                    if(source_ids == ngram_line_index):
                        occurrence.sources.remove(ngram_line_index)
    
            
def adjust_freq(entity):
    for e_tablelist in (adjust_table):
        if(e_tablelist[1] == entity):
            for freq in e_tablelist[1].freqs:
                freq.value = freq.value-1-freq.value
                e_tablelist[1].add_frequency(freq)
            for occ in e_tablelist[1].occurs:
                occ_freq = occ.freqs
                for of in occ_freq:
                    of.value = of.value-1-of.value
                    occ.add_frequency(of)
                    if(occ.get_freq_value(of.name)==0 and zero_retained == False):
                        adjust_table.remove(e_tablelist)
            if(consolidation_logged == True and (len(e_tablelist) < 6)):
                e_tablelist.append('Adjusted')
    return None
output_filetype_ext
def update_adjust_table(entity_list):
    global adjust_table
    adjust_table.append(entity_list) 
    sort_adjust_table(0)
    return None

def sort_adjust_table(updatekey):
    if(updatekey==0):
        adjust_table.sort(key=getKeyNgramSize, reverse=True)
    if(updatekey==4):
        adjust_table.sort(key=getKeyEntityOrder)
    
def getKeyNgramSize(item):
    return item[0]

def getKeyEntityOrder(item):
    return item[4]

################################################################################

def treat_options( opts, arg, n_arg, usage_string ) :
    """
        Callback function that handles the command line options of this script.
        
        @param opts The options parsed by getopts. Ignored.
        
        @param arg The argument list parsed by getopts.
        
        @param n_arg The number of arguments expected for this script.    
    """
    global zero_retained
    global consolidation_logged
    global input_filetype_ext
    global output_filetype_ext
    
    ctxinfo = util.CmdlineContextInfo(opts)
    util.treat_options_simplest(opts, arg, n_arg, usage_string)
    
    for o, a in ctxinfo.iter(opts):
        if o in ("-z","--retainzero") :
            zero_retained = True
        elif o in ("-l","--logfreqconsol") :
            consolidation_logged = True
            handler = logging.FileHandler('candidates_updated.xml')
            handler.setLevel(logging.INFO)
            logger.addHandler(handler)
        elif o in ("-V","--version") :
            print(version)
            sys.exit(0)
        elif o == "--to":
            output_filetype_ext = a
        else:
            raise Exception("Bad arg: " + o)
            

################################################################################
# MAIN SCRIPT
if len(sys.argv[0:]) < 2:
    print("You must provide arguments to this script")
    print(usage_string)
    sys.exit(2)
longopts = [ "retainzero", "logfreqconsol", "version", "to="]
args = util.read_options( "zlV", longopts, treat_options, -1, usage_string )
filetype.parse(args, SubstringAHandler(), input_filetype_ext)       
