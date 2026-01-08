module markpad;
import raylib55::rl;
import markpad::editor;
import markpad::gfx;
import std::core::mem;

// Handles Editor Typing, Shortcuts, and Editor Mouse Interaction
fn void App.handle_editor_input(App *self)
{
	editor::State* state = &self.state;
	editor::FileBrowser* browser = &self.browser;
	gfx::Renderer* renderer = &self.renderer;

	bool ctrl = rl::is_key_down(rl::RLKeyboardKey.LEFT_CONTROL) || rl::is_key_down(rl::RLKeyboardKey.RIGHT_CONTROL);
	bool shift = rl::is_key_down(rl::RLKeyboardKey.LEFT_SHIFT) || rl::is_key_down(rl::RLKeyboardKey.RIGHT_SHIFT);

	while (true)
	{
		int key = rl::get_char_pressed();
		if (key == 0) break;
		if (!ctrl) state.insert_char((char)key);
	}
	
	int wheel = (int)rl::get_mouse_wheel_move();
	if (wheel != 0)
	{
		state.scroll_y -= wheel * 24;
		if (state.scroll_y < 0) state.scroll_y = 0;
	}

	int mx = rl::get_mouse_x();
	int my = rl::get_mouse_y();
    int sw = rl::get_screen_width();
    int scrollbar_x = sw - 15;
    if (state.show_markdown_preview) scrollbar_x = (sw / 2) - 15;
	
    if (self.is_dragging_scrollbar)
    {
        if (rl::is_mouse_button_up(rl::RLMouseButton.LEFT))
        {
            self.is_dragging_scrollbar = false;
        }
        else
        {
            int line_height = renderer.line_height;
            usz len = state.buffer.len();
            int line_count = 1;
            
            for (usz k = 0; k < len; k++) { if (state.buffer.get_char_at(k) == '\n') line_count++; }
            int content_h = line_count * line_height;
            int screen_h = rl::get_screen_height();
            
            if (content_h > screen_h)
            {
                int scroll_track_h = screen_h;
                float view_ratio = (float)screen_h / (float)content_h;
                int scroll_thumb_h = (int)(screen_h * view_ratio);
                 if (scroll_thumb_h < 30) scroll_thumb_h = 30;
                
                int track_avail = screen_h - scroll_thumb_h;
                int mouse_relative = my - self.scrollbar_drag_y_offset;
                
                float ratio = (float)mouse_relative / (float)track_avail;
                if (ratio < 0.0) ratio = 0.0;
                if (ratio > 1.0) ratio = 1.0;
                
                state.scroll_y = (int)(ratio * (float)(content_h - screen_h));
            }
        }
    }
    
	if (rl::is_mouse_button_pressed(rl::RLMouseButton.LEFT))
	{
        if (mx >= scrollbar_x && mx <= scrollbar_x + 15)
        {
            self.is_dragging_scrollbar = true;
            self.scrollbar_drag_y_offset = 0; 
        }
        else
        {
            usz index = renderer.get_index_at_pos(state, mx, my, 50, 50);
            state.set_cursor_pos(index, shift);
        }
	}
	else if (rl::is_mouse_button_down(rl::RLMouseButton.LEFT) && my > 30 && !self.is_dragging_scrollbar)
	{
		usz index = renderer.get_index_at_pos(state, mx, my, 50, 50);
		state.set_cursor_pos(index, true); 
	}

	// Keys
	if (rl::is_key_pressed(rl::RLKeyboardKey.ENTER) || rl::is_key_pressed_repeat(rl::RLKeyboardKey.ENTER)) 
	{
		state.insert_char('\n');
	}
	if (rl::is_key_pressed(rl::RLKeyboardKey.BACKSPACE) || rl::is_key_pressed_repeat(rl::RLKeyboardKey.BACKSPACE)) state.backspace();
	if (rl::is_key_pressed(rl::RLKeyboardKey.LEFT) || rl::is_key_pressed_repeat(rl::RLKeyboardKey.LEFT)) state.move_left(shift);
	if (rl::is_key_pressed(rl::RLKeyboardKey.RIGHT) || rl::is_key_pressed_repeat(rl::RLKeyboardKey.RIGHT)) state.move_right(shift);
	if (rl::is_key_pressed(rl::RLKeyboardKey.UP) || rl::is_key_pressed_repeat(rl::RLKeyboardKey.UP)) state.move_up(shift);
	if (rl::is_key_pressed(rl::RLKeyboardKey.DOWN) || rl::is_key_pressed_repeat(rl::RLKeyboardKey.DOWN)) state.move_down(shift);
	
	// Shortcuts
	if (ctrl)
	{
		if (rl::is_key_pressed(rl::RLKeyboardKey.S)) 
		{
			if (state.current_file != null) 
			{
				state.save_file();
			}
			else {
				self.active_modal = 4; // Browser Save
				browser.refresh();
				self.input_len = 0;
				self.input_buf[0] = 0;
			}
		}
		if (rl::is_key_pressed(rl::RLKeyboardKey.A)) state.select_all();
		
		if (rl::is_key_pressed(rl::RLKeyboardKey.C))
		{
			char* text = state.get_selection_text();
			if (text)
			{
				rl::set_clipboard_text((ZString)text);
				mem::free(text);
			}
		}
		
		if (rl::is_key_pressed(rl::RLKeyboardKey.X))
		{
			char* text = state.get_selection_text();
			if (text)
			{
				rl::set_clipboard_text((ZString)text);
				mem::free(text);
				state.delete_selection();
			}
		}
		
		if (rl::is_key_pressed(rl::RLKeyboardKey.V))
		{
			char* text = (char*)rl::get_clipboard_text();
			if (text)
			{
				state.insert_string(text);
			}
		}
	}
}
