#!/bin/sh
clear
odin build . -linker:lld -o:none -debug && ./uml-gen scenarijus.txt

