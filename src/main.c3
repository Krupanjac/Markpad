module markpad;
import std::io;
import markpad::platform;
import markpad::editor;
import markpad::gfx;
import raylib55::rl;

fn int main(String[] args)
{
	platform::init_window();
	
	editor::State state;
	state.init();
	
	editor::FileBrowser browser;
	browser.init();
	
	gfx::Renderer renderer;
	renderer.init();

	io::printn("Markpad started...");

	int active_menu = 0; // 0=None, 1=File, 2=Edit, 3=View, 4=Help
	int active_modal = 0; // 0=None, 1=Open, 2=Save, 3=Browser(Open), 4=Browser(Save)
	
	char[256] input_buf;
	int input_len = 0;
	// Zero init
	for (int i = 0; i < 256; i++) input_buf[i] = 0;

	while (!platform::should_close())
	{
		// --- Drag & Drop ---
		if (rl::is_file_dropped())
		{
			rl::RLFilePathList dropped = rl::load_dropped_files();
			if (dropped.count > 0)
			{
				io::printn("File dropped!");
				state.load_file((char*)dropped.paths[0]);
			}
			rl::unload_dropped_files(dropped);
		}

		if (active_modal != 0)
		{
			// Browser Logic
			if (active_modal >= 3)
			{
				int mx = rl::get_mouse_x();
				int my = rl::get_mouse_y();
				int sw = rl::get_screen_width();
				int sh = rl::get_screen_height();
				int w = 600;
				int h = 500;
				int x = (sw / 2) - (w / 2);
				int y = (sh / 2) - (h / 2);
				int list_y = y + 50;
				
				// Handle clicks
				if (rl::is_mouse_button_pressed(rl::RLMouseButton.LEFT))
				{
					// Close button logic? (Simple area check)
					// X button
					if (mx > x + w - 70 && mx < x + w - 10 && my > y + h - 40 && my < y + h - 10)
					{
						active_modal = 0;
					}
					// OK button
					else if (mx > x + w - 140 && mx < x + w - 80 && my > y + h - 40 && my < y + h - 10)
					{
						// Submit
						if (input_len > 0)
						{
							// Concat dir + filename
							// Simplified for this demo
							char[2048] full_path;
							full_path[0] = 0;
							
							// Copy dir
							usz dlen = 0; while (browser.current_directory[dlen] != 0) dlen++;
							for(int i=0; i<dlen; i++) full_path[i] = browser.current_directory[i];
							
							// Copy file
							for(int i=0; i<input_len; i++) full_path[dlen + i] = input_buf[i];
							full_path[dlen + input_len] = 0;
							
							if (active_modal == 3) // Open
							{
								state.load_file((char*)&full_path);
							}
							else // Save
							{
								// Set state file
								if (state.current_file) mem::free(state.current_file);
								usz flen = dlen + (usz)input_len;
								state.current_file = (char*)mem::alloc_array(char, flen + 1);
								mem::copy(state.current_file, &full_path, flen + 1);
								state.save_file();
							}
							active_modal = 0;
						}
					}
					// List click
					else if (mx > x + 10 && mx < x + w - 10 && my > list_y && my < list_y + h - 100)
					{
						int rel_y = my - list_y - 5; // header offset
						int item_h = 24;
						if (rel_y > 0)
						{
							int idx = (rel_y / item_h); // 0 is parent
							int file_idx = idx - 1 + browser.scroll_offset;
							
							if (idx == 0) // clicked ".."
							{
								browser.up_dir();
							}
							else if (file_idx >= 0 && file_idx < browser.files.count)
							{
								browser.selected_index = file_idx;
								// Check if dir
								char* path = browser.files.paths[file_idx];
								
								// Construct full path to check is_dir
								// This is tricky without string builder, assuming simple check by name or reloading
								// Try to enter
								char[1024] test_path;
								// Not robust but let's try assuming if it has no extension it is dir (bad assumption but useful for now)
								// Actually Raylib directory listing includes directories.
								// Let's just try to enter, if it fails assume file
								
								// Better: directory_exists check on full path
								char[2048] check_path;
								usz clen = 0; while (browser.current_directory[clen] != 0) clen++;
								for(int i=0; i<clen; i++) check_path[i] = browser.current_directory[i];
								
								usz nlen = 0; while (path[nlen] != 0) nlen++;
								for(int i=0; i<nlen; i++) check_path[clen + i] = path[i];
								check_path[clen+nlen] = 0;
								
								if (rl::directory_exists((ZString)&check_path))
								{
									browser.enter_dir(path);
									input_len = 0;
									input_buf[0] = 0;
								}
								else
								{
									// Is file, select it
									input_len = 0;
									for(int i=0; i<nlen && i<255; i++) {
										input_buf[i] = path[i];
										input_len++;
									}
									input_buf[input_len] = 0;
								}
							}
						}
					}
				}
				
				// Scroll
				int wheel = (int)rl::get_mouse_wheel_move();
				if (wheel != 0)
				{
					browser.scroll_offset -= wheel;
					if (browser.scroll_offset < 0) browser.scroll_offset = 0;
					if (browser.files.count > 10 && browser.scroll_offset > browser.files.count - 10) 
					{
						browser.scroll_offset = browser.files.count - 10;
					}
				}
			}

			// Modal Input (Shared logic with browser input field)
			int key = rl::get_char_pressed();
			while (key > 0)
			{
				if (key >= 32 && key <= 125 && input_len < 255)
				{
					input_buf[input_len] = (char)key;
					input_len++;
					input_buf[input_len] = 0;
				}
				key = rl::get_char_pressed();
			}
			
			if (rl::is_key_pressed(rl::RLKeyboardKey.BACKSPACE) && input_len > 0)
			{
				input_len--;
				input_buf[input_len] = 0;
			}
			
			if (rl::is_key_pressed(rl::RLKeyboardKey.ESCAPE))
			{
				active_modal = 0;
			}
			
			if (rl::is_key_pressed(rl::RLKeyboardKey.ENTER))
			{
				// ENTER Logic handle above for clicks, duplicating here for keyboard confirm
				if (input_len > 0)
				{
					// Same submit logic
					char[2048] full_path;
					full_path[0] = 0;
					usz dlen = 0; 
					if (active_modal >= 3) { // Browser
						while (browser.current_directory[dlen] != 0) dlen++;
						for(int i=0; i<dlen; i++) full_path[i] = browser.current_directory[i];
					}
					
					for(int i=0; i<input_len; i++) full_path[dlen + i] = input_buf[i];
					full_path[dlen + input_len] = 0;

					if (active_modal == 1 || active_modal == 3) // Open
					{
						state.load_file((char*)&full_path);
					}
					else if (active_modal == 2 || active_modal == 4) // Save
					{
						if (state.current_file) mem::free(state.current_file);
						usz flen = dlen + (usz)input_len;
						state.current_file = (char*)mem::alloc_array(char, flen + 1);
						mem::copy(state.current_file, &full_path, flen + 1);
						state.save_file();
					}
					active_modal = 0;
				}
			}
		}
		else
		{
			// Normal Input
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
				bool clicked_menu = false;
				
				// Handle Dropdown Clicks if open
				if (active_menu == 1) // File
				{
					if (mx >= 10 && mx <= 210 && my > 30 && my < 150)
					{
						clicked_menu = true;
						active_menu = 0; // Close logic
						
						if (my < 60) { // New
							state.init();
						} else if (my < 90) { // Open
							active_modal = 3; // Browser Open
							browser.refresh();
							input_len = 0; 
							input_buf[0] = 0; 
						} else if (my < 120) { // Save
							if (state.current_file != null) 
							{
								state.save_file();
							}
							else {
								active_modal = 4; // Browser Save
								browser.refresh();
								input_len = 0;
								input_buf[0] = 0;
							}
						} else { // Exit
							break;
						}
					}
				}
				else if (active_menu == 3) // View
				{
					if (mx >= 110 && mx <= 310 && my > 30 && my < 60)
					{
						clicked_menu = true;
						active_menu = 0;
						state.word_wrap = !state.word_wrap;
					}
				}
				
				if (!clicked_menu)
				{
					// Menu Bar Hitbox Check
					if (my <= 30)
					{
						if (mx >= 10 && mx <= 55) {
							active_menu = (active_menu == 1) ? 0 : 1;
						} else if (mx >= 60 && mx <= 105) {
							active_menu = (active_menu == 2) ? 0 : 2;
						} else if (mx >= 110 && mx <= 155) {
							active_menu = (active_menu == 3) ? 0 : 3;
						} else if (mx >= 160 && mx <= 205) {
							active_menu = (active_menu == 4) ? 0 : 4;
						} else {
							active_menu = 0;
						}
					}
					else
					{
						// Editor Click (Start Selection / Move Cursor)
						active_menu = 0;
						usz index = renderer.get_index_at_pos(&state, mx, my, 50, 50);
						state.set_cursor_pos(index, shift);
					}
				}
			}
			else if (rl::is_mouse_button_down(rl::RLMouseButton.LEFT) && my > 30)
			{
				// Mouse Selection Drag
				usz index = renderer.get_index_at_pos(&state, mx, my, 50, 50);
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
						active_modal = 4; // Browser Save
						browser.refresh();
						input_len = 0;
						input_buf[0] = 0;
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

		platform::begin_drawing();
		
		renderer.draw_menu_bar();
		renderer.draw_buffer(&state, 50, 50);
		
		if (active_menu > 0)
		{
			renderer.draw_menu_dropdown(active_menu);
		}
		
		if (active_modal != 0)
		{
			if (active_modal >= 3)
			{
				char* title = (active_modal == 3) ? "Open File" : "Save File As";
				renderer.draw_file_browser(&browser, title, (char*)&input_buf);
			}
			else
			{
				char* title = (active_modal == 1) ? "Open File (Path):" : "Save File (Path):";
				renderer.draw_modal(title, (char*)&input_buf);
			}
		}
		
		platform::end_drawing();
	}


	platform::close_window();
	io::printn("Markpad exited.");
	return 0;
}
