#!/bin/bash
set -e

if [ ! -d "deps/cmark/src" ]; then
    echo "Error: Must be run from project root"
    exit 1
fi

mkdir -p build/lib

echo "Compiling cmark static library..."

# Compile C files
cc -c -O2 -fPIC -std=c99 -I. -Ideps/cmark/src \
    deps/cmark/src/blocks.c \
    deps/cmark/src/buffer.c \
    deps/cmark/src/cmark.c \
    deps/cmark/src/cmark_ctype.c \
    deps/cmark/src/commonmark.c \
    deps/cmark/src/houdini_href_e.c \
    deps/cmark/src/houdini_html_e.c \
    deps/cmark/src/houdini_html_u.c \
    deps/cmark/src/html.c \
    deps/cmark/src/inlines.c \
    deps/cmark/src/iterator.c \
    deps/cmark/src/latex.c \
    deps/cmark/src/man.c \
    deps/cmark/src/node.c \
    deps/cmark/src/references.c \
    deps/cmark/src/render.c \
    deps/cmark/src/scanners.c \
    deps/cmark/src/utf8.c \
    deps/cmark/src/xml.c

# archive
ar rcs build/lib/libcmark.a *.o

# cleanup
rm *.o

echo "Successfully built build/lib/libcmark.a"
