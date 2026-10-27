/* FAKE_ANSWER and fake.h come from the fake pkg-config's cflags,
   FIXTURE_BONUS from build.pep's own flag. */
#include "fake.h"

int fixture_answer(void) {
    return FAKE_HEADER_ANSWER + FIXTURE_BONUS;
}
