module markpad::md;
import std::core::mem;

/*
    Markdown Parser bindings for CommonMark (libcmark)
    Replacing custom scanner.
*/

// --- CMark Bindings ---
// Using void* for opaque C types to avoid C3 definition issues.

extern fn char* cmark_markdown_to_html(char* text, usz len, int options);
extern fn void* cmark_parse_document(char* buffer, usz len, int options);
extern fn void cmark_node_free(void* node);

extern fn int cmark_node_get_type(void* node);
extern fn char* cmark_node_get_literal(void* node);
extern fn int cmark_node_get_heading_level(void* node);
extern fn int cmark_node_get_list_type(void* node);
extern fn int cmark_node_get_list_start(void* node);
extern fn int cmark_node_get_delim_type(void* node);
extern fn char* cmark_node_get_url(void* node);
extern fn char* cmark_node_get_title(void* node);
extern fn char* cmark_node_get_fence_info(void* node);
extern fn int cmark_node_get_start_line(void* node);
extern fn int cmark_node_get_start_column(void* node);
extern fn int cmark_node_get_end_line(void* node);
extern fn int cmark_node_get_end_column(void* node);

extern fn void* cmark_node_next(void* node);
extern fn void* cmark_node_previous(void* node);
extern fn void* cmark_node_parent(void* node);
extern fn void* cmark_node_first_child(void* node);
extern fn void* cmark_node_last_child(void* node);

// Node Types
const int CMARK_NODE_NONE = 0;
const int CMARK_NODE_DOCUMENT = 1;
const int CMARK_NODE_BLOCK_QUOTE = 2;
const int CMARK_NODE_LIST = 3;
const int CMARK_NODE_ITEM = 4;
const int CMARK_NODE_CODE_BLOCK = 5;
const int CMARK_NODE_HTML_BLOCK = 6;
const int CMARK_NODE_CUSTOM_BLOCK = 7;
const int CMARK_NODE_PARAGRAPH = 8;
const int CMARK_NODE_HEADING = 9;
const int CMARK_NODE_THEMATIC_BREAK = 10;
const int CMARK_NODE_TEXT = 11;
const int CMARK_NODE_SOFTBREAK = 12;
const int CMARK_NODE_LINEBREAK = 13;
const int CMARK_NODE_CODE = 14;
const int CMARK_NODE_HTML_INLINE = 15;
const int CMARK_NODE_CUSTOM_INLINE = 16;
const int CMARK_NODE_EMPH = 17;
const int CMARK_NODE_STRONG = 18;
const int CMARK_NODE_LINK = 19;
const int CMARK_NODE_IMAGE = 20;

// --- Legacy Style Helper ---

struct MDStyle
{
    bool is_header;
    int header_level; // 1-6
    bool is_bold;
    bool is_italic;
    bool is_code;
    bool is_quote;
    bool is_list_item;
    bool is_strikethrough;
    bool is_link;
}

// Helper to recursively check for inline styles
fn void check_inline_styles(void* node, MDStyle* style)
{
    while (node != null)
    {
        int type = cmark_node_get_type(node);
        
        if (type == CMARK_NODE_STRONG) style.is_bold = true;
        if (type == CMARK_NODE_EMPH) style.is_italic = true;
        if (type == CMARK_NODE_CODE) style.is_code = true;
        if (type == CMARK_NODE_LINK) style.is_link = true;
        // cmark doesn't support strikethrough by default
        
        // Recurse into children
        void* child = cmark_node_first_child(node);
        if (child != null) 
        {
            check_inline_styles(child, style);
        }

        node = cmark_node_next(node);
    }
}

// Check the style of a line (using cmark to parse the single line)
fn MDStyle check_line_style(char* line_start, usz len)
{
    MDStyle style = {};
    if (len == 0) return style;

    // Parse the line as a document
    // Note: This is inefficient but compatible with the old API.
    // In the future, we should probably parse the whole doc.
    void* root = cmark_parse_document(line_start, len, 0);
    if (root == null) return style;
    defer cmark_node_free(root);

    // Get the first child of the document
    void* child = cmark_node_first_child(root);
    if (child == null) return style;

    int type = cmark_node_get_type(child);

    if (type == CMARK_NODE_HEADING)
    {
        style.is_header = true;
        style.header_level = cmark_node_get_heading_level(child);
    }
    else if (type == CMARK_NODE_BLOCK_QUOTE)
    {
        style.is_quote = true;
    }
    else if (type == CMARK_NODE_LIST)
    {
        style.is_list_item = true;
    }
    else if (type == CMARK_NODE_ITEM)
    {
        style.is_list_item = true;
    }
    else if (type == CMARK_NODE_CODE_BLOCK)
    {
        style.is_code = true;
    }
    else if (type == CMARK_NODE_PARAGRAPH)
    {
        // Traverse inline nodes deeply
        void* inline_node = cmark_node_first_child(child);
        check_inline_styles(inline_node, &style);
    }

    return style;
}
