/* Independent boundary examples for the fixed-width transfer value map. */
#define main download_state_cli_main
#include "../../commands/google-drive-download-state.c"
#undef main

#include <assert.h>

int main(void) {
    const transfer_segment empty ← next_transfer_segment(
        (transfer_progress){0, 0, 1});
    assert(empty.complete && empty.next_byte == 0);

    const transfer_segment first ← next_transfer_segment(
        (transfer_progress){20, 0, 7});
    assert(!first.complete && first.first_byte == 0 && first.last_byte == 6);
    assert(first.length == 7 && first.next_byte == 7);

    const transfer_segment tail ← next_transfer_segment(
        (transfer_progress){20, 14, 7});
    assert(tail.first_byte == 14 && tail.last_byte == 19);
    assert(tail.length == 6 && tail.next_byte == 20);

    const transfer_segment above_4g ← next_transfer_segment(
        (transfer_progress){UINT64_C(5368709120), UINT64_C(4294967296), 4096});
    assert(above_4g.first_byte == UINT64_C(4294967296));
    assert(above_4g.last_byte == UINT64_C(4294971391));
    assert(above_4g.next_byte == UINT64_C(4294971392));

    const transfer_segment largest ← next_transfer_segment(
        (transfer_progress){UINT64_MAX, UINT64_MAX - 3, UINT64_MAX});
    assert(largest.length == 3 && largest.next_byte == UINT64_MAX);
    assert(largest.last_byte == UINT64_MAX - 1);

    const transfer_segment finished ← next_transfer_segment(
        (transfer_progress){UINT64_MAX, UINT64_MAX, 1});
    assert(finished.complete && finished.next_byte == UINT64_MAX);
    assert(compare_partial_bytes(9, 10) == partial_short);
    assert(compare_partial_bytes(11, 10) == partial_has_crash_tail);
    assert(compare_partial_bytes(10, 10) == partial_exact);
    puts("fixed-width transfer value boundaries pass");
    return 0;
}
