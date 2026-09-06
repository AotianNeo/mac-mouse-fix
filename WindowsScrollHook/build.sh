#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Building libMacMouseFixWindowsScroll.dylib..."
clang -dynamiclib -arch arm64 -arch x86_64 \
  -framework Foundation -framework AppKit \
  -L"/Applications/Mac Mouse Fix.app/Contents/Library/LoginItems/Mac Mouse Fix Helper.app/Contents/Frameworks" \
  -lswift_Concurrency \
  -install_name "@rpath/libMacMouseFixWindowsScroll.dylib" \
  -o "$DIR/libMacMouseFixWindowsScroll.dylib" \
  "$DIR/WindowsScrollHook.m"

echo "Build successful: $DIR/libMacMouseFixWindowsScroll.dylib"
