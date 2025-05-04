#!/bin/sh
clear
odin build . -linker:lld -o:none -debug && ./uml-gen scenarijus.txt
#
# btw, if you get clang: error: invalid linker name in argument '-fuse-ld=lld', 
#   either remove -linker:lld or install lld

