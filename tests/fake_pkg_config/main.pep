# A stand-in for pkg-config, which tests/run.sh builds: it knows one
# library, `fake`, and answers `--cflags fake` and `--libs fake` as
# pkg-config would, prefixing its include folder with
# PKG_CONFIG_SYSROOT_DIR. Its cflags also carry PKG_CONFIG_LIBDIR, so a
# test sees the environment it ran in.

import [File] from io;
import os;

main(args: String[]): int {
    if (args.count != 3 or args[2] != "fake") {
        File.stderr().print_line($"Package '{args[args.count - 1]}' was not found in the pkg-config search path.");
        return 1;
    }
    if (args[1] == "--cflags") {
        var sysroot = os.environment("PKG_CONFIG_SYSROOT_DIR");
        var include = sysroot.is_value() ? sysroot.value() + "/fake/include" : "fake/include";
        var libdir = os.environment("PKG_CONFIG_LIBDIR");
        print($"-I{include} -DFAKE_ANSWER=40" + (libdir.is_value() ? $" -DFAKE_LIBDIR={libdir.value()}" : ""));
        return 0;
    }
    if (args[1] == "--libs") {
        # A library every system has, so the fixture links, and a flag a
        # build script cannot pass on, which find warns about.
        var system = os.system_os() == os.OperatingSystem.Windows ? "kernel32" : "m";
        print($"-Lfake -l{system} -Wl,--fake");
        return 0;
    }
    File.stderr().print_line($"fake pkg-config: unknown option {args[1]}");
    return 2;
}
