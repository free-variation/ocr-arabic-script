# ocr-arabic-script
Experiments in OCR for historical texts written in Arabic script.

## Prerequisites
 * GNU Make
 * GNU gawk
 * A working Python3 environment
 * pip
 * (Optional) GNU parallel, for running kraken operations in parallel, which may be somewhat faster than kraken batched operations on multicore machines with lower core counts and no GPU.

## Installation
```bash
make deps
```

## Configuration
The system is configured via environment variables set in a local, non-versisoned file `./config`

### PyTorch device
To point to a GPU, set for example
```bash
DEVICE=cuda:0
```
The default device is `cpu`.

### Number of threads for OCR step
This parameter is passed to kraken's `ocr` command.  For a 4-core system,
```bash
NUM_THREADS=4
```
The default is `1'.

## Test Runs

### Binarization
```bash
make binarize-all
```
This will binarie all the images in `data/fas`, yielding image files ending in `-bin.png`

Optionally, use the parallelized version of this target:
```bash
make binarize-all-par
```

### Segmentation
```bash
make segment-all
```
This will segment all the binaried images in `data/fas`, yielding ALTO XML files ending in `-seg.xml`

Optionally, use the parallelized version of this target:
```bash
make segment-all-par
```
Because the parallelized version runs multiple processes, the overhead of the initial load of the neural model is multiplied by the number of cores avialable on the machine (the `parallel` default). Experiment to determine whether parallelization is beneficial on your hardware.  On a Macbook Pro (2019) the speedup is considerable.

## Recognition
```bash
make ocr-all
```
This target will run kraken's OCR over the segmented images, again yielding ALTO XML files, this time containing `<CONTENT>` elements.  The filenames of the output end in `-rec.xml`.


Optionally, use the parallelized version of this target:
```bash
make ocr-all-par
```
Same caveats apply.
