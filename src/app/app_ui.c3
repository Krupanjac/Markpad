module markpad;
import raylib55::rl;
import markpad::editor;
import markpad::gfx;
import std::core::mem;

// Handles Mouse clicks on Menu Bar and Dropdowns
// Returns true if the input was consumed by the menu system
fn bool App.handle_menu_interaction(App *self)
{
	int mx = rl::get_mouse_x();
	int my = rl::get_mouse_y();
	bool clicked = rl::is_mouse_button_pressed(rl::RLMouseButton.LEFT);
	
	if (!clicked) return false;
	
	bool clicked_menu_item = false;
	
	// Handle Dropdown Clicks if open
	if (self.active_menu == 1) // File
	{
		if (mx >= 10 && mx <= 210 && my > 30 && my < 150)
		{
			clicked_menu_item = true;
			self.active_menu = 0; // Close dropdown after selection
			
			if (my < 60) { // New
				self.state.init();
			} else if (my < 90) { // Open
				self.active_modal = 3; // Browser Open
				self.browser.refresh();
				self.input_len = 0; 
				self.input_buf[0] = 0; 
			} else if (my < 120) { // Save
				if (self.state.current_file != null) 
				{
					self.state.save_file();
				}
				else {
					self.active_modal = 4; // Browser Save
					self.browser.refresh();
					self.input_len = 0;
					self.input_buf[0] = 0;
				}
			} else { // Exit
				self.quit = true;
			}
			return true;
		}
	}
	else if (self.active_menu == 3) // View
	{
		if (mx >= 110 && mx <= 310 && my > 30 && my < 150)
		{
			clicked_menu_item = true; 
			self.active_menu = 0;
			
			if (my < 60) {
				self.state.word_wrap = !self.state.word_wrap;
			}
			else if (my < 90) {
				self.state.show_markdown_syntax = !self.state.show_markdown_syntax;
			}
			else if (my < 120) {
				self.state.show_markdown_preview = !self.state.show_markdown_preview;
			}
			
			return true;
		}
	}
	
	// Check Menu Bar Hits using coordinates from main.c3 logic
	if (my <= 30)
	{
		if (mx >= 10 && mx <= 55) {
			self.active_menu = (self.active_menu == 1) ? 0 : 1;
		} else if (mx >= 60 && mx <= 105) {
			self.active_menu = (self.active_menu == 2) ? 0 : 2;
		} else if (mx >= 110 && mx <= 155) {
			self.active_menu = (self.active_menu == 3) ? 0 : 3;
		} else if (mx >= 160 && mx <= 205) {
			self.active_menu = (self.active_menu == 4) ? 0 : 4;
		} else {
			self.active_menu = 0; // Clicked on empty space in bar
		}
		return true; // Click was on menu bar, so consumed
	}
	
	// If menu was active but we clicked outside (and not on bar), close it
	if (self.active_menu > 0) {
		self.active_menu = 0;
		// Do not return true, let the click pass through to editor
		// This matches "clicking away" behavior
	}

	return false;
}

fn void App.update_modal(App *self)
{
	editor::FileBrowser* browser = &self.browser;
	
	// Browser Mouse Interaction
	if (self.active_modal >= 3)
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
		
		if (rl::is_mouse_button_pressed(rl::RLMouseButton.LEFT))
		{
			// X button
			if (mx > x + w - 70 && mx < x + w - 10 && my > y + h - 40 && my < y + h - 10)
			{
				self.active_modal = 0;
			}
			// OK button
			else if (mx > x + w - 140 && mx < x + w - 80 && my > y + h - 40 && my < y + h - 10)
			{
				self.confirm_modal();
			}
			// List click
			else if (mx > x + 10 && mx < x + w - 10 && my > list_y && my < list_y + h - 100)
			{
				int rel_y = my - list_y - 5;
				int item_h = 24;
				if (rel_y > 0)
				{
					int idx = (rel_y / item_h);
					int file_idx = idx - 1 + browser.scroll_offset;
					
					if (idx == 0) // clicked ".."
					{
						browser.up_dir();
					}
					else if (file_idx >= 0 && file_idx < browser.files.count)
					{
						browser.selected_index = file_idx;
						char* raw_path = browser.files.paths[file_idx];
						
						// Extract filename from path (handle Windows/Unix separators)
						// This prevents path duplication if Raylib returns full paths
						char* path = raw_path;
						int rp_len = 0; while (raw_path[rp_len] != 0) rp_len++;
						for (int k = rp_len - 1; k >= 0; k--) {
							if (raw_path[k] == '/' || raw_path[k] == '\\') {
								path = &raw_path[k+1];
								break;
							}
						}
						char[2048] check_path;
						usz clen = 0; while (browser.current_directory[clen] != 0) clen++;
						for(int i=0; i<clen; i++) check_path[i] = browser.current_directory[i];
						
						usz nlen = 0; while (path[nlen] != 0) nlen++;
						for(int i=0; i<nlen; i++) check_path[clen + i] = path[i];
						check_path[clen+nlen] = 0;
						
						if (rl::directory_exists((ZString)&check_path))
						{
							browser.enter_dir(path);
							self.input_len = 0;
							self.input_buf[0] = 0;
						}
						else
						{
							self.input_len = 0;
							for(int i=0; i<nlen && i<255; i++) {
								self.input_buf[i] = path[i];
								self.input_len++;
							}
							self.input_buf[self.input_len] = 0;
						}
					}
				}
			}
		}
		
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

	// Keyboard Input
	int key = rl::get_char_pressed();
	while (key > 0)
	{
		if (key >= 32 && key <= 125 && self.input_len < 255)
		{
			self.input_buf[self.input_len] = (char)key;
			self.input_len++;
			self.input_buf[self.input_len] = 0;
		}
		key = rl::get_char_pressed();
	}
	
	if (rl::is_key_pressed(rl::RLKeyboardKey.BACKSPACE) && self.input_len > 0)
	{
		self.input_len--;
		self.input_buf[self.input_len] = 0;
	}
	
	if (rl::is_key_pressed(rl::RLKeyboardKey.ESCAPE))
	{
		self.active_modal = 0;
	}
	
	if (rl::is_key_pressed(rl::RLKeyboardKey.ENTER))
	{
		self.confirm_modal();
	}
}

fn void App.confirm_modal(App *self)
{
	editor::State* state = &self.state;
	editor::FileBrowser* browser = &self.browser;
	int active_modal = self.active_modal;
	
	if (self.input_len > 0)
	{
		char[2048] full_path;
		full_path[0] = 0;
		usz dlen = 0; 
		if (active_modal >= 3) { // Browser
			while (browser.current_directory[dlen] != 0) dlen++;
			for(int i=0; i<dlen; i++) full_path[i] = browser.current_directory[i];
		}
		
		for(int i=0; i<self.input_len; i++) full_path[dlen + i] = self.input_buf[i];
		full_path[dlen + self.input_len] = 0;

		if (active_modal == 1 || active_modal == 3) // Open
		{
			state.load_file((char*)&full_path);
		}
		else if (active_modal == 2 || active_modal == 4) // Save
		{
			if (state.current_file) mem::free(state.current_file);
			usz flen = dlen + (usz)self.input_len;
			state.current_file = (char*)mem::alloc_array(char, flen + 1);
			mem::copy(state.current_file, &full_path, flen + 1);
			state.save_file();
		}
		self.active_modal = 0;
	}
}
