-include config

DEVICE ?= cpu
NUM_THREADS ?= 1
SEG_MODEL ?= models/cBAD_27.mlmodel

ifeq (, $(shell which gawk))
$(error "Please install gawk.")
endif

ifeq (, $(shell which xmllint))
$(error "Please install xmllint, in the package libxml2-utils.")
endif

ifeq (, $(shell which parallel))
$(error "Please install GNU parallel.")
endif

ifeq (, $(shell which mmv))
$(error "Please install the mmv utilities.")
endif

install-python-libs: 
	pip install -r requirements.txt

install-eval-tools:
	rm -rf ocr-evaluation-tools
	git clone https://github.com/free-variation/ocr-evaluation-tools.git
	cd ocr-evaluation-tools; make PREFIX=.. install
	rm -rf ocr-evaluation-tools
	

deps: install-python-libs install-eval-tools


# Run OCR over sample files

binarize-all: 
	kraken -I data/fas/'*[0-9].png' -o '-bin.png' -f image -d ${DEVICE} binarize

binarize-all-par: 
	find data/fas -name '*[0-9].png' | parallel kraken -i {} {.}-bin.png -f image -d ${DEVICE} binarize 

segment-all: 
	kraken -I data/fas/'*-bin.png' -o '-seg.xml' -f image -d ${DEVICE} -a segment --model models/cBAD_27.mlmodel -bl --text-direction horizontal-rl --pad 0 0
	sh scripts/fix_paths.sh data/fas/*-seg.xml
	find data/fas -name '*-seg.xml' | parallel xmllint -o {} --format {}  

segment-all-par: 
	find data/fas -name '*-bin.png' | parallel kraken -i {} {.}-seg.xml -f image -a segment --model ${SEG_MODEL} -bl --text-direction horizontal-rl --pad 0 0
	sh scripts/fix_paths.sh data/fas/*-seg.xml  
	find data/fas -name '*-seg.xml' | parallel xmllint -o {} --format {}  

ocr-all: 
	kraken -I data/fas/'*-seg.xml' -o '-rec.xml' -n -f alto -d ${DEVICE} ocr -m models/arabPersPrBigMixed_best.mlmodel --reorder --text-direction horizontal-tb --threads ${NUM_THREADS}
	find data/fas -name '*-rec.xml' | parallel xmllint -o {} --format {}  

ocr-all-par: 
	find data/fas -name '*-seg.xml' | parallel kraken -i {} {.}-rec.txt -n -f alto -d ${DEVICE} ocr -m models/arabPersPrBigMixed_best.mlmodel --reorder --text-direction horizontal-tb --threads 1

extract-gold-all:
	find data/fas -name '*[0-9].xml' | parallel ./scripts/extract_gold.awk {} 

create-eval-dirs:
	rm -rf d1 d2
	mkdir -p d1 d2
	mcp 'data/fas/*-bin-seg-rec.txt' 'd2/#1.rec.txt'	
	mcp 'data/fas/*-gold.txt' 'd1/#1.gt.txt'

eval-all:
	sh scripts/evalOCR.sh -p -s -n d1 d2 report.txt

eval-google:
	sh scripts/evalOCR.sh -p -s -n d1 google-ocr g-report.txt

go: deps binarize-all-par segment-all-par ocr-all-par extract-gold-all create-eval-dirs eval-all


# Corpus construction
download-openITI:
	rm -rf corpora/openITI
	git clone https://github.com/OpenITI/RELEASE corpora/openITI

build-openITI-corpus: 
	find corpora/openITI -name '*-ara1' | parallel python scripts/clean_openiti.py {} > corpora/openiti.txt

download-pdl:
	rm -rf corpora/pdl
	git clone https://github.com/PersDigUMD/CorpusCSV.git corpora/pdl

build-pdl-corpus:
	cat corpora/pdl/*.csv > corpora/pdl/all.txt
	gawk 'BEGIN {FS="\t"} !/urn:/ {print $$3}' corpora/pdl/all.txt > corpora/pdl.txt
