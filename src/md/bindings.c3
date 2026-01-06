module markpad::md;

// Minimal bindings for libcmark
// Requires linking against libcmark (e.g. -l cmark)

extern fn char* cmark_markdown_to_html(char* text, int length, int options);
extern fn char* cmark_version_string();
