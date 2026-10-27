## The instructions a build script prints for the build: one function per
## `pep:` line.
##
## Bring it in with `import build.emit`. Each function prints its line on
## standard output, where the build reads it. A relative path is relative
## to the package's folder, which the script runs in.
##
## @example
##     import build.emit;
##
##     main(): int {
##         emit.link("sqlite3");             # pep:link=sqlite3
##         emit.rerun_if_env_changed("SQLITE_DIR");
##         return 0;
##     }

# Prints `pep:<key>=<value>`. A newline in `value` would start a line the
# script did not mean, so it is refused.
_line(key: String, value: String) {
    if (value.find("\n") >= 0 or value.find("\r") >= 0) {
        panic($"build.emit.{key}: the value holds a line break: '{value}'");
    }
    print($"pep:{key}={value}");
}

## Links an object file or a static library (`.a`, `.lib`):
## `pep:object=<path>`.
##
## @param path the object file or library
## @panics if `path` holds a line break
export object(path: String) {
    _line("object", path);
}

## Links a library by name, as `-l` does: `pep:link=<name>`.
##
## @param name the library's name, without `lib` or a suffix (`sqlite3`)
## @panics if `name` holds a line break
export link(name: String) {
    _line("link", name);
}

## Adds a folder the linker searches, as `-L` does: `pep:link-path=<dir>`.
##
## @param dir the folder
## @panics if `dir` holds a line break
export link_path(dir: String) {
    _line("link-path", dir);
}

## Defines the build option `<package>_<name>`, as `-D` does:
## `pep:build-option=<name>[=<value>]`. The package's code reads it as a
## feature's, with `[BuildOption]`.
##
## @param name the option's name, without the package's prefix
## @param value its value; empty (the default) for a bare `name`, which is `name=1`
## @panics if `name` or `value` holds a line break
export build_option(name: String, value: String = "") {
    _line("build-option", value.is_empty ? name : $"{name}={value}");
}

## Shows `warning: <package>: <text>` to the user: `pep:warning=<text>`.
## Text of several lines shows as a warning per line.
##
## @param text what to show
## @panics if `text` holds a carriage return that does not end a line
export warning(text: String) {
    for (var line in text.lines()) {
        _line("warning", line);
    }
}

## Runs the script again when the file, or any file in the folder,
## changes: `pep:rerun-if-changed=<path>`.
##
## @param path the file or folder
## @panics if `path` holds a line break
export rerun_if_changed(path: String) {
    _line("rerun-if-changed", path);
}

## Runs the script again when the environment variable changes:
## `pep:rerun-if-env-changed=<name>`.
##
## @param name the variable's name
## @panics if `name` holds a line break
export rerun_if_env_changed(name: String) {
    _line("rerun-if-env-changed", name);
}
