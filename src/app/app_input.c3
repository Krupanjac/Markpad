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

	// Text Input
	while (true)
	{
		int key = rl::get_char_pressed();
		if (key == 0) break;
		if (!ctrl) state.insert_char((char)key);
	}
	
	// Mouse Interaction
	int mx = rl::get_mouse_x();
	int my = rl::get_mouse_y();
	
	if (rl::is_mouse_button_pressed(rl::RLMouseButton.LEFT))
	{
		// Editor Click (Start Selection / Move Cursor)
		// We assume menu handled its clicks earlier and returned false
		usz index = renderer.get_index_at_pos(state, mx, my, 50, 50);
		state.set_cursor_pos(index, shift);
	}
	else if (rl::is_mouse_button_down(rl::RLMouseButton.LEFT) && my > 30)
	{
		// Mouse Selection Drag
		usz index = renderer.get_index_at_pos(state, mx, my, 50, 50);
		state.set_cursor_pos(index, true); // Dragging implies selecting
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
