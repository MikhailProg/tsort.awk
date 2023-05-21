#!/bin/sh

set -eu

test $# = 2 || { echo >&2 "usage: $(basename $0) vertices image"; exit 1; }

{
    echo 'digraph {'
    sed 's/^[^ ]*/    & ->/' < "$1"
    echo '}'
} | dot -T svg -o "$2"



