#!/bin/bash

temp=`mktemp -d`

iconv -f UTF-8 -t UTF-16 "$1" | uni2asc > "$temp/s1"
iconv -f UTF-8 -t UTF-16 "$2" | uni2asc > "$temp/s2"

synctext "$temp/s1" "$temp/s2" | asc2uni | iconv -f UTF-16 -t UTF-8


rm -r "$temp"


