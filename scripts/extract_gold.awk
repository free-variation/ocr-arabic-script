#!/usr/local/bin/gawk -f

match($0, /CONTENT="(.*)"/, a) { 
		outfile = FILENAME
		gsub(/\.xml/, "-gold.txt", outfile)
		print a[1] > outfile 
}


