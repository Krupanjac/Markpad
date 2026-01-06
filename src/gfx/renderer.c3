module markpad::gfx;
import raylib55::rl;
import markpad::editor;

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
	if (target_y < start_y) return 0;

	int cur_x = start_x;
	int cur_y = start_y;
	usz len = state.buffer.len();
	int max_width = rl::get_screen_width() - start_x - 10;
	
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
	int cur_y = start_y;
	usz len = buffer.len();
	int max_width = rl::get_screen_width() - start_x - 10;
	
	usz sel_start = state.selection_anchor < buffer.gap_start ? state.selection_anchor : buffer.gap_start;
	usz sel_end = state.selection_anchor > buffer.gap_start ? state.selection_anchor : buffer.gap_start;
	bool selected = sel_start != sel_end;

	// Draw content
	for (usz i = 0; i < len; i++)
	{
		// Checking selection early to draw background
		if (selected && i >= sel_start && i < sel_end)
		{
			rl::draw_rectangle(cur_x, cur_y, self.char_width, self.line_height, rl::SKYBLUE);
		}

		// Draw Cursor
		if (i == buffer.gap_start)
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

		// Draw Char
		char[2] str;
		str[0] = c;
		str[1] = 0;
		rl::draw_text((ZString)&str, cur_x, cur_y, self.font_size, rl::BLACK);
		
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

fn void Renderer.draw_menu_dropdown(Renderer* self, int menu_id)
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
		int height = item_height * 1;
		rl::draw_rectangle(start_x, start_y, width, height, rl::RAYWHITE);
		rl::draw_rectangle_lines(start_x, start_y, width, height, rl::GRAY);
		
		rl::draw_text("Word Wrap", start_x + 10, start_y + 5, 20, rl::BLACK);
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
