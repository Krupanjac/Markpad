module markpad::md;
import std::core::mem;

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

struct MDStyle
{
    bool is_header;
    int header_level; // 1-6
    bool is_bold;
    bool is_italic;
    bool is_code;
    bool is_quote;
    bool is_list_item; // kept for compatibility, but maybe unused
    bool is_strikethrough;
    bool is_link;
    
    int list_depth;
    int quote_depth;
    char[32] list_prefix;
}

fn void check_inline_styles(void* node, MDStyle* style)
{
    while (node != null)
    {
        int type = cmark_node_get_type(node);
        
        if (type == CMARK_NODE_STRONG) style.is_bold = true;
        if (type == CMARK_NODE_EMPH) style.is_italic = true;
        if (type == CMARK_NODE_CODE) style.is_code = true;
        if (type == CMARK_NODE_LINK) style.is_link = true;
        
        void* child = cmark_node_first_child(node);
        if (child != null) 
        {
            check_inline_styles(child, style);
        }

        node = cmark_node_next(node);
    }
}

fn MDStyle check_line_style(char* line_start, usz len)
{
    MDStyle style = {};
    if (len == 0) return style;

    void* root = cmark_parse_document(line_start, len, 0);
    if (root == null) return style;
    defer cmark_node_free(root);

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
        void* inline_node = cmark_node_first_child(child);
        check_inline_styles(inline_node, &style);
    }

    return style;
}
