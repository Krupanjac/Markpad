module markpad::gfx;
import raylib55::rl;
import markpad::editor;

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