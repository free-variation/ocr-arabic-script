-include config

DEVICE ?= cpu

check-par:
ifeq (, $(shell which parallel))
$(error "Please install parallel.")
endif

check-gawk:
ifeq (, $(shell which gawk))
$(error "Please install gawk.")
endif

install-python-libs: 
	pip install -r requirements.txt

install-eval-tools:
	rm -rf ocr-evaluation-tools
	git clone https://github.com/free-variation/ocr-evaluation-tools.git
	cd ocr-evaluation-tools; make PREFIX=.. install
	

deps: install-python-libs install-eval-tools

binarize-all: check-par
	find data/fas -name '*[0-9].png' | parallel kraken -i {} {.}-bin.png -f image -d ${DEVICE} binarize 

segment-all: check-gawk
	kraken -I data/fas/'*-bin.png' -o '-seg.xml' -f image -d ${DEVICE} -a segment --model models/cBAD_27.mlmodel -bl --text-direction horizontal-rl --pad 0 0
	sh scripts/fix_paths.sh data/fas/*-seg.xml

ocr-all:
	kraken -I data/fas/'*-seg.xml' -o '-rec.xml' -a -f alto -d ${DEVICE} ocr -m models/arabPersPrBigMixed_best.mlmodel --reorder --text-direction horizontal-tb

segment-all-par: check-par check-gawk
	find data/fas -name '*-bin.png' | parallel kraken -i {} {.}-seg.xml -f image -a segment --model models/cBAD_27.mlmodel -bl --text-direction horizontal-rl --pad 0 0
	sh scripts/fix_paths.sh data/fas/*-seg.xml

