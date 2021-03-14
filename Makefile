-include config

DEVICE ?= cpu
NUM_THREADS ?= 1

ifeq (, $(shell which gawk))
$(error "Please install gawk.")
endif

ifeq (, $(shell which xmllint))
$(error "Please install xmllint, in the package libxml2-utils.")
endif

ifeq (, $(shell which parallel))
$(error "Please install GNU parallel.")
endif

install-python-libs: 
	pip install -r requirements.txt

install-eval-tools:
	rm -rf ocr-evaluation-tools
	git clone https://github.com/Shreeshrii/ocr-evaluation-tools.git
	cd ocr-evaluation-tools; make PREFIX=.. install
	rm -rf ocr-evaluation-tools
	

deps: install-python-libs install-eval-tools

binarize-all:
	kraken -I data/fas/'*[0-9].png' -o '-bin.png' -f image -d ${DEVICE} binarize

binarize-all-par: 
	find data/fas -name '*[0-9].png' | parallel kraken -i {} {.}-bin.png -f image -d ${DEVICE} binarize 

segment-all: 
	kraken -I data/fas/'*-bin.png' -o '-seg.xml' -f image -d ${DEVICE} -a segment --model models/cBAD_27.mlmodel -bl --text-direction horizontal-rl --pad 0 0
	sh scripts/fix_paths.sh data/fas/*-seg.xml
	find data/fas -name '*-seg.xml' | parallel xmllint -o {} --format {}  

segment-all-par: 
	find data/fas -name '*-bin.png' | parallel kraken -i {} {.}-seg.xml -f image -a segment --model models/cBAD_27.mlmodel -bl --text-direction horizontal-rl --pad 0 0
	sh scripts/fix_paths.sh data/fas/*-seg.xml  
	find data/fas -name '*-seg.xml' | parallel xmllint -o {} --format {}  

ocr-all:
	kraken -I data/fas/'*-seg.xml' -o '-rec.xml' -a -f alto -d ${DEVICE} ocr -m models/arabPersPrBigMixed_best.mlmodel --reorder --text-direction horizontal-tb --threads ${NUM_THREADS}
	find data/fas -name '*-rec.xml' | parallel xmllint -o {} --format {}  

ocr-all-par: 
	find data/fas -name '*-seg.xml' | parallel kraken -i {} {.}-rec.xml -a -f alto -d ${DEVICE} ocr -m models/arabPersPrBigMixed_best.mlmodel --reorder --text-direction horizontal-tb --threads 1
	find data/fas -name '*-rec.xml' | parallel xmllint -o {} --format {}  

