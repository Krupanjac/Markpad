module markpad::gfx;
import raylib55::rl;
import markpad::editor;
import markpad::md;

struct Renderer
{
	rl::RLFont[5] fonts;
    char*[5] font_names;
    int current_font_idx;
    
	rl::RLFont font;
	
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
    self.font_names[1] = "System (DejaVu)";
    
    self.fonts[2] = rl::load_font_ex("resources/Fira/FiraCode-Regular.ttf", 32, (int*)0, 0);
    self.font_names[2] = "Fira Code";
    
    self.fonts[3] = rl::load_font_ex("resources/JetBrainsMono/JetBrainsMono-Regular.ttf", 32, (int*)0, 0);
    self.font_names[3] = "JetBrains Mono";
    
    self.fonts[4] = rl::load_font_ex("resources/Cascadia/CascadiaCode.ttf", 32, (int*)0, 0);
    self.font_names[4] = "Cascadia Code";

    self.current_font_idx = 0;
	self.font = self.fonts[0];
    
	self.font_size = 20;
	self.line_height = 24;
    self.recalc_metrics();
}

fn void Renderer.recalc_metrics(Renderer* self)
{
    rl::RLVector2 v = rl::measure_text_ex(self.font, "M", (float)self.font_size, 1.0);
    self.char_width = (int)v.x;
    
    if (self.current_font_idx == 0) self.char_width += 4;
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
		
		rl::draw_text("Font:", start_x + 10, start_y + 65, 20, rl::BLACK);
        rl::draw_text((ZString)self.font_names[self.current_font_idx], start_x + 60, start_y + 65, 20, rl::DARKGRAY);
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
    int cur_x = start_x;
    int cur_y = start_y - state.scroll_y;

    usz i = 0;
    usz len = state.buffer.len();

    while (i < len)
    {
        char[1024] line_buf;
        int line_len = 0;
        while (i < len && line_len < 1023)
        {
            char c = state.buffer.get_char_at(i);
            if (c == '\n') 
            {
                i++;
                break;
            }
            line_buf[line_len] = c;
            line_len++;
            i++;
        }
        line_buf[line_len] = 0;

        int old_y = cur_y;
        if (line_len > 0) {
            void* doc = md::cmark_parse_document((char*)&line_buf, (usz)line_len, 0);
            if (doc != null) {
                defer md::cmark_node_free(doc);
                md::MDStyle st = {};
                self.draw_markdown_nodes(doc, &cur_x, &cur_y, start_x, start_x + width, st);
            }
        }
        if (cur_y == old_y) { cur_y += self.font_size + 4; }
        else { cur_y += 4; }
        cur_x = start_x;
    }
}

fn void Renderer.draw_markdown_nodes(Renderer* self, void* node, int* cur_x, int* cur_y, int start_x, int max_width, md::MDStyle style)
{
    void* n = node;
    while (n != null)
    {
        int type = md::cmark_node_get_type(n);
        md::MDStyle next_style = style;
        
        if (type == md::CMARK_NODE_STRONG) next_style.is_bold = true;
        if (type == md::CMARK_NODE_EMPH) next_style.is_italic = true;
        if (type == md::CMARK_NODE_CODE) next_style.is_code = true;
        if (type == md::CMARK_NODE_LINK) 
        {
             next_style.is_link = true;
        }
        if (type == md::CMARK_NODE_HEADING)
        {
            next_style.is_header = true;
            next_style.header_level = md::cmark_node_get_heading_level(n);
        }
        if (type == md::CMARK_NODE_BLOCK_QUOTE) 
        {
            next_style.is_quote = true;
        }
        
        if (type == md::CMARK_NODE_ITEM || type == md::CMARK_NODE_LIST)
        {
             if (type == md::CMARK_NODE_ITEM)
             {
                 rl::draw_circle(*cur_x + 6, *cur_y + (self.font_size / 2) + 2, 3.0, rl::BLACK);
                 *cur_x += 20;
             }
        }

        if (type == md::CMARK_NODE_TEXT || type == md::CMARK_NODE_CODE)
        {
            char* text = md::cmark_node_get_literal(n);
            if (text != null)
            {
                rl::RLColor color = rl::BLACK;
                if (next_style.is_link)  { color = rl::BLUE; }
                else if (next_style.is_code) { color = (rl::RLColor){60,60,60,255}; }
                else if (next_style.is_quote) { color = rl::GRAY; }
                else if (next_style.is_italic) { color = (rl::RLColor){80, 80, 80, 255}; }
                
                if (next_style.is_header) color = rl::DARKBLUE;

                int font_size = self.font_size;
                if (next_style.is_header) 
                {
                    if (next_style.header_level == 1) { font_size = 40; }
                    else if (next_style.header_level == 2) { font_size = 32; }
                    else if (next_style.header_level == 3) { font_size = 28; }
                    else { font_size = 24; }
                }
                
                if (next_style.is_code && type == md::CMARK_NODE_CODE)
                {
                     rl::RLVector2 v = rl::measure_text_ex(self.font, (ZString)text, (float)font_size, 1.0);
                     int w = (int)v.x;
                     rl::draw_rectangle(*cur_x, *cur_y, w, font_size + 2, rl::LIGHTGRAY);
                }
                
                rl::RLVector2 main_v = rl::measure_text_ex(self.font, (ZString)text, (float)font_size, 1.0);
                int w = (int)main_v.x;
                
                if (*cur_x + w > max_width && max_width > 0)
                {
                     *cur_x = start_x;
                     *cur_y += font_size + 4;
                }

                if (next_style.is_bold)
                {
                    rl::draw_text_ex(self.font, (ZString)text, (rl::RLVector2){(float)(*cur_x + 1), (float)*cur_y}, (float)font_size, 1.0, color);
                }
                rl::draw_text_ex(self.font, (ZString)text, (rl::RLVector2){(float)*cur_x, (float)*cur_y}, (float)font_size, 1.0, color);
                
                *cur_x += w;
            }
        }
        else if (type == md::CMARK_NODE_SOFTBREAK)
        {
             rl::RLVector2 v = rl::measure_text_ex(self.font, " ", (float)self.font_size, 1.0);
             *cur_x += (int)v.x;
        }

        void* child = md::cmark_node_first_child(n);
        if (child != null)
        {
            self.draw_markdown_nodes(child, cur_x, cur_y, start_x, max_width, next_style);
        }

        n = md::cmark_node_next(n);
    }
}
