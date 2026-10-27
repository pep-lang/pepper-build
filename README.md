# pepper-build

Helpers for [Pepper](https://github.com/pep-lang/pepper) build scripts
(`build.pep`, Pepper's `build.rs`): compile a package's C code for the
build's target with the toolchain's clang, find a system library with
`pkg-config`, and print the `pep:` lines that tell the build what to link.
Build scripts need Pepper 0.11.0 or later.

Four modules, each imported by itself:

- **`build.cc`**: `cc.compile(sources, flags)` compiles C files for
  `PEP_TARGET` with `PEP_CLANG`, `PEP_SYSROOT` and `-O<PEP_OPT_LEVEL>`,
  plus your flags (`-I` include folders, `-D` defines), into
  `PEP_OUT_DIR`. It prints `pep:object=` and `pep:rerun-if-changed=` for
  each file, and returns the objects' paths.
- **`build.pkg_config`**: `pkg_config.find(name)` runs `pkg-config` (the
  one `PKG_CONFIG` names, else the `PATH`'s), prints `pep:link=` and
  `pep:link-path=` for its `--libs`, and returns a `Library` whose
  `cflags` go to `cc.compile`. When the library or `pkg-config` is
  missing, the error says how to install it here (apt, Homebrew, vcpkg or
  MSYS2). When cross-compiling it points `pkg-config` at the `--sysroot`
  (`PKG_CONFIG_LIBDIR`, `PKG_CONFIG_SYSROOT_DIR`), unless
  `PKG_CONFIG_LIBDIR` is already set.
- **`build.emit`**: one function per `pep:` line: `object`, `link`,
  `link_path`, `build_option`, `warning`, `rerun_if_changed`,
  `rerun_if_env_changed`.
- **`build.env`**: the `PEP_*` inputs, typed: `target()`, `target_os()`,
  `target_arch()`, `host()`, `opt_level()`, `features()`,
  `package_name()`, `package_dir()`, `out_dir()`, `clang()`, `sysroot()`.

```pepper
# build.pep: links libsodium and compiles the package's C glue against it.
import [File] from io;
import build.cc;
import build.emit;
import build.pkg_config;

main(): int {
    var sodium = pkg_config.find("libsodium");
    if (sodium.is_err()) {
        File.stderr().print_line(sodium.error().message);
        return 1;
    }
    var flags = sodium.value().cflags.copy();
    flags.append("-Ic/include");
    var objects = cc.compile(["c/glue.c"], flags);
    if (objects.is_err()) {
        File.stderr().print_line(objects.error().message);
        return 1;
    }
    emit.rerun_if_changed("c/include");
    return 0;
}
```

What a build script receives and prints is described in Pepper's book:
[Build scripts](https://docs.pepper-lang.dev/dev/tools/projects.html#build-scripts).

## Limits

- `pkg_config.find` splits `pkg-config`'s output on spaces, so a path
  holding an escaped space breaks, and it passes on only `-L`, `-l`,
  `-pthread` and `.a`/`.lib` files from `--libs`; other flags become a
  warning. It takes no version requirement.
- `cc.compile` compiles C only, one file at a time, and does not track the
  headers a file includes: name them with `emit.rerun_if_changed`.

## Using it

Add it to the `[build-dependencies]` of the package whose `build.pep`
uses it, under the name `build`:

```sh
pepper package add --build pep-lang/pepper-build --name build
```

which writes

```toml
[build-dependencies]
build = { github = "pep-lang/pepper-build" }
```

## Tests

```sh
tests/run.sh path/to/pepper
```

runs the `[Test]` functions in `tests/` with `pepper test`, then builds and
runs `tests/fixture`, a project whose build script uses this package as a
`path` build-dependency to find a library and compile and link a C file.
Both use a fake `pkg-config`, `tests/fake_pkg_config`, which the script
builds: the tests name it in `PKG_CONFIG`, and the fixture finds it first
on the `PATH`.

## Releasing

CI (`.github/workflows/ci.yml`) runs the tests on Linux, macOS and
Windows for every push to `main` and every pull request. Until Pepper
0.11.0 is published it installs 0.11.0-dev (the workflow's
`PEPPER_VERSION`), the first toolchain with build scripts, and skips the
job that tests `minimum_toolchain`; once 0.11.0 is out, delete
`PEPPER_VERSION` and both use releases. To release, set `version` in
`pep.toml`, merge, then push the matching tag
(`git tag v1.0.0 && git push origin v1.0.0`): CI tests the tag and
publishes a GitHub release for it.

## License

Apache-2.0; see [LICENSE](LICENSE).
