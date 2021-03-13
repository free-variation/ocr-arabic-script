install-python-libs: 
	pip install -r requirements.txt

install-eval-tools:
	rm -rf ocr-evaluation-tools
	git clone https://github.com/free-variation/ocr-evaluation-tools.git
	cd ocr-evaluation-tools; make PREFIX=.. install
	

deps: install-python-libs install-eval-tools

segment-all:
	find data/fas -name '*.png' | parallel kraken -i {} {.}.json -f image binarize segment -bl --text-direction horizontal-rl --pad 0 0
