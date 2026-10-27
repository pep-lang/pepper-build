# Calls the C function build.pep compiled, and reads the build option it set.

extern int fixture_answer();

[BuildOption("fixture_ANSWERED")]
answered(): String {
    return "answered";
}

[Target(!BuildOption(fixture_ANSWERED))]
answered(): String {
    return "no build option";
}

main(): int {
    print($"{fixture_answer()} {answered()}");
    return 0;
}
