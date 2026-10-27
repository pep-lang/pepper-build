# The package's modules under the variables a build hands a script, set
# here. tests/run.sh names the fake pkg-config (tests/fake_pkg_config) in
# PKG_CONFIG. Each test runs in a process of its own, so what one sets
# does not reach the next.

import build.cc;
import build.emit;
import build.env;
import os;
import build.pkg_config;

# Sets the variables a native build for x86_64 Linux hands a script.
private native_build() {
    os.set_environment("PEP_TARGET", "x86_64-unknown-linux-gnu");
    os.set_environment("PEP_TARGET_OS", "linux");
    os.set_environment("PEP_TARGET_ARCH", "x86_64");
    os.set_environment("PEP_HOST", "x86_64-unknown-linux-gnu");
    os.set_environment("PEP_OPT_LEVEL", "2");
    os.set_environment("PEP_FEATURES", "tls,fast");
    os.set_environment("PEP_PACKAGE_NAME", "native");
    os.set_environment("PEP_PACKAGE_DIR", "/work/native");
    os.set_environment("PEP_OUT_DIR", "/work/native/out");
    os.set_environment("PEP_CLANG", "");
    os.set_environment("PEP_SYSROOT", "");
    os.remove_environment("PKG_CONFIG_LIBDIR");
    os.remove_environment("PKG_CONFIG_SYSROOT_DIR");
}

# Sets the variables of a build on that machine for aarch64 Linux, with
# the system root `sysroot` (empty for none).
private cross_build(sysroot: String) {
    native_build();
    os.set_environment("PEP_TARGET", "aarch64-unknown-linux-gnu");
    os.set_environment("PEP_TARGET_ARCH", "aarch64");
    os.set_environment("PEP_SYSROOT", sysroot);
}

[Test]
reads_the_inputs() {
    native_build();
    expect_equal(env.target(), "x86_64-unknown-linux-gnu");
    expect_equal(env.target_os(), "linux");
    expect_equal(env.target_arch(), "x86_64");
    expect_equal(env.host(), "x86_64-unknown-linux-gnu");
    expect_equal(env.opt_level(), 2);
    expect_equal(",".join(env.features()), "tls,fast");
    expect_equal(env.package_name(), "native");
    expect_equal(env.package_dir().to_string(), "/work/native");
    expect_equal(env.out_dir().to_string(), "/work/native/out");
    expect_true(env.clang().is_empty());
    expect_true(env.sysroot().is_empty());
    os.set_environment("PEP_FEATURES", "");
    expect_equal(env.features().count, 0 as ulong);
}

[Test]
finds_a_library() {
    native_build();
    var fake = pkg_config.find("fake");
    expect_true(fake.is_ok());
    expect_equal(fake.value().name, "fake");
    expect_equal(" ".join(fake.value().cflags), "-Ifake/include -DFAKE_ANSWER=40");
}

[Test]
says_how_to_install_a_missing_library() {
    native_build();
    var missing = pkg_config.find("libmissing");
    expect_true(missing.is_err());
    var message = missing.error().message;
    expect_true(message.starts_with("pkg-config cannot find 'libmissing': Package 'libmissing' was not found"));
    expect_true(message.contains("install it with"));
    expect_true(message.contains("libmissing.pc"));
    expect_true(message.contains("PKG_CONFIG_PATH"));
}

[Test]
says_how_to_install_a_missing_pkg_config() {
    native_build();
    os.set_environment("PKG_CONFIG", "no-such-pkg-config");
    var missing = pkg_config.find("fake");
    expect_true(missing.is_err());
    expect_true(missing.error().message.starts_with("cannot run no-such-pkg-config: "));
    expect_true(missing.error().message.contains("install it with"));
    expect_false(missing.error().message.contains("PKG_CONFIG_PATH"));
}

[Test]
points_pkg_config_at_the_system_root_when_cross_compiling() {
    cross_build("/sys");
    var fake = pkg_config.find("fake");
    expect_true(fake.is_ok());
    var cflags = fake.value().cflags;
    expect_equal(cflags[0], "-I/sys/fake/include");
    var separator = os.system_os() == os.OperatingSystem.Windows ? ";" : ":";
    expect_equal(
        cflags[2],
        "-DFAKE_LIBDIR="
            + separator.join(
                [
                    "/sys/usr/lib/pkgconfig",
                    "/sys/usr/share/pkgconfig",
                    "/sys/usr/local/lib/pkgconfig",
                    "/sys/usr/lib/aarch64-linux-gnu/pkgconfig",
                ]
            )
    );
}

[Test]
keeps_the_users_pkg_config_libdir_when_cross_compiling() {
    cross_build("");
    os.set_environment("PKG_CONFIG_LIBDIR", "/mine");
    var fake = pkg_config.find("fake");
    expect_true(fake.is_ok());
    expect_equal(" ".join(fake.value().cflags), "-Ifake/include -DFAKE_ANSWER=40 -DFAKE_LIBDIR=/mine");
}

[Test]
refuses_to_cross_compile_without_a_system_root() {
    cross_build("");
    var fake = pkg_config.find("fake");
    expect_true(fake.is_err());
    expect_true(fake.error().message.contains("no --sysroot"));
}

[Test]
needs_a_clang() {
    native_build();
    # A dot in a folder's name is not an extension: `a.b/x` makes `a.b_x.o`, not `a.o`.
    var objects = cc.compile(["c/add.c", "a.b/x", "a.c"], Array<String>());
    expect_true(objects.is_err());
    expect_true(objects.error().message.contains("no clang"));
}

[Test]
refuses_two_sources_with_one_object_name() {
    native_build();
    var objects = cc.compile(["c/x.c", "c_x.c"], Array<String>());
    expect_true(objects.is_err());
    var object = env.out_dir().join("c_x.o");
    expect_equal(
        objects.error().message, $"cannot compile both 'c/x.c' and 'c_x.c': each would make {object}; rename one"
    );
}

[Test]
[ShouldPanic("line break")]
refuses_a_line_break_in_a_pep_line() {
    emit.link("m
pep:link=evil");
}
