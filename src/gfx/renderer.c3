module markpad::gfx;
import std::core::mem;
import std::io;
import raylib55::rl;
import markpad::editor;
import markpad::md;

extern fn int snprintf(char *str, usz size, char *format, ...);

struct Renderer
{
	rl::RLFont[5] fonts;
    char*[5] font_names;
    int current_font_idx;
    
	rl::RLFont font;
    rl::RLFont font_italic;
	
	int font_size;
	int char_width;
	int line_height;
}

fn void Renderer.init(Renderer* self)
{
	self.fonts[0] = rl::get_font_default();
    self.font_names[0] = "Default";
    
	self.fonts[1] = rl::load_font_ex("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 32, (int*)0, 0);
    if (self.fonts[1].texture.id == 0) self.fonts[1] = rl::get_font_default();
    self.font_names[1] = "DejaVu";
    
    self.fonts[2] = rl::load_font_ex("resources/Fira/FiraCode-Bold.ttf", 32, (int*)0, 0);
    self.font_names[2] = "Fira Code";
    
    self.fonts[3] = rl::load_font_ex("resources/JetBrainsMono/JetBrainsMono-Regular.ttf", 32, (int*)0, 0);
    self.font_names[3] = "JetBrains Mono";
    
    self.fonts[4] = rl::load_font_ex("resources/Cascadia/CascadiaCode.ttf", 32, (int*)0, 0);
    self.font_names[4] = "Cascadia Code";

    self.current_font_idx = 0;
	self.font = self.fonts[0];
    
    // Load Italic Fallback
    self.font_italic = rl::load_font_ex("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Oblique.ttf", 32, (int*)0, 0);
    if (self.font_italic.texture.id == 0) self.font_italic = self.fonts[0];

	self.font_size = 20;
	self.line_height = 24;
    self.recalc_metrics();
}

fn void Renderer.free(Renderer* self)
{
    // Index 0 is default font, we don't own it.
    // Indexes 1-4 are loaded fonts, unless they failed load and are copies of default.
    for (int i = 1; i < 5; i++)
    {
        if (self.fonts[i].texture.id != self.fonts[0].texture.id)
        {
            rl::unload_font(self.fonts[i]);
        }
    }
    
    if (self.font_italic.texture.id != self.fonts[0].texture.id)
    {
        rl::unload_font(self.font_italic);
    }
}

fn void Renderer.recalc_metrics(Renderer* self)
{
    rl::RLVector2 v = rl::measure_text_ex(self.font, "M", (float)self.font_size, 1.0);
    self.char_width = (int)v.x;
}

fn void Renderer.set_font(Renderer* self, int index)
{
    if (index >= 0 && index < 5)
    {
        self.current_font_idx = index;
        if (self.fonts[self.current_font_idx].texture.id != 0)
        {
            self.font = self.fonts[self.current_font_idx];
        }
        else {
             self.font = self.fonts[0];
        }
        self.recalc_metrics();
    }
}

fn void Renderer.toggle_font(Renderer* self)
{
    self.current_font_idx = (self.current_font_idx + 1) % 5;
    
    while (self.fonts[self.current_font_idx].texture.id == 0 && self.current_font_idx != 0)
    {
         self.current_font_idx = (self.current_font_idx + 1) % 5;
    }
    
    self.font = self.fonts[self.current_font_idx];
    self.recalc_metrics();
}



fn void Renderer.draw_simple_text(Renderer* self, char* text, int x, int y, int size, rl::RLColor color)
{
	rl::draw_text((ZString)text, x, y, size, color);
}

// Calculate the buffer index for a given screen position (hit testing)
fn usz Renderer.get_index_at_pos(Renderer* self, editor::State* state, int target_x, int target_y, int start_x, int start_y)
{
	int effective_start_y = start_y - state.scroll_y;
	if (target_y < effective_start_y) return 0;

	int cur_x = start_x;
	int cur_y = effective_start_y;
	usz len = state.buffer.len();
	int max_width = rl::get_screen_width() - start_x - 10;
	if (state.show_markdown_preview) max_width = (rl::get_screen_width() / 2) - start_x - 10;

	for (usz i = 0; i < len; i++)
	{
		if (target_y >= cur_y && target_y < cur_y + self.line_height)
		{
			if (target_x < cur_x + self.char_width) {
				return i;
			}
		}

		char c = state.buffer.get_char_at(i);
		
		if (c == '\n')
		{
			if (target_y >= cur_y && target_y < cur_y + self.line_height) {
				return i;
			}
			cur_x = start_x;
			cur_y += self.line_height;
			continue;
		}
		
		if (state.word_wrap && cur_x > start_x + max_width)
		{
			if (target_y >= cur_y && target_y < cur_y + self.line_height) {
				return i;
			}
			cur_x = start_x;
			cur_y += self.line_height;
		}
		
		if (c == '\t')
		{
			cur_x += self.char_width * 4;
			continue;
		}
		
		cur_x += self.char_width;
	}
	
	return len;
}

fn void Renderer.draw_menu_bar(Renderer* self)
{
	rl::draw_rectangle(0, 0, rl::get_screen_width(), 30, rl::LIGHTGRAY);
	
	// Draw Items
	rl::draw_text("File", 10, 5, 20, rl::BLACK);
	rl::draw_text("Edit", 60, 5, 20, rl::BLACK);
	rl::draw_text("View", 110, 5, 20, rl::BLACK);
	rl::draw_text("Help", 160, 5, 20, rl::BLACK);
	
	rl::draw_line(0, 30, rl::get_screen_width(), 30, rl::GRAY);
}

fn void Renderer.draw_buffer(Renderer* self, editor::State* state, int start_x, int start_y, int view_width)
{
	editor::GapBuffer* buffer = &state.buffer;
	int cur_x = start_x;
	int cur_y = start_y - state.scroll_y;
	usz len = buffer.len();
	int max_width = view_width - 10;
	
	usz sel_start = state.selection_anchor < buffer.gap_start ? state.selection_anchor : buffer.gap_start;
	usz sel_end = state.selection_anchor > buffer.gap_start ? state.selection_anchor : buffer.gap_start;
	bool selected = sel_start != sel_end;

	for (usz i = 0; i < len; i++)
	{
		bool visible = (cur_y + self.line_height > 30) && (cur_y < rl::get_screen_height());

		if (selected && i >= sel_start && i < sel_end && visible)
		{
			rl::draw_rectangle(cur_x, cur_y, self.char_width, self.line_height, rl::SKYBLUE);
		}

		if (i == buffer.gap_start && visible)
		{
			rl::draw_rectangle(cur_x, cur_y, 2, self.line_height, rl::RED);
		}

		char c = buffer.get_char_at(i);

		if (c == '\n')
		{
			cur_x = start_x;
			cur_y += self.line_height; 
			continue;
		}
		
		if (state.word_wrap && cur_x > start_x + max_width)
		{
			cur_x = start_x;
			cur_y += self.line_height;
		}
		
		if (c == '\t')
		{
			cur_x += self.char_width * 4;
			continue;
		}

		if (visible)
		{
			char[2] str;
			str[0] = c;
			str[1] = 0;
            
            rl::RLVector2 v = rl::measure_text_ex(self.font, (ZString)&str, (float)self.font_size, 1.0);
            int char_w = (int)v.x;
            int offset_x = (self.char_width - char_w) / 2;
            
			rl::draw_text_ex(self.font, (ZString)&str, (rl::RLVector2){ (float)(cur_x + offset_x), (float)cur_y }, (float)self.font_size, 1.0, rl::BLACK);
		}
		
		cur_x += self.char_width;
	}
	
	if (buffer.gap_start == len)
	{
		rl::draw_rectangle(cur_x, cur_y, 2, self.line_height, rl::RED);
	}

    int screen_h = rl::get_screen_height();
    int content_h = 0; 
    
    int line_count = 1;
    for (usz k = 0; k < len; k++) { if (buffer.get_char_at(k) == '\n') line_count++; }
    content_h = line_count * self.line_height;
    if (content_h < screen_h) content_h = screen_h;

    float view_ratio = (float)screen_h / (float)content_h;
    if (view_ratio < 1.0)
    {
        int scroll_h = (int)(screen_h * view_ratio);
        if (scroll_h < 30) scroll_h = 30;
        int scroll_y = (int)((float)state.scroll_y / (float)(content_h - screen_h) * (float)(screen_h - scroll_h));
        
        int scroll_x = start_x + view_width - 15;

        rl::draw_rectangle(scroll_x, 0, 15, screen_h, (rl::RLColor){240, 240, 240, 255});
        rl::draw_rectangle(scroll_x + 2, scroll_y, 11, scroll_h, rl::DARKGRAY);
    }
}

fn void Renderer.draw_modal(Renderer* self, char* title, char* input_text)
{
	int sw = rl::get_screen_width();
	int sh = rl::get_screen_height();
	
	rl::draw_rectangle(0, 0, sw, sh, (rl::RLColor){ 0, 0, 0, 100 });
	
	int w = 400;
	int h = 120;
	int x = (sw / 2) - (w / 2);
	int y = (sh / 2) - (h / 2);
	
	rl::draw_rectangle(x, y, w, h, rl::RAYWHITE);
	rl::draw_rectangle_lines(x, y, w, h, rl::GRAY);
	
	rl::draw_text((ZString)title, x + 10, y + 10, 20, rl::BLACK);
	
	rl::draw_rectangle(x + 10, y + 40, w - 20, 30, rl::WHITE);
	rl::draw_rectangle_lines(x + 10, y + 40, w - 20, 30, rl::LIGHTGRAY);
	
	rl::draw_text((ZString)input_text, x + 15, y + 45, 20, rl::BLACK);
	
	rl::draw_text("Enter to Confirm, Esc to Cancel", x + 10, y + 90, 10, rl::GRAY);
}
fn void Renderer.draw_font_selector(Renderer* self)
{
	int sw = rl::get_screen_width();
	int sh = rl::get_screen_height();
    
	rl::draw_rectangle(0, 0, sw, sh, (rl::RLColor){ 0, 0, 0, 100 });
	
	int w = 400;
	int h = 300;
	int x = (sw / 2) - (w / 2);
	int y = (sh / 2) - (h / 2);
	
	rl::draw_rectangle(x, y, w, h, rl::RAYWHITE);
	rl::draw_rectangle_lines(x, y, w, h, rl::GRAY);
	
	rl::draw_text("Select Font", x + 10, y + 10, 20, rl::BLACK);
    
    int list_y = y + 40;
    int item_h = 40;
    
    for (int i = 0; i < 5; i++)
    {
        int item_y = list_y + (i * item_h);
        
        if (i == self.current_font_idx)
        {
            rl::draw_rectangle(x + 10, item_y, w - 20, item_h, rl::SKYBLUE);
        }
        
        // Check availability (dim unavailable custom fonts if necessary, though we fallback to default currently)
        rl::RLColor col = rl::BLACK;
        if (i > 1 && self.fonts[i].texture.id == 0) col = rl::GRAY;
        
        rl::draw_text((ZString)self.font_names[i], x + 20, item_y + 10, 20, col);
    }
    
    rl::draw_text("Esc to Cancel", x + 10, y + h - 20, 10, rl::GRAY);
}
fn void Renderer.draw_file_browser(Renderer* self, editor::FileBrowser* browser, char* title, char* input_text)
{
	int sw = rl::get_screen_width();
	int sh = rl::get_screen_height();
	
	rl::draw_rectangle(0, 0, sw, sh, (rl::RLColor){ 0, 0, 0, 100 });
	
	int w = 600;
	int h = 500;
	int x = (sw / 2) - (w / 2);
	int y = (sh / 2) - (h / 2);
	
	rl::draw_rectangle(x, y, w, h, rl::RAYWHITE);
	rl::draw_rectangle_lines(x, y, w, h, rl::GRAY);
	
	rl::draw_text((ZString)title, x + 10, y + 10, 20, rl::BLACK);
	rl::draw_text((ZString)&browser.current_directory, x + 10, y + 30, 10, rl::DARKGRAY);
	
	int list_y = y + 50;
	int list_h = h - 100;
	rl::draw_rectangle(x + 10, list_y, w - 20, list_h, rl::WHITE);
	rl::draw_rectangle_lines(x + 10, list_y, w - 20, list_h, rl::LIGHTGRAY);
	
	int item_h = 24;
	int view_max = list_h / item_h;
	int start_idx = browser.scroll_offset;
	int count = browser.files.count;
	
	rl::draw_text(".. (Parent Directory)", x + 20, list_y + 5, 20, rl::BLUE);
	
	for (int i = 0; i < view_max; i++)
	{
		int idx = start_idx + i;
		if (idx >= count) break;
		
		int render_y = list_y + ((i + 1) * item_h) + 5;
		
		char* filename = browser.files.paths[idx];
		bool is_sel = (idx == browser.selected_index);
		
		if (is_sel) {
			rl::draw_rectangle(x + 12, render_y, w - 24, item_h, rl::SKYBLUE);
		}
		
		rl::RLColor col = rl::BLACK;
		
		rl::draw_text((ZString)filename, x + 20, render_y + 2, 20, col);
	}
	
	int input_y = y + h - 40;
	rl::draw_rectangle(x + 10, input_y, w - 160, 30, rl::WHITE);
	rl::draw_rectangle_lines(x + 10, input_y, w - 160, 30, rl::LIGHTGRAY);
	rl::draw_text((ZString)input_text, x + 15, input_y + 5, 20, rl::BLACK);
	
	rl::draw_rectangle(x + w - 140, input_y, 60, 30, rl::LIGHTGRAY);
	rl::draw_text("OK", x + w - 120, input_y + 5, 20, rl::BLACK);
	
	rl::draw_rectangle(x + w - 70, input_y, 60, 30, rl::LIGHTGRAY);
	rl::draw_text("X", x + w - 50, input_y + 5, 20, rl::BLACK);
}

fn void Renderer.draw_menu_dropdown(Renderer* self, int menu_id, editor::State* state)
{
	int start_x = 0;
	int start_y = 30;
	int width = 200;
	int item_height = 30;
	
	if (menu_id == 1) // File
	{
		start_x = 10;
		int height = item_height * 4;
		rl::draw_rectangle(start_x, start_y, width, height, rl::RAYWHITE);
		rl::draw_rectangle_lines(start_x, start_y, width, height, rl::GRAY);
		
		rl::draw_text("New", start_x + 10, start_y + 5, 20, rl::BLACK);
		rl::draw_text("Open...", start_x + 10, start_y + 35, 20, rl::BLACK);
		rl::draw_text("Save       Ctrl+S", start_x + 10, start_y + 65, 20, rl::BLACK);
		rl::draw_text("Exit", start_x + 10, start_y + 95, 20, rl::BLACK);
	}
	else if (menu_id == 2) // Edit
	{
		start_x = 60;
		int height = item_height * 4;
		rl::draw_rectangle(start_x, start_y, width, height, rl::RAYWHITE);
		rl::draw_rectangle_lines(start_x, start_y, width, height, rl::GRAY);
		
		rl::draw_text("Cut        Ctrl+X", start_x + 10, start_y + 5, 20, rl::BLACK);
		rl::draw_text("Copy       Ctrl+C", start_x + 10, start_y + 35, 20, rl::BLACK);
		rl::draw_text("Paste      Ctrl+V", start_x + 10, start_y + 65, 20, rl::BLACK);
		rl::draw_text("Select All Ctrl+A", start_x + 10, start_y + 95, 20, rl::BLACK);
	}
	else if (menu_id == 3) // View
	{
		start_x = 110;
		int height = item_height * 3;
		rl::draw_rectangle(start_x, start_y, width, height, rl::RAYWHITE);
		rl::draw_rectangle_lines(start_x, start_y, width, height, rl::GRAY);
		
		rl::draw_text("Word Wrap", start_x + 30, start_y + 5, 20, rl::BLACK);
		if (state.word_wrap) rl::draw_text("x", start_x + 10, start_y + 5, 20, rl::DARKGREEN);

		rl::draw_text("Show Preview", start_x + 30, start_y + 35, 20, rl::BLACK);
		if (state.show_markdown_preview) rl::draw_text("x", start_x + 10, start_y + 35, 20, rl::DARKGREEN);
		
		rl::draw_text("Font", start_x + 30, start_y + 65, 20, rl::BLACK);
	}
	else if (menu_id == 4) // Help
	{
		start_x = 160;
		int height = item_height * 1;
		rl::draw_rectangle(start_x, start_y, width, height, rl::RAYWHITE);
		rl::draw_rectangle_lines(start_x, start_y, width, height, rl::GRAY);
		
		rl::draw_text("About", start_x + 10, start_y + 5, 20, rl::BLACK);
	}
}

fn void Renderer.draw_markdown_preview(Renderer* self, editor::State* state, int start_x, int start_y, int width)
{
    usz len = state.buffer.len();
    if (len == 0) return;

    // Linearize buffer to full string
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

    // Parse full document
    void* root = md::cmark_parse_document(full_text, len, 0);
    if (root == null) return;
    defer md::cmark_node_free(root);
    
    int cur_x = start_x;
    int cur_y = start_y - state.scroll_y;
    int limit_x = start_x + width - 20;

    md::MDStyle base_style = {};
    self.draw_markdown_nodes(root, &cur_x, &cur_y, start_x, limit_x, base_style);
}

fn void Renderer.draw_markdown_nodes(Renderer* self, void* node, int* cur_x, int* cur_y, int start_x, int max_width, md::MDStyle style)
{
    void* n = node;
    while (n != null)
    {
        int type = md::cmark_node_get_type(n);
        
        // --- Vertical whitespace preservation ---
        // Adds extra spacing if the user inserted multiple newlines in the source
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
                       // Cap gaps to avoid massive scrolling if someone holds Enter
                       if (gaps > 10) gaps = 10; 
                       *cur_y += gaps * self.line_height; 
                  }
             }
        }
        
        md::MDStyle next_style = style;
        bool visit_children = true;
        
        // --- Block Layout Adjustments ---
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

        // --- Block Styling ---
        int child_start_x = start_x;

        if (type == md::CMARK_NODE_HEADING)
        {
             next_style.is_header = true;
             next_style.header_level = md::cmark_node_get_heading_level(n);
        }
        else if (type == md::CMARK_NODE_BLOCK_QUOTE)
        {
             next_style.quote_depth++;
             child_start_x += 25; // Indent quote content
             int y_start = *cur_y;
             
             void* child = md::cmark_node_first_child(n);
             if (child != null) self.draw_markdown_nodes(child, cur_x, cur_y, child_start_x, max_width, next_style);
             visit_children = false; 
             
             // Draw vertical bar for the height of the content
             rl::draw_rectangle(start_x + 5, y_start, 4, *cur_y - y_start, rl::LIGHTGRAY);
             *cur_y += 8; // Padding after block
        }
        else if (type == md::CMARK_NODE_LIST)
        {
             // Fix for "Nested lists text overlap": 
             // If we are a list inside an item, and we are the first child (or effectively following the bullet immediately),
             // we MUST start on a new line to avoid overlapping the parent bullet or text.
             void* parent = md::cmark_node_parent(n);
             if (parent != null && md::cmark_node_get_type(parent) == md::CMARK_NODE_ITEM)
             {
                  // Always push nested lists to next line
                  *cur_y += self.font_size + 4;
             }

             next_style.list_depth++;
             child_start_x += 20; // Indent list items
             
             void* child = md::cmark_node_first_child(n);
             if (child != null) self.draw_markdown_nodes(child, cur_x, cur_y, child_start_x, max_width, next_style);
             visit_children = false;
        }
        else if (type == md::CMARK_NODE_ITEM)
        {
             // Draw bullet/number
             void* parent = md::cmark_node_parent(n);
             int ptype = 1; // 1=Bullet
             int start_num = 1;
             if (parent != null) {
                 ptype = md::cmark_node_get_list_type(parent);
                 start_num = md::cmark_node_get_list_start(parent);
             }
             
             int bullet_x = start_x - 15;
             int bullet_y = *cur_y + (self.font_size / 2) - 4; // approximate centering
             
             if (ptype == 1) // Bullet
             {
                 rl::draw_circle(bullet_x, bullet_y + 4, 3.0, rl::BLACK);
             }
             else // Ordered
             {
                 // Calculate index
                 int idx = start_num;
                 void* prev = md::cmark_node_previous(n);
                 while(prev != null) { idx++; prev = md::cmark_node_previous(prev); }
                 
                 char[16] num_buf; 
   
                 snprintf((char*)&num_buf, 16, "%d.", idx);
                 rl::draw_text((ZString)&num_buf, bullet_x - 10, *cur_y, self.font_size, rl::BLACK);
             }
        }
        else if (type == md::CMARK_NODE_CODE_BLOCK)
        {
             char* code = md::cmark_node_get_literal(n);
             if (code != null) {
                 // Simple rendering of code block
                 int block_y_start = *cur_y;
                 rl::draw_text_ex(self.fonts[2], (ZString)code, (rl::RLVector2){(float)start_x + 5, (float)*cur_y + 5}, (float)self.font_size, 1.0, (rl::RLColor){60,60,60,255});
                 
                 // Measure height roughly by counting newlines
                 int lines = 1;
                 int c = 0; while(code[c]!=0) { if(code[c]=='\n') lines++; c++; }
                 
                 int h = lines * (self.font_size + 2) + 10;
                 // Draw background behind (oops, we drew text first. Immediate mode order matters)
                 // Redraw rect first? 
                 // Actually let's just draw rect at the stored pos? No, we need to know H before drawing ??
                 // For now, draw rect behind text by calculating H first.
                 
                 rl::draw_rectangle(start_x, block_y_start, max_width - start_x, h, (rl::RLColor){240, 240, 240, 255});
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

        // --- Inline Styles ---
        if (type == md::CMARK_NODE_STRONG) next_style.is_bold = true;
        if (type == md::CMARK_NODE_EMPH) next_style.is_italic = true;
        if (type == md::CMARK_NODE_CODE) next_style.is_code = true;
        if (type == md::CMARK_NODE_LINK) next_style.is_link = true; // URL handling skipped for visual simplicity

        // --- Text Rendering ---
        if (type == md::CMARK_NODE_TEXT || type == md::CMARK_NODE_CODE)
        {
            char* text = md::cmark_node_get_literal(n);
            if (text != null)
            {
                rl::RLColor color = rl::BLACK;
                
                // USER REQUEST: Fix gray text. Make sure Bold/Italic remain black (or dark)
                // Only code gets gray background/color.
                if (next_style.is_link)  { color = rl::BLUE; }
                else if (next_style.is_code) { color = (rl::RLColor){60,60,60,255}; }
                // else if (next_style.is_italic) ... // Keep black
                
                if (next_style.is_header) color = rl::DARKBLUE;

                int font_size = self.font_size;
                if (next_style.is_header) 
                {
                    if (next_style.header_level == 1) { font_size = 40; }
                    else if (next_style.header_level == 2) { font_size = 32; }
                    else if (next_style.header_level == 3) { font_size = 28; }
                    else { font_size = 24; }
                }

                // Inline code background
                bool draw_bg = (next_style.is_code && type == md::CMARK_NODE_CODE);

                int text_len = 0; while(text[text_len]!=0) text_len++;
                
                for (int k = 0; k < text_len; k++)
                {
                    char c = text[k];
                    char[2] str_buf; str_buf[0] = c; str_buf[1] = 0;
                    
                    // Use monospace for code, Italic fallback for italic
                    rl::RLFont f = self.font;
                    if (next_style.is_code) {f = self.fonts[2];}
                    else if (next_style.is_italic) {f = self.font_italic;}

                    rl::RLVector2 v = rl::measure_text_ex(f, (ZString)&str_buf, (float)font_size, 1.0);
                    int char_w = (int)v.x;
                    
                    if (*cur_x + char_w > max_width && max_width > 0 && *cur_x > start_x)
                    {
                         *cur_x = start_x;
                         *cur_y += font_size + 4;
                    }
                    
                    if (draw_bg)
                    {
                        rl::draw_rectangle(*cur_x, *cur_y, char_w, font_size + 2, (rl::RLColor){230,230,230,255});
                    }
                    
                    if (next_style.is_bold) {
                        // Fake bold by offset
                        rl::draw_text_ex(f, (ZString)&str_buf, (rl::RLVector2){(float)(*cur_x + 1), (float)*cur_y}, (float)font_size, 1.0, color);
                    }
                    
                    rl::draw_text_ex(f, (ZString)&str_buf, (rl::RLVector2){(float)*cur_x, (float)*cur_y}, (float)font_size, 1.0, color);
                    
                    *cur_x += char_w;
                }
            }
        }
        else if (type == md::CMARK_NODE_SOFTBREAK)
        {
             // Treat soft breaks as hard breaks (GitHub/Editor style)
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
        
        // Post-Block Spacing
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
