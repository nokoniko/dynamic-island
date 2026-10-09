#!/bin/sh
# Runs the Swift and Rust test suites. With only the Command Line Tools installed,
# Swift Testing lives outside SwiftPM's search paths and plain `swift test` silently
# runs zero tests, so point it there explicitly.
set -e
cd "$(dirname "$0")"

clt=/Library/Developer/CommandLineTools
if [ "$(xcode-select -p)" = "$clt" ]; then
	frameworks="$clt/Library/Developer/Frameworks"
	libraries="$clt/Library/Developer/usr/lib"
	swift test -Xswiftc -F -Xswiftc "$frameworks" \
		-Xlinker -rpath -Xlinker "$frameworks" -Xlinker -rpath -Xlinker "$libraries"
else
	swift test
fi

cd builder && cargo test
