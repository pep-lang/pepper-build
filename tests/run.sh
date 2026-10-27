#!/usr/bin/env bash
# Runs the package's tests: the [Test] functions in tests/, with pepper test,
# then builds and runs tests/fixture, a project whose build script uses the
# package. Both use a fake pkg-config (tests/fake_pkg_config): the tests
# name it in PKG_CONFIG, the fixture finds it first on the PATH.
#
# Usage: tests/run.sh [path/to/pepper]   (default: pepper on PATH)
set -euxo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pepper="${1:-pepper}"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

# The package is the module `build`: a folder of that name on the import path.
mkdir "$build/packages" "$build/bin"
ln -s "$root" "$build/packages/build"

exe=""
case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) exe=".exe" ;; esac
"$pepper" build "$root/tests/fake_pkg_config/main.pep" -o "$build/bin/pkg-config$exe"

PKG_CONFIG="$build/bin/pkg-config$exe" "$pepper" test -I "$build/packages" "$root/tests"

# The fixture: its build script finds `fake`, compiles c/answer.c with its
# flags and links it; the program prints 40 + 2 and the build option's word.
cd "$root/tests/fixture"
PATH="$build/bin:$PATH" "$pepper" build --build "$build/fixture-build" -o "$build/fixture$exe" 2>"$build/errors" || {
    cat "$build/errors" >&2
    exit 1
}
cat "$build/errors" >&2
grep -F "warning: fixture: built the fixture's C code" "$build/errors"
grep -F "warning: fixture: pkg-config gives '-Wl,--fake' to link fake" "$build/errors"
[ "$("$build/fixture$exe" | tr -d '\r')" = "42 answered" ]
