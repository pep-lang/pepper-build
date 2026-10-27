## Finding a system library with `pkg-config`.
##
## Bring it in with `import build.pkg_config`. `find` asks `pkg-config`
## (the one `PKG_CONFIG` names, else the `pkg-config` on the `PATH`) for a
## library, tells the build to link it, and returns the flags its headers
## need, for `cc.compile`.
##
## When cross-compiling (`PEP_TARGET` is not `PEP_HOST`), `pkg-config` must
## describe the target's libraries, not the host's: unless `PKG_CONFIG_LIBDIR`
## is set, `find` points it at the `.pc` folders of the target's system
## root (`--sysroot`), and sets `PKG_CONFIG_SYSROOT_DIR` to that root, so the
## folders `pkg-config` names are inside it.
##
## @example
##     import build.cc;
##     import build.pkg_config;
##
##     main(): int {
##         var sodium = pkg_config.find("libsodium");
##         if (sodium.is_err()) {
##             print(sodium.error().message);
##             return 1;
##         }
##         return cc.compile(["c/glue.c"], sodium.value().cflags).is_ok() ? 0 : 1;
##     }

import os;
import process;
import "../emit" as emit;
import "../env" as env;

## A library `find` found.
export struct Library {
    ## The name `find` was given (`libsodium`).
    var name: String;
    ## The flags its headers need (`pkg-config --cflags`), such as `-I` and
    ## `-D` flags, to pass to `cc.compile`.
    var cflags: String[];

    ## Creates a Library.
    ##
    ## @param name the library's pkg-config name
    ## @param cflags the flags its headers need
    construct(name: String, cflags: String[]) {
        this.name = name;
        this.cflags = cflags;
    }
}

## Finds the library `name` with `pkg-config` and tells the build to link
## it: for each of `pkg-config --libs`'s flags it prints `pep:link-path=`
## (`-L`), `pep:link=` (`-l`, and `-pthread`) or `pep:object=` (a `.a` or
## `.lib` file), and a `pep:warning=` for a flag it cannot pass on. It also
## prints `pep:rerun-if-env-changed=` for the variables that change what
## `pkg-config` finds.
##
## @param name the library's pkg-config name, the stem of its `.pc` file
##   (`libsodium`, `sqlite3`)
## @returns the library; an error, with how to install the library (or
##   `pkg-config`) on this system, when `pkg-config` cannot be run or does
##   not find the library, or when cross-compiling with no system root and
##   no `PKG_CONFIG_LIBDIR`
## @panics if a `PEP_*` variable it reads is not set (outside a build script)
export find(name: String): Result<Library> {
    for (var variable in ["PKG_CONFIG", "PKG_CONFIG_PATH", "PKG_CONFIG_LIBDIR", "PKG_CONFIG_SYSROOT_DIR"]) {
        emit.rerun_if_env_changed(variable);
    }
    var cflags = _run("--cflags", name)?;
    var libs = _run("--libs", name)?;
    for (var flag in libs) {
        if (flag.starts_with("-L")) {
            emit.link_path(flag.substr_bytes(2, flag.size - 2));
        } else if (flag.starts_with("-l")) {
            emit.link(flag.substr_bytes(2, flag.size - 2));
        } else if (flag == "-pthread") {
            emit.link("pthread");
        } else if (flag.ends_with(".a") or flag.ends_with(".lib")) {
            emit.object(flag);
        } else {
            emit.warning($"pkg-config gives '{flag}' to link {name}, which a build script cannot pass on: ignored");
        }
    }
    return Result<Library>.ok(Library(name, cflags));
}

# The pkg-config to run, with the environment that points it at the
# target's libraries when cross-compiling.
_command(): Result<process.Command> {
    var command = process.Command(os.environment("PKG_CONFIG").value_or("pkg-config"));
    if (env.target() == env.host() or os.environment("PKG_CONFIG_LIBDIR").is_value()) {
        return Result<process.Command>.ok(command);
    }
    var sysroot = env.sysroot();
    if (sysroot.is_empty()) {
        return Result<process.Command>.err(
            $"cannot use pkg-config for {env.target()}: the build has no --sysroot, so pkg-config would describe this machine's libraries; set PKG_CONFIG_LIBDIR to the folders holding the target's .pc files"
        );
    }
    var root = sysroot.value();
    var separator = os.system_os() == os.OperatingSystem.Windows ? ";" : ":";
    var folders = [
        "/usr/lib/pkgconfig",
        "/usr/share/pkgconfig",
        "/usr/local/lib/pkgconfig",
        $"/usr/lib/{env.target_arch()}-linux-gnu/pkgconfig",
    ];
    var paths = Array<String>();
    for (var folder in folders) {
        paths.append(root + folder);
    }
    command.environment("PKG_CONFIG_LIBDIR", separator.join(paths));
    if (os.environment("PKG_CONFIG_SYSROOT_DIR").is_empty()) {
        command.environment("PKG_CONFIG_SYSROOT_DIR", root);
    }
    return Result<process.Command>.ok(command);
}

# Runs pkg-config with `query` (`--cflags`, `--libs`) for `name`, and
# splits what it prints into flags.
# shortcut: splits on spaces, so a path with an escaped space breaks; parse
# pkg-config's quoting when a library needs one.
_run(query: String, name: String): Result<String[]> {
    var command = _command()?;
    var output = command.arguments([query, name]).run();
    if (output.is_err()) {
        return Result<String[]>.err(
            $"cannot run {command.program}: {output.error().message}\n{_install_hint("pkg-config", "pkgconf")}or set PKG_CONFIG to the pkg-config to run"
        );
    }
    if (!output.value().status.success()) {
        return Result<String[]>.err(
            $"pkg-config cannot find '{name}': {output.value().stderr.trim()}\n{_install_hint(_apt_name(name), name)}or add the folder holding {name}.pc (with vcpkg, installed/<triplet>/lib/pkgconfig) to PKG_CONFIG_PATH"
        );
    }
    var flags = Array<String>();
    for (var flag in output.value().stdout.trim().split(" ")) {
        if (!flag.trim().is_empty) {
            flags.append(flag.trim());
        }
    }
    return Result<String[]>.ok(flags);
}

# How to install the package `name` on this machine, a phrase ending in
# ", " for the caller to finish: `apt` is its Debian name.
_install_hint(apt: String, name: String): String {
    var system = os.system_os();
    if (system == os.OperatingSystem.Mac) {
        return $"install it with Homebrew (`brew install {name}`), ";
    }
    if (system == os.OperatingSystem.Windows) {
        return $"install it with vcpkg (`vcpkg install {name}`) or MSYS2 (`pacman -S mingw-w64-ucrt-x86_64-{name}`), ";
    }
    return $"install it with your package manager (on Debian and Ubuntu, `sudo apt install {apt}`; its name may differ), ";
}

# The Debian package of the library `name`'s headers: `lib<name>-dev`.
_apt_name(name: String): String {
    return (name.starts_with("lib") ? name : "lib" + name) + "-dev";
}
