#!/bin/bash

gawk -i inplace 'match($0, /fileName>(.*)</, a) {"basename " a[1] | getline basename; gsub(a[1], basename)} {print}' "$@"
