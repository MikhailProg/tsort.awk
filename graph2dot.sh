#!/bin/sh

set -eu

test $# = 1 || { echo >&2 "usage: $(basename $0) graph"; exit 1; }

echo 'digraph {'
awk '{ printf("    %s -> %s;\n", $1, $2) }' < "$1"
echo '}'

