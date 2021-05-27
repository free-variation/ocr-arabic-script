#!/bin/bash
set -e

export LC_NUMERIC=C

PROG=${0##*/}
TMP=/tmp/${PROG}_$$
trap "rm $TMP* 2>/dev/null" EXIT

# Defaul values of arguments
DWSP=0
DPMS=0
NORM=0
REXT=".rec.txt"

###############################################################################

function usage
{
cat <<-EOF >&2

  Usage: $PROG [Options] gth-Dir rec-Dir rep-File

    Options:

         -s             Disregard white spaces
         -p             Disregard punctuation marks
         -n		Normalize some Arabic/Persian characters
         -e             File extension of recognized hypotheses
         -h             This help

EOF
exit
}
###############################################################################

###############################################################################
function cadFilter () {
    local l=""
    for l in ${1}/*${2}; do
	sed -r "s/ *$/ /" ${l}
    done |
	python3 -c "import unicodedata as ud, sys, re; sys.stdout.write(''.join(c for c in re.sub(r'\s', ' ', ud.normalize('NFD', sys.stdin.read()))))"
    #> RES_wo-PMs-WSs/gth_${B}.txt;
}
function cadFilter_pm () {
    local l=""
    for l in ${1}/*${2}; do
	sed -r "s/ *$/ /" ${l}
    done |
	python3 -c "import unicodedata as ud, sys, re; sys.stdout.write(''.join(c for c in re.sub(r'\s', ' ', ud.normalize('NFD', sys.stdin.read())) if ud.category(c)[0]!='P'))"
    #> RES_wo-PMs-WSs/gth_${B}.txt;
}
function cadFilter_pm_ws () {
    local l=""
    for l in ${1}/*${2}; do
	sed -r "s/ *$/ /" ${l}
    done |
	python3 -c "import unicodedata as ud, sys, re; sys.stdout.write(''.join(c for c in re.sub(r'\s', '', ud.normalize('NFD', sys.stdin.read())) if ud.category(c)[0]!='P'))"
    #> RES_wo-PMs-WSs/gth_${B}.txt;
}
function normalize () {
    cat - |
	python3 -c "import sys; sys.stdout.write(''.join(b if not (b in ['\u06A9', '\u06AA', '\u06AB', '\u06AC']) else '\u0643' for b in ''.join(c if not (c in ['\u0649','\u0620','\u06CC']) else '\u064A' for c in ''.join('' if (d in ['\u0640','\ufdfa']) else d for d in sys.stdin.read()))))"
	#python3 -c "import sys; sys.stdout.write(''.join(b if not (b in ['\u06A9', '\u06AA', '\u06AB', '\u06AC']) else '\u0643' for b in ''.join(c if not (c in ['\u0649','\u0620','\u06CC']) else '\u064A' for c in sys.stdin.read())))"
}

# Character Normalization
#'\u0649', '\u0620', '\u06CC'   ---->   '\u064A'
# ى    ؠ   ی   ------>   ي
#
#'\u06A9'  '\u06AA'  '\u06AB'  '\u06AC'   ---->   \u0643
# ک    ڪ    ګ    ڬ    ------->   ك
#
# Removing the \u0640 ('ARABIC TATWEEL') and \ufdfa ('ARABIC LIGATURE SALLALLAHOU ALAYHE WASALLAM')

###############################################################################



# MAIN SOURCE
###############################################################################

#normalize $1
#exit 1
while [ $# -ge 1 ]; do
    #if [ ${1:0:2} = "-o" ]; then OUTDIR=$2; shift;
    #    [ -d $OUTDIR ] || { echo "ERROR: Dir \"$OUTDIR\" does not exist !"; exit 1; }
    #elif [ ${1:0:2} = "-s" ]; then OFFSET=$2; shift;
    #elif [ ${1:0:2} = "-t" ]; then STROKEWIDTH=$2; shift;
    #elif [ ${1:0:2} = "-c" ]; then STROKECOLOR=$2; shift;
    if [ ${1:0:2} = "-s" ]; then DWSP=1;
    elif [ ${1:0:2} = "-p" ]; then DPMS=1;
    elif [ ${1:0:2} = "-n" ]; then NORM=1;			   
    elif [ ${1:0:2} = "-e" ]; then shift; REXT=$1;
    elif [ ${1:0:2} = "-h" ]; then usage; exit 0;
    else break;
    fi
    shift
done

if [ $# -lt 2 -o $# -gt 3 ]; then
    usage
    exit 1
fi
gthDir=$1
recDir=$2
repFile=$3
if [ ! -d "$gthDir" -o ! -d "$recDir" ]; then
    echo "One of the directories: \"$gthDir\" or \"$recDir\" doesn't exist !" 1>&2
    exit 1
fi

if [ "${NORM}" -eq 0 ]; then
    if [ "${DWSP}" -eq 0 -a "${DPMS}" -eq 0 ]; then
	cadFilter $gthDir .gt.txt > ${TMP}_gth
	cadFilter $recDir $REXT > ${TMP}_ocr
    elif [ "${DWSP}" -eq 0 -a "${DPMS}" -eq 1 ]; then
	cadFilter_pm $gthDir .gt.txt > ${TMP}_gth
	cadFilter_pm $recDir $REXT > ${TMP}_ocr
    elif [ "${DWSP}" -eq 1 -a "${DPMS}" -eq 1 ]; then
	cadFilter_pm_ws $gthDir .gt.txt > ${TMP}_gth
	cadFilter_pm_ws $recDir $REXT > ${TMP}_ocr
    else
	echo "This setup has not been implemented yet !" 1>&2
	exit 1
    fi
else
    if [ "${DWSP}" -eq 0 -a "${DPMS}" -eq 0 ]; then
	cadFilter $gthDir .gt.txt | normalize > ${TMP}_gth
	cadFilter $recDir $REXT | normalize > ${TMP}_ocr
    elif [ "${DWSP}" -eq 0 -a "${DPMS}" -eq 1 ]; then
	cadFilter_pm $gthDir .gt.txt | normalize > ${TMP}_gth
	cadFilter_pm $recDir $REXT | normalize > ${TMP}_ocr
    elif [ "${DWSP}" -eq 1 -a "${DPMS}" -eq 1 ]; then
	cadFilter_pm_ws $gthDir .gt.txt | normalize > ${TMP}_gth
	cadFilter_pm_ws $recDir $REXT | normalize > ${TMP}_ocr
    else
	echo "This setup has not been implemented yet !" 1>&2
	exit 1
    fi  
fi

if [ $# -eq 3 ]; then
  ocrevalutf8 accuracy ${TMP}_gth ${TMP}_ocr > ${repFile}
else
  ocrevalutf8 accuracy ${TMP}_gth ${TMP}_ocr
fi
exit 0
