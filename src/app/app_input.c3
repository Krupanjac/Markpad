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
	
	int user_wheel = (int)rl::get_mouse_wheel_move();
	int mx = rl::get_mouse_x();
	int my = rl::get_mouse_y();
    int sw = rl::get_screen_width();
    int screen_h = rl::get_screen_height();
    
    // Determine scroll limits
    int max_scroll_edit = state.editor_content_height - screen_h;
    if (max_scroll_edit < 0) max_scroll_edit = 0;
    
    int max_scroll_prev = state.preview_content_height - screen_h;
    if (max_scroll_prev < 0) max_scroll_prev = 0;
    
    // Wheel Scrolling
	if (user_wheel != 0)
	{
        if (state.independent_scroll && state.show_markdown_preview)
        {
             // Independent Mode
             if (mx > sw / 2)
             {
                 state.scroll_y_preview -= user_wheel * 24;
                 if (state.scroll_y_preview < 0) state.scroll_y_preview = 0;
                 if (state.scroll_y_preview > max_scroll_prev) state.scroll_y_preview = max_scroll_prev;
             }
             else
             {
                 state.scroll_y -= user_wheel * 24;
                 if (state.scroll_y < 0) state.scroll_y = 0;
                 if (state.scroll_y > max_scroll_edit) state.scroll_y = max_scroll_edit;
             }
        }
        else
        {
             // Synced Mode (or no preview)
             int limit = max_scroll_edit;
             if (state.show_markdown_preview && max_scroll_prev > limit) limit = max_scroll_prev; // "dictates length"
             
             state.scroll_y -= user_wheel * 24;
             if (state.scroll_y < 0) state.scroll_y = 0;
             if (state.scroll_y > limit) state.scroll_y = limit;
             
             // Sync preview
             state.scroll_y_preview = state.scroll_y;
        }
	}

    int editor_scrollbar_x = sw - 15;
    if (state.show_markdown_preview) editor_scrollbar_x = (sw / 2) - 15;
    
    // Preview scrollbar is at the right edge
    int preview_scrollbar_x = sw - 15; 
	
    // 1. Handle Editor Scrollbar Drag
    if (self.is_dragging_scrollbar)
    {
        if (rl::is_mouse_button_up(rl::RLMouseButton.LEFT))
        {
            self.is_dragging_scrollbar = false;
        }
        else
        {
            int content_h = state.editor_content_height;
            // Use limits logic
            int limit = content_h - screen_h;
            if (!state.independent_scroll && state.show_markdown_preview)
            {
               // In synced mode, we might drag past editor content if preview is longer
               if (state.preview_content_height > content_h) limit = state.preview_content_height - screen_h;
            }

            if (content_h > screen_h || limit > 0)
            {
                int scroll_track_h = screen_h;
                // Calculate thumb size based on ratio of viewport to content
                int effective_content_h = (limit + screen_h);
                float view_ratio = (float)screen_h / (float)effective_content_h;
                
                int scroll_thumb_h = (int)(screen_h * view_ratio);
                if (scroll_thumb_h < 30) scroll_thumb_h = 30;
                
                int track_avail = screen_h - scroll_thumb_h;
                int mouse_relative = my - self.scrollbar_drag_y_offset;
                
                float ratio = (float)mouse_relative / (float)track_avail;
                if (ratio < 0.0) ratio = 0.0;
                if (ratio > 1.0) ratio = 1.0;
                
                state.scroll_y = (int)(ratio * (float)limit);
                if (!state.independent_scroll) state.scroll_y_preview = state.scroll_y;
            }
        }
    }
    // 2. Handle Preview Scrollbar Drag
    else if (self.is_dragging_preview_scrollbar)
    {
        if (rl::is_mouse_button_up(rl::RLMouseButton.LEFT))
        {
            self.is_dragging_preview_scrollbar = false;
        }
        else
        {
             int content_h = state.preview_content_height;
             if (content_h > screen_h)
             {
                 float view_ratio = (float)screen_h / (float)content_h;
                 int scroll_thumb_h = (int)(screen_h * view_ratio);
                 if (scroll_thumb_h < 30) scroll_thumb_h = 30;
                 
                 int track_avail = screen_h - scroll_thumb_h;
                 int mouse_relative = my - self.scrollbar_drag_y_offset;
                 float ratio = (float)mouse_relative / (float)track_avail;
                 if (ratio < 0.0) ratio = 0.0;
                 if (ratio > 1.0) ratio = 1.0;
                 
                 int val = (int)(ratio * (float)(content_h - screen_h));
                 
                 if (state.independent_scroll) {
                     state.scroll_y_preview = val;
                 } else {
                     // If we allow dragging preview scrollbar in synced mode, it drags both?
                     // Usually dragging right bar should drag both.
                     // But we should respect the "dictates length" rule.
                     state.scroll_y = val;
                     state.scroll_y_preview = val;
                 }
             }
        }
    }
    
	if (rl::is_mouse_button_pressed(rl::RLMouseButton.LEFT))
	{
        // Hit Test Editor Scrollbar
        if (mx >= editor_scrollbar_x && mx <= editor_scrollbar_x + 15)
        {
            self.is_dragging_scrollbar = true;
            self.scrollbar_drag_y_offset = 0; 
        }
        // Hit Test Preview Scrollbar (only if visible)
        else if (state.show_markdown_preview && mx >= preview_scrollbar_x && mx <= sw) 
        {
             self.is_dragging_preview_scrollbar = true;
             self.scrollbar_drag_y_offset = 0;
        }
        else
        {
            usz index = renderer.get_index_at_pos(state, mx, my, 50, 50);
            state.set_cursor_pos(index, shift);
        }
	}
	else if (rl::is_mouse_button_down(rl::RLMouseButton.LEFT) && my > 30 && !self.is_dragging_scrollbar && !self.is_dragging_preview_scrollbar)
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
