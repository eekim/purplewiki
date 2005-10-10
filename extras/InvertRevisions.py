#!/usr/bin/env python

# InvertRevisions.py
# 2005 March 15
# Jonathan Cheyer
#
# workaround for bug in PurpleWiki-0.96alpha/extras/backendConvert.pl
# License: GPL Version 2, http://www.gnu.org/copyleft/gpl.html

import sys
import os

def getTotal(current):
    f = open(current, "r")
    total = int(f.readline())
    f.close()
    return total

def doSwap(directory, suffix, a, b):
    fileA = "%s/%s%s" % (directory, a, suffix)
    fileB = "%s/%s%s" % (directory, b, suffix)
    fileTMP = "%s/%s-TMP%s" % (directory, a, suffix)
    os.rename(fileA, fileTMP)
    os.rename(fileB, fileA)
    os.rename(fileTMP, fileB)

def swapFiles(directory, total):
    print "%s: " % (directory)
    for i in range((total) / 2):
        doSwap(directory, ".txt", i + 1, total - i)
        doSwap(directory, ".meta", i + 1, total - i)

def swapRecursiveFiles(wikiDirectory):
    for dirpath, dirnames, filenames in os.walk(wikiDirectory):
        for dir in dirnames:
            path = os.path.join(dirpath, dir)
            current = "%s/%s" % (path, "current")
            if (os.path.isfile(current)):
                total = getTotal(current)
                swapFiles(path, total)

def main():
    if len(sys.argv) != 2:
        print "%s <wikidb_directory>" % (sys.argv[0])
        sys.exit(1)
    swapRecursiveFiles(sys.argv[1])

main()
