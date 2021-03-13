install-python-libs: 
	pip install -r requirements.txt

install-eval-tools:
	rm -rf ocr-evaluation-tools
	git clone https://github.com/free-variation/ocr-evaluation-tools.git
	cd ocr-evaluation-tools; make PREFIX=.. install
	

deps: install-python-libs install-eval-tools

binarize-all:
	find data/fas -name '*.png' | parallel kraken -i {} {.}-bin.png -f image binarize 

segment-all:
	find data/fas -name '*-bin.png' | parallel kraken -i {} {.}.json -f image segment -bl --text-direction horizontal-rl --pad 0 0

segment-all-nopar:
	kraken -I data/fas/'*-bin.png' -o '.json' -f image segment -bl --text-direction horizontal-rl --pad 0 0
