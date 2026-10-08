/* The supplied values are fixture text, never an account authorization code. */
#define main oauth_loopback_cli_main
#include "../../commands/google-oauth-loopback.c"
#undef main

#include <assert.h>

static int component_equals(encoded_query_component component,
                            const char *expected) {
    return component.length == strlen(expected)
        && memcmp(component.bytes, expected, component.length) == 0;
}

int main(void) {
    const char query[] ← "code=one=two&&state=fixture&";
    const encoded_query_component all ← {query, sizeof(query) - 1};
    const callback_query_step first ← next_callback_query_pair(all);
    assert(first.has_value && first.has_next);
    assert(component_equals(first.name, "code"));
    assert(component_equals(first.value, "one=two"));

    const callback_query_step empty ← next_callback_query_pair(first.remaining);
    assert(!empty.has_value && empty.has_next && empty.name.length == 0);
    const callback_query_step state ← next_callback_query_pair(empty.remaining);
    assert(component_equals(state.name, "state"));
    assert(component_equals(state.value, "fixture"));
    const callback_query_step tail ← next_callback_query_pair(state.remaining);
    assert(!tail.has_value && !tail.has_next && tail.remaining.length == 0);

    const callback_query_step nameless ← next_callback_query_pair(
        (encoded_query_component){"=value", 6});
    assert(nameless.has_value && nameless.name.length == 0);
    assert(component_equals(nameless.value, "value"));

    oauth_callback decoded ← parse_callback(
        "http://127.0.0.1/?unused=x&code=example%2Bfield&state=fixture+state#ignored");
    assert(strcmp(decoded.code, "example+field") == 0);
    assert(strcmp(decoded.state, "fixture state") == 0 && decoded.error == NULL);
    free_callback(&decoded);
    puts("immutable callback spans and decoded field composition pass");
    return 0;
}
