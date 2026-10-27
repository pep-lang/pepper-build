# Finds the library `fake` through pkg-config, compiles c/answer.c with
# its flags and one of its own, and links it.

import build.cc;
import build.emit;
import [File] from io;
import build.pkg_config;

main(): int {
    var fake = pkg_config.find("fake");
    if (fake.is_err()) {
        File.stderr().print_line(fake.error().message);
        return 1;
    }
    var flags = fake.value().cflags.copy();
    flags.append("-DFIXTURE_BONUS=2");
    var objects = cc.compile(["c/answer.c"], flags);
    if (objects.is_err()) {
        File.stderr().print_line(objects.error().message);
        return 1;
    }
    emit.rerun_if_changed("fake");
    emit.build_option("ANSWERED");
    emit.warning("built the fixture's C code");
    return 0;
}
