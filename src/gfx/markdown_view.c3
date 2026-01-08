module markpad::gfx;
import std::core::mem;
import raylib55::rl;
import markpad::editor;
import markpad::md;

extern fn int snprintf(char *str, usz size, char *format, ...);

fn void Renderer.draw_markdown_preview(Renderer* self, editor::State* state, int start_x, int start_y, int width)
{
    usz len = state.buffer.len();
    if (len == 0) return;

    char* full_text = (char*)mem::alloc_array(char, len + 1);
    defer mem::free(full_text);

    if (state.buffer.gap_start > 0) {
        mem::copy(full_text, state.buffer.data, state.buffer.gap_start);
    }
    
    usz right_len = state.buffer.capacity - state.buffer.gap_end;
    if (right_len > 0) {
        mem::copy(full_text + state.buffer.gap_start, state.buffer.data + state.buffer.gap_end, right_len);
    }
    full_text[len] = 0;

    void* root = md::cmark_parse_document(full_text, len, 0);
    if (root == null) return;
    defer md::cmark_node_free(root);
    
    int cur_x = start_x;
    int cur_y = start_y - state.scroll_y;
    int limit_x = start_x + width - 20;

    md::MDStyle base_style = {};
    mem::set(&base_style.list_prefix, 0, 32); 
    
    self.draw_markdown_nodes(root, &cur_x, &cur_y, start_x, limit_x, base_style);
}

fn void Renderer.draw_markdown_nodes(Renderer* self, void* node, int* cur_x, int* cur_y, int start_x, int max_width, md::MDStyle style)
{
    void* n = node;
    while (n != null)
    {
        int type = md::cmark_node_get_type(n);
        
        int start_line = md::cmark_node_get_start_line(n);
        if (start_line > 0)
        {
             void* prev = md::cmark_node_previous(n);
             if (prev != null)
             {
                  int prev_end = md::cmark_node_get_end_line(prev);
                  if (prev_end > 0 && start_line > prev_end + 1)
                  {
                       int gaps = start_line - prev_end - 1;
                       if (gaps > 10) gaps = 10; 
                       *cur_y += gaps * self.line_height; 
                  }
             }
        }
        
        md::MDStyle next_style = style;
        bool visit_children = true;
        
        if (type == md::CMARK_NODE_PARAGRAPH || 
            type == md::CMARK_NODE_HEADING || 
            type == md::CMARK_NODE_CODE_BLOCK ||
            type == md::CMARK_NODE_BLOCK_QUOTE ||
            type == md::CMARK_NODE_LIST ||
            type == md::CMARK_NODE_THEMATIC_BREAK)
        {
             if (*cur_x != start_x) {
                 *cur_x = start_x;
                 *cur_y += self.font_size + 4;
             }
        }

        int child_start_x = start_x;

        if (type == md::CMARK_NODE_HEADING)
        {
             next_style.is_header = true;
             next_style.header_level = md::cmark_node_get_heading_level(n);
        }
        else if (type == md::CMARK_NODE_BLOCK_QUOTE)
        {
             next_style.quote_depth++;
             child_start_x += 25;
             int y_start = *cur_y;
             
             void* child = md::cmark_node_first_child(n);
             if (child != null) self.draw_markdown_nodes(child, cur_x, cur_y, child_start_x, max_width, next_style);
             visit_children = false; 
             
             rl::draw_rectangle(start_x + 5, y_start, 4, *cur_y - y_start, rl::LIGHTGRAY);
             *cur_y += 8;
        }
        else if (type == md::CMARK_NODE_LIST)
        {
             void* parent = md::cmark_node_parent(n);
             if (parent != null && md::cmark_node_get_type(parent) == md::CMARK_NODE_ITEM)
             {
                  *cur_y += self.font_size + 4;
             }

             next_style.list_depth++;
             child_start_x += 25; 
             
             void* child = md::cmark_node_first_child(n);
             if (child != null) self.draw_markdown_nodes(child, cur_x, cur_y, child_start_x, max_width, next_style);
             visit_children = false;
        }
        else if (type == md::CMARK_NODE_ITEM)
        {
             void* parent = md::cmark_node_parent(n);
             int ptype = 1; 
             int start_num = 1;
             if (parent != null) {
                 ptype = md::cmark_node_get_list_type(parent);
                 start_num = md::cmark_node_get_list_start(parent);
             }
             
             if (ptype == 1) 
             {
                 rl::draw_circle(start_x - 12, *cur_y + (self.font_size / 2) + 2, 3.0, rl::BLACK);
                 mem::set(&next_style.list_prefix, 0, 32);
             }
             else 
             {
                 int idx = start_num;
                 void* prev = md::cmark_node_previous(n);
                 while(prev != null) { idx++; prev = md::cmark_node_previous(prev); }
                 
                 char[32] num_str;
                 mem::set(&num_str, 0, 32);
                 
                 if (style.list_prefix[0] == 0)
                 {
                     snprintf((char*)&num_str, 32, "%d", idx);
                 }
                 else
                 {
                     snprintf((char*)&num_str, 32, "%s.%d", &style.list_prefix, idx);
                 }
                 
                 mem::copy(&next_style.list_prefix, &num_str, 32); 
                 
                 char[40] display;
                 snprintf((char*)&display, 40, "%s.", &num_str);
                 
                 rl::RLVector2 v = rl::measure_text_ex(self.fonts[0], (ZString)&display, (float)self.font_size, 1.0);
                 int w = (int)v.x;
                 rl::draw_text_ex(self.fonts[0], (ZString)&display, (rl::RLVector2){(float)(start_x - w - 5), (float)*cur_y}, (float)self.font_size, 1.0, rl::BLACK);
             }
        }
        else if (type == md::CMARK_NODE_CODE_BLOCK)
        {
             char* code = md::cmark_node_get_literal(n);
             if (code != null) {
                 int block_y_start = *cur_y;
                 int lines = 1; int c = 0; while(code[c]!=0) { if(code[c]=='\n') lines++; c++; }
                 if (code[0] == 0) lines = 0;
                 
                 int h = lines * (self.font_size + 2) + 10;
                 
                 rl::draw_rectangle(start_x, block_y_start, max_width - start_x, h, (rl::RLColor){245, 245, 245, 255});
                 rl::draw_rectangle_lines(start_x, block_y_start, max_width - start_x, h, rl::LIGHTGRAY);
                 rl::draw_text_ex(self.fonts[2], (ZString)code, (rl::RLVector2){(float)start_x + 5, (float)block_y_start + 5}, (float)self.font_size, 1.0, (rl::RLColor){50,50,50,255});
                 
                 *cur_y += h + 8;
             }
             visit_children = false; 
        }
        else if (type == md::CMARK_NODE_THEMATIC_BREAK) 
        {
             rl::draw_line(start_x, *cur_y + 10, max_width, *cur_y + 10, rl::LIGHTGRAY);
             *cur_y += 20;
             visit_children = false;
        }

        if (type == md::CMARK_NODE_STRONG) next_style.is_bold = true;
        if (type == md::CMARK_NODE_EMPH) next_style.is_italic = true;
        if (type == md::CMARK_NODE_CODE) next_style.is_code = true;
        if (type == md::CMARK_NODE_LINK) next_style.is_link = true;

        if (type == md::CMARK_NODE_TEXT || type == md::CMARK_NODE_CODE)
        {
            char* text = md::cmark_node_get_literal(n);
            if (text != null)
            {
                rl::RLColor color = rl::BLACK;
                if (next_style.is_link)  { color = rl::BLUE; }
                else if (next_style.is_code) { color = (rl::RLColor){60,60,60,255}; }
                if (next_style.is_header) color = rl::DARKBLUE;

                int font_sz = self.font_size;
                if (next_style.is_header) 
                {
                    if (next_style.header_level == 1) { font_sz = 36; }
                    else if (next_style.header_level == 2) { font_sz = 30; }
                    else if (next_style.header_level == 3) { font_sz = 26; }
                    else { font_sz = 22; }
                }

                bool draw_bg = (next_style.is_code && type == md::CMARK_NODE_CODE);
                int text_len = 0; while(text[text_len]!=0) text_len++;
                
                for (int k = 0; k < text_len; k++)
                {
                    char c = text[k];
                    char[2] str_buf; str_buf[0] = c; str_buf[1] = 0;
                    
                    rl::RLFont f = self.font;
                    if (next_style.is_code) {f = self.fonts[2];}
                    else if (next_style.is_italic) {f = self.font_italic;}

                    rl::RLVector2 v = rl::measure_text_ex(f, (ZString)&str_buf, (float)font_sz, 1.0);
                    int char_w = (int)v.x;
                    
                    if (*cur_x + char_w > max_width && max_width > 0 && *cur_x > start_x)
                    {
                         *cur_x = start_x;
                         *cur_y += font_sz + 4;
                    }
                    
                    if (draw_bg)
                    {
                        rl::draw_rectangle(*cur_x, *cur_y, char_w, font_sz + 2, (rl::RLColor){230,230,230,255});
                    }
                    
                    if (next_style.is_bold) {
                        rl::draw_text_ex(f, (ZString)&str_buf, (rl::RLVector2){(float)(*cur_x + 1), (float)*cur_y}, (float)font_sz, 1.0, color);
                    }
                    
                    rl::draw_text_ex(f, (ZString)&str_buf, (rl::RLVector2){(float)*cur_x, (float)*cur_y}, (float)font_sz, 1.0, color);
                    
                    *cur_x += char_w;
                }
            }
        }
        else if (type == md::CMARK_NODE_SOFTBREAK)
        {
             *cur_x = start_x;
             *cur_y += self.font_size + 4;
        }
        else if (type == md::CMARK_NODE_LINEBREAK)
        {
             *cur_x = start_x;
             *cur_y += self.font_size + 4;
        }

        if (visit_children)
        {
            void* child = md::cmark_node_first_child(n);
            if (child != null)
            {
                self.draw_markdown_nodes(child, cur_x, cur_y, child_start_x, max_width, next_style);
            }
        }
        
        if (type == md::CMARK_NODE_PARAGRAPH || 
            type == md::CMARK_NODE_HEADING || 
            type == md::CMARK_NODE_CODE_BLOCK || 
            type == md::CMARK_NODE_LIST)
        {
             if (*cur_x != start_x) {
                 *cur_x = start_x;
                 *cur_y += self.font_size + 8;
             }
        }

        n = md::cmark_node_next(n);
    }
}
