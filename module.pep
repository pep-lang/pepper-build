## Helpers for Pepper build scripts (`build.pep`): compiling C for the
## build's target, finding system libraries with `pkg-config`, and printing
## the build's `pep:` instructions.
##
## Add the package to a project's `[build-dependencies]` under the name
## `build`, then import the modules a script needs:
##
## - `build.cc`: `cc.compile(sources, flags)` compiles C files with the
##   toolchain's clang and links the objects
## - `build.pkg_config`: `pkg_config.find(name)` links a system library and
##   returns its header flags
## - `build.emit`: a function per `pep:` line (`emit.link`, `emit.warning`, ...)
## - `build.env`: the `PEP_*` inputs, typed (`env.target()`, `env.out_dir()`, ...)
##
## @example
##     # build.pep
##     import build.cc;
##
##     main(): int {
##         return cc.compile(["c/add.c"], ["-Ic"]).is_ok() ? 0 : 1;
##     }

# The package's API is its nested modules; this root module holds nothing.
