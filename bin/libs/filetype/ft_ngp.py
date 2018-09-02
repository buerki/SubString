#!/usr/bin/python
# -*- coding:UTF-8 -*-

################################################################################
# Copyright 2018 Cardiff University
# with parts copyright 2010-2015 Carlos Ramisch, Vitor De Araujo, Silvio Ricardo Cordeiro,
# Sandra Castellanos
#
# ft_ngp.py is designed to work with mwetoolkit
#
# mwetoolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# mwetoolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with mwetoolkit.  If not, see <http://www.gnu.org/licenses/>.
#
################################################################################
"""
This module provides classes to manipulate files that are encoded in the
"Experimental" data set format.

You should use the methods in package `filetype` instead.
"""

from . import _common as common
from .. import util

################################################################################


class NGPInfo(common.FiletypeInfo):
    description = "Format of the N-Gram Processor, n-gram + frequency (n·gram·  78)"
    filetype_ext = "NGP"

    comment_prefix = "#"
    escaper = common.Escaper("${", "}", [
            ("$", "${dollar}"), ("/", "${slash}"), (" ", "${space}"),
            ("\t", "${tab}"), ("\n", "${newline}"), ("#", "${hash}")
    ])

    def operations(self):
        return common.FiletypeOperations(NGPChecker, None, NGPPrinter)

INFO = NGPInfo()

################################################################################

class NGPChecker(common.AbstractChecker):
    r"""Checks whether input is in NGP format."""
    def matches_header(self, strict):
        return not strict

################################################################################

class NGPPrinter(common.AbstractPrinter):
    valid_categories = ["candidates"]

    def __init__(self, ctxinfo, category, freq_source=None,
            lemmapos=False, surface_instead_lemmas=False, **kwargs):
        super(NGPPrinter, self).__init__(ctxinfo, category)
        self.freq_source = freq_source
        self.lemmapos = lemmapos
        self.surface_instead_lemmas = surface_instead_lemmas


    def handle_meta(self, meta, ctxinfo):
        """Print the header for the NGP dataset file,
        and save the corpus size."""
        #string_cand = "l1\tl2\tf\tN"

    def handle_candidate(self, entity, ctxinfo):
        """Print each `Candidate` as a NGP data set entry line.
        @param entity: The `Candidate` that is being read from the XML file.
        """
        string_cand = ""

        for w in entity :
#            if self.lemmapos :
#                string_cand += self.escape(w.lemma) + "/" + self.escape(w.pos) + "\t"
#            elif w.has_prop("lemma") and not self.surface_instead_lemmas :
#                string_cand += w.lemma + "\t"
#            else :
                string_cand += w.surface + "·"
        string_cand += "\t" + str(self.freq_value(ctxinfo, entity.freqs))

        self.add_string(ctxinfo, string_cand, "\n")


    def freq_value(self, ctxinfo, items):
        """Given a list of items with a `name` and a `value` attribute, return
        the item whose name is the same as that of `freq_source`.
        """
        for item in items:
            if self.freq_source is None or item.name == self.freq_source:
                return item.value

        ctxinfo.warn("Frequency source '%s' not found!" % self.freq_source)
        return 0

