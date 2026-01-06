module markpad::gfx;
import raylib55::rl;
import markpad::editor;
import markpad::md;

struct Renderer
{
	rl::RLFont font;
	int font_size;
	int char_width;
	int line_height;
}

fn void Renderer.init(Renderer* self)
{
	self.font = rl::get_font_default();
	self.font_size = 20;
	self.char_width = 12; // Approximation for default font
	self.line_height = 24;
}

fn void Renderer.draw_simple_text(Renderer* self, char* text, int x, int y, int size, rl::RLColor color)
{
	rl::draw_text((ZString)text, x, y, size, color);
}

// Calculate the buffer index for a given screen position (hit testing)
fn usz Renderer.get_index_at_pos(Renderer* self, editor::State* state, int target_x, int target_y, int start_x, int start_y)
{
	int effective_start_y = start_y - state.scroll_y;
	if (target_y < effective_start_y) return 0; // Or better logic?

	int cur_x = start_x;
	int cur_y = effective_start_y;
	usz len = state.buffer.len();
	int max_width = rl::get_screen_width() - start_x - 10;
	if (state.show_markdown_preview) max_width = (rl::get_screen_width() / 2) - start_x - 10;

	// Simple hit test: find closest character
	for (usz i = 0; i < len; i++)
	{
		// If we are on the same line
		if (target_y >= cur_y && target_y < cur_y + self.line_height)
		{
			// If we are significantly to the left of this char, current char is the one (or previous)
			// But simpler: Is X with char range?
			if (target_x < cur_x + self.char_width) {
				return i;
			}
		}

		char c = state.buffer.get_char_at(i);
		
		if (c == '\n')
		{
			// If we were on this line but reached the end, return this index (end of line)
			if (target_y >= cur_y && target_y < cur_y + self.line_height) {
				return i;
			}
			cur_x = start_x;
			cur_y += self.line_height;
			continue;
		}
		
		if (state.word_wrap && cur_x > start_x + max_width)
		{
			// If we matched line but wrapped, assume it was near end of previous visual line
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

fn void Renderer.draw_buffer(Renderer* self, editor::State* state, int start_x, int start_y)
{
	editor::GapBuffer* buffer = &state.buffer;
	int cur_x = start_x;
	int cur_y = start_y - state.scroll_y; // Apply Scroll
	usz len = buffer.len();
	int max_width = rl::get_screen_width() - start_x - 10;
	if (state.show_markdown_preview) max_width = (rl::get_screen_width() / 2) - start_x - 10;
	
	usz sel_start = state.selection_anchor < buffer.gap_start ? state.selection_anchor : buffer.gap_start;
	usz sel_end = state.selection_anchor > buffer.gap_start ? state.selection_anchor : buffer.gap_start;
	bool selected = sel_start != sel_end;

	// Syntax State
	bool new_line = true;
	rl::RLColor current_color = rl::BLACK;
	int current_font_size = self.font_size; 

	// Draw content
	for (usz i = 0; i < len; i++)
	{
		// Skip drawing if above screen (Optimization)
		// But we must calculate positions correctly
		bool visible = (cur_y + self.line_height > 30) && (cur_y < rl::get_screen_height());

		// Checking selection early to draw background
		if (selected && i >= sel_start && i < sel_end && visible)
		{
			rl::draw_rectangle(cur_x, cur_y, self.char_width, self.line_height, rl::SKYBLUE);
		}

		// Draw Cursor
		if (i == buffer.gap_start && visible)
		{
			rl::draw_rectangle(cur_x, cur_y, 2, self.line_height, rl::RED);
		}

		char c = buffer.get_char_at(i);
		
		// Check Syntax at start of line
		if (new_line && state.show_markdown_syntax)
		{
			new_line = false;
			current_color = rl::BLACK;
			current_font_size = self.font_size;
			
			// Simple Header Check
			if (c == '#') {
				current_color = rl::BLUE;
				if (i + 1 < len && buffer.get_char_at(i+1) == ' ') current_font_size = 24; 
			}
			if (c == '>') {
				current_color = rl::GRAY;
			}
		}

		if (c == '\n')
		{
			cur_x = start_x;
			cur_y += self.line_height; 
			new_line = true;
			current_color = rl::BLACK;
			current_font_size = self.font_size;
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

		// Draw Char
		if (visible)
		{
			char[2] str;
			str[0] = c;
			str[1] = 0;
			rl::draw_text((ZString)&str, cur_x, cur_y, current_font_size, current_color);
		}
		
		cur_x += self.char_width;
	}
	
	// Draw Cursor if at end
	if (buffer.gap_start == len)
	{
		rl::draw_rectangle(cur_x, cur_y, 2, self.line_height, rl::RED);
	}
}

fn void Renderer.draw_modal(Renderer* self, char* title, char* input_text)
{
	int sw = rl::get_screen_width();
	int sh = rl::get_screen_height();
	
	// Overlay
	rl::draw_rectangle(0, 0, sw, sh, (rl::RLColor){ 0, 0, 0, 100 });
	
	int w = 400;
	int h = 120;
	int x = (sw / 2) - (w / 2);
	int y = (sh / 2) - (h / 2);
	
	rl::draw_rectangle(x, y, w, h, rl::RAYWHITE);
	rl::draw_rectangle_lines(x, y, w, h, rl::GRAY);
	
	rl::draw_text((ZString)title, x + 10, y + 10, 20, rl::BLACK);
	
	// Input Box
	rl::draw_rectangle(x + 10, y + 40, w - 20, 30, rl::WHITE);
	rl::draw_rectangle_lines(x + 10, y + 40, w - 20, 30, rl::LIGHTGRAY);
	
	rl::draw_text((ZString)input_text, x + 15, y + 45, 20, rl::BLACK);
	
	rl::draw_text("Enter to Confirm, Esc to Cancel", x + 10, y + 90, 10, rl::GRAY);
}

fn void Renderer.draw_file_browser(Renderer* self, editor::FileBrowser* browser, char* title, char* input_text)
{
	int sw = rl::get_screen_width();
	int sh = rl::get_screen_height();
	
	// Overlay
	rl::draw_rectangle(0, 0, sw, sh, (rl::RLColor){ 0, 0, 0, 100 });
	
	int w = 600;
	int h = 500;
	int x = (sw / 2) - (w / 2);
	int y = (sh / 2) - (h / 2);
	
	rl::draw_rectangle(x, y, w, h, rl::RAYWHITE);
	rl::draw_rectangle_lines(x, y, w, h, rl::GRAY);
	
	// Title
	rl::draw_text((ZString)title, x + 10, y + 10, 20, rl::BLACK);
	rl::draw_text((ZString)&browser.current_directory, x + 10, y + 30, 10, rl::DARKGRAY);
	
	// File List Area
	int list_y = y + 50;
	int list_h = h - 100;
	rl::draw_rectangle(x + 10, list_y, w - 20, list_h, rl::WHITE);
	rl::draw_rectangle_lines(x + 10, list_y, w - 20, list_h, rl::LIGHTGRAY);
	
	// Draw Items
	int item_h = 24;
	int view_max = list_h / item_h;
	int start_idx = browser.scroll_offset;
	int count = browser.files.count;
	
	// Item 0 is always ".."
	rl::draw_text(".. (Parent Directory)", x + 20, list_y + 5, 20, rl::BLUE);
	
	for (int i = 0; i < view_max; i++)
	{
		int idx = start_idx + i;
		if (idx >= count) break;
		
		int render_y = list_y + ((i + 1) * item_h) + 5; // offset by 1 for ".."
		
		char* filename = browser.files.paths[idx];
		bool is_sel = (idx == browser.selected_index);
		
		if (is_sel) {
			rl::draw_rectangle(x + 12, render_y, w - 24, item_h, rl::SKYBLUE);
		}
		
		rl::RLColor col = rl::BLACK;
		// Determine valid full path to check if dir
		// Making a temp buffer for path check
		// Note provided browser.c3 doesn't have is_dir fully wired for list items yet without concat
		// So we might just draw all as black for now or try to check
		// Optimization: Just draw text
		
		rl::draw_text((ZString)filename, x + 20, render_y + 2, 20, col);
	}
	
	// Input Box (for filename)
	int input_y = y + h - 40;
	rl::draw_rectangle(x + 10, input_y, w - 160, 30, rl::WHITE);
	rl::draw_rectangle_lines(x + 10, input_y, w - 160, 30, rl::LIGHTGRAY);
	rl::draw_text((ZString)input_text, x + 15, input_y + 5, 20, rl::BLACK);
	
	// Buttons
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

		rl::draw_text("Show Syntax", start_x + 30, start_y + 35, 20, rl::BLACK);
		if (state.show_markdown_syntax) rl::draw_text("x", start_x + 10, start_y + 35, 20, rl::DARKGREEN);

		rl::draw_text("Show Preview", start_x + 30, start_y + 65, 20, rl::BLACK);
		if (state.show_markdown_preview) rl::draw_text("x", start_x + 10, start_y + 65, 20, rl::DARKGREEN);
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
int cur_y = start_y;

usz i = 0;
usz len = state.buffer.len();

while (i < len)
{
// Extract line
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

// Parse Style
md::MDStyle style = md::check_line_style((char*)&line_buf, (usz)line_len);

int font_size = self.font_size;
rl::RLColor color = rl::BLACK;
int x_offset = 0;

if (style.is_header)
{
    color = rl::DARKBLUE;
    if (style.header_level == 1) { font_size = 40; }
    else if (style.header_level == 2) { font_size = 32; }
    else if (style.header_level == 3) { font_size = 28; }
    else { font_size = 24; }
}
else if (style.is_quote)
{
    color = rl::GRAY;
    x_offset = 20;
    rl::draw_rectangle(cur_x, cur_y, 4, font_size, rl::LIGHTGRAY);
}
else if (style.is_list_item)
{
    rl::draw_circle(cur_x + 10, cur_y + (font_size / 2), 4.0, rl::BLACK);
    x_offset = 20;
}

// Visual simulation for Inline Styles (Header takes precedence)
// We only change color/indicator since we don't have font variants in default font
if (style.is_bold) color = rl::BLACK; 
if (style.is_italic) color = rl::DARKGRAY;
if (style.is_strikethrough) color = rl::GRAY;
if (style.is_link) color = rl::BLUE;
if (style.is_code) 
{
    color = (rl::RLColor){ 50, 50, 50, 255 };
    rl::draw_rectangle(cur_x, cur_y, width, font_size + 4, rl::LIGHTGRAY);
}

// Prepare text for rendering (Skip tokens)
char* text_ptr = (char*)&line_buf;
if (style.is_header) text_ptr = &line_buf[style.header_level + 1];
if (style.is_quote) text_ptr = &line_buf[2];
if (style.is_list_item) text_ptr = &line_buf[2];


// Word Wrapping Logic
int text_len = 0; while(text_ptr[text_len] != 0) text_len++;
if (text_len == 0 && !style.is_list_item) { 
    // empty line
    cur_y += font_size + 4; 
    continue; 
}

int current_x_offset = x_offset;
int available_width = width - x_offset - 10;
int drawn_chars = 0;

// Standard Rendering (No Wrap)
if (!state.word_wrap)
{
    rl::draw_text((ZString)text_ptr, cur_x + current_x_offset, cur_y, font_size, color);
    cur_y += font_size + 4;
    continue;
}

while (drawn_chars < text_len)
{
    // Greedily take as many words as fit
    int fit_count = 0;
    int pixel_width = 0;
    int last_space = -1;
    
    // Measure char by char (approximation using char_width)
    // Raylib's MeasureText is better but unavailable in this binding easily? 
    // We assume self.char_width = 12 constant for now (Monospaced default font)
    // For variable width font like Default, we should use MeasureText
    
    for (int k = drawn_chars; k < text_len; k++)
    {
        // Simple width check: Measure from drawn_chars to k
        char c_backup = text_ptr[k+1];
        text_ptr[k+1] = 0;
        int w = rl::measure_text((ZString)&text_ptr[drawn_chars], font_size);
        text_ptr[k+1] = c_backup;
        
        if (w > available_width)
        {
            if (last_space != -1) {
                fit_count = (last_space - drawn_chars) + 1; // Include space
            } else {
                fit_count = (k - drawn_chars); // Force break word
                if (fit_count == 0) fit_count = 1; // Always draw at least one char
            }
            break;
        }
        
        if (text_ptr[k] == ' ') last_space = k;
        fit_count = (k - drawn_chars) + 1;
    }
    
    // Draw the segment
    char c_backup_end = text_ptr[drawn_chars + fit_count];
    text_ptr[drawn_chars + fit_count] = 0;
    rl::draw_text((ZString)&text_ptr[drawn_chars], cur_x + current_x_offset, cur_y, font_size, color);
    text_ptr[drawn_chars + fit_count] = c_backup_end;
    
    drawn_chars += fit_count;
    cur_y += font_size + 2;
    // Indent subsequent lines if quote/list?
    // Maybe keep offset? Yes.
}

cur_y += 4; // Extra paragraph spacing
}
}
