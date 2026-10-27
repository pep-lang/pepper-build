## Compiling C for the build's target with the toolchain's clang.
##
## Bring it in with `import build.cc`. `compile` builds C files into
## objects in the package's output folder and tells the build to link them.
##
## @example
##     import build.cc;
##
##     main(): int {
##         var objects = cc.compile(["c/add.c"], ["-Ic/include", "-DFAST=1"]);
##         return objects.is_ok() ? 0 : 1;
##     }

import [Path] from io;
import process;
import "../emit" as emit;
import "../env" as env;

## Compiles each C file in `sources` into an object for the build's target
## (`PEP_TARGET`), with the clang the build links with (`PEP_CLANG`), the
## target's system root (`PEP_SYSROOT`) and the build's optimization level
## (`PEP_OPT_LEVEL`). It prints `pep:object=` for each object, so the
## build links them, and `pep:rerun-if-changed=` for each source; a script
## that also reads headers names them with `emit.rerun_if_changed`.
##
## A source's object goes in `PEP_OUT_DIR`, named after the source's path
## (`c/add.c` makes `c_add.o`), so two sources whose paths differ only in
## `/` and `_` (`c/x.c`, `c_x.c`) are an error. A relative source is
## relative to the package's folder.
##
## @param sources the C files to compile
## @param flags more clang flags for every file, such as include folders
##   (`-Ic/include`), defines (`-DNAME=value`) or a `pkg_config.Library`'s
##   `cflags`
## @returns the objects' paths; an error naming the source and holding
##   clang's output when one does not compile, or when the toolchain has no
##   clang
## @panics if a `PEP_*` variable it reads is not set (outside a build script)
export compile(sources: String[], flags: String[]): Result<String[]> {
    var objects = Array<String>();
    for (var index in 0..sources.count) {
        var object = env.out_dir().join(_object_name(sources[index])).to_string();
        var other = objects.find(object);
        if (other.is_value()) {
            return Result<String[]>.err(
                $"cannot compile both '{sources[other.value()]}' and '{sources[index]}': each would make {object}; rename one"
            );
        }
        objects.append(object);
    }
    var clang = env.clang();
    if (clang.is_empty()) {
        return Result<String[]>.err("cannot compile C: the toolchain has no clang (PEP_CLANG is empty)");
    }
    var common = ["--target=" + env.target(), "-O" + to_string(env.opt_level())];
    var sysroot = env.sysroot();
    if (sysroot.is_value()) {
        common.append("--sysroot=" + sysroot.value());
    }
    for (var index in 0..sources.count) {
        var source = sources[index];
        var arguments = common.copy();
        arguments.append_all(flags);
        arguments.append_all(["-c", source, "-o", objects[index]]);
        var ran = process.Command(clang.value()).arguments(arguments).run();
        if (ran.is_err()) {
            return Result<String[]>.err($"cannot run {clang.value()}: {ran.error().message}");
        }
        if (!ran.value().status.success()) {
            return Result<String[]>.err($"clang cannot compile '{source}':
{ran.value().stderr}{ran.value().stdout}");
        }
        emit.object(objects[index]);
        emit.rerun_if_changed(source);
    }
    return Result<String[]>.ok(objects);
}

# The object file name for `source`: its path with `.o` for its file's
# extension, and each separator, and the drive's colon, made `_`.
_object_name(source: String): String {
    return Path(source).with_extension("o").to_string().replace("\\", "_").replace("/", "_").replace(":", "_");
}
