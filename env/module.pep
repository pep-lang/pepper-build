## What the build hands a build script: the `PEP_*` environment variables,
## read and typed.
##
## Bring it in with `import build.env`. Every accessor panics when its
## variable is not set, which happens only outside a build script.
##
## @example
##     import build.env;
##
##     main(): int {
##         print($"building {env.package_name()} for {env.target()} at -O{env.opt_level()}");
##         return 0;
##     }

import [Path] from io;
import math;
import os;

# The value of the build's variable `name`.
_required(name: String): String {
    var value = os.environment(name);
    if (value.is_empty()) {
        panic($"{name} is not set: build.env reads it only in a build script, which the build runs");
    }
    return value.value();
}

# The value of `name`, or none when it is empty.
_optional(name: String): String? {
    var value = _required(name);
    return value.is_empty ? Optional<String>.Empty : Optional<String>.Value(value);
}

## Returns the triple the program is built for (`PEP_TARGET`), as
## `--target` names it, such as `x86_64-pc-windows-msvc`.
##
## @returns the target triple
## @panics if `PEP_TARGET` is not set
export target(): String {
    return _required("PEP_TARGET");
}

## Returns the target's operating system (`PEP_TARGET_OS`): `linux`,
## `macos`, `windows`, `wasi`, `ios` or `android`.
##
## @returns the target's operating system
## @panics if `PEP_TARGET_OS` is not set
export target_os(): String {
    return _required("PEP_TARGET_OS");
}

## Returns the target's architecture (`PEP_TARGET_ARCH`), such as `x86_64`
## or `aarch64`.
##
## @returns the target's architecture
## @panics if `PEP_TARGET_ARCH` is not set
export target_arch(): String {
    return _required("PEP_TARGET_ARCH");
}

## Returns the triple of the machine the build, and the script, runs on
## (`PEP_HOST`). It differs from `target()` when cross-compiling.
##
## @returns the host triple
## @panics if `PEP_HOST` is not set
export host(): String {
    return _required("PEP_HOST");
}

## Returns the optimization level (`PEP_OPT_LEVEL`), `0` to `3`.
##
## @returns the optimization level
## @panics if `PEP_OPT_LEVEL` is not set or is not a number
export opt_level(): int {
    var text = _required("PEP_OPT_LEVEL");
    var level = math.parse_int(text);
    if (level.is_empty()) {
        panic($"PEP_OPT_LEVEL is '{text}', not a number");
    }
    return level.value() as int;
}

## Returns the package's features the build turns on (`PEP_FEATURES`).
##
## @returns the features' names, empty when none is on
## @panics if `PEP_FEATURES` is not set
export features(): String[] {
    var text = _required("PEP_FEATURES");
    return text.is_empty ? Array<String>() : text.split(",");
}

## Returns the name of the package whose script this is (`PEP_PACKAGE_NAME`).
##
## @returns the package's name
## @panics if `PEP_PACKAGE_NAME` is not set
export package_name(): String {
    return _required("PEP_PACKAGE_NAME");
}

## Returns the package's folder (`PEP_PACKAGE_DIR`), which is also the
## folder the script runs in.
##
## @returns the package's folder, absolute
## @panics if `PEP_PACKAGE_DIR` is not set
export package_dir(): Path {
    return Path(_required("PEP_PACKAGE_DIR"));
}

## Returns the package's own folder for what the script makes
## (`PEP_OUT_DIR`). Its `module.pep` is the package's `generated` module.
##
## @returns the output folder, absolute
## @panics if `PEP_OUT_DIR` is not set
export out_dir(): Path {
    return Path(_required("PEP_OUT_DIR"));
}

## Returns the clang the build links with (`PEP_CLANG`), which compiles C
## for any target LLVM supports.
##
## @returns the path to clang, or none when the toolchain has none
## @panics if `PEP_CLANG` is not set
export clang(): String? {
    return _optional("PEP_CLANG");
}

## Returns the target's system root (`PEP_SYSROOT`, from `--sysroot`).
##
## @returns the system root, or none when the build names none
## @panics if `PEP_SYSROOT` is not set
export sysroot(): String? {
    return _optional("PEP_SYSROOT");
}
