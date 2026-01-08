module markpad;
import markpad::platform;
import markpad::editor;
import markpad::gfx;
import raylib55::rl;
import std::io;

struct App
{
	editor::State state;
	editor::FileBrowser browser;
	gfx::Renderer renderer;
	
	int active_menu; 
	int active_modal; 
	
	char[256] input_buf;
	int input_len;
	
    bool is_dragging_scrollbar;
    int scrollbar_drag_y_offset;

	bool quit;
}

fn void App.init(App *self)
{
	platform::init_window();
	
	self.state.init();
	self.browser.init();
	self.renderer.init();

	self.active_menu = 0;
	self.active_modal = 0;
	self.input_len = 0;
    self.is_dragging_scrollbar = false;
    self.scrollbar_drag_y_offset = 0;
	self.quit = false;
	for (int i = 0; i < 256; i++) self.input_buf[i] = 0;

	io::printn("Markpad started...");
}

fn void App.run(App *self)
{
	while (!platform::should_close() && !self.quit)
	{
		self.update();
		self.draw();
	}
    
    self.renderer.free();
    self.browser.free();
    
	platform::close_window();
    
    self.state.free();
    
	io::printn("Markpad exited.");
}

fn void App.update(App *self)
{
	editor::State* state = &self.state;

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

	if (self.active_modal != 0)
	{
		self.update_modal();
	}
	else
	{
		bool input_handled = self.handle_menu_interaction();
		if (!input_handled)
		{
			self.handle_editor_input();
		}
	}
}

fn void App.draw(App *self)
{
	platform::begin_drawing();
	
	self.renderer.draw_menu_bar();
	
	if (self.state.show_markdown_preview)
	{
		int sw = rl::get_screen_width();
		int half_w = (sw / 2);
		
		rl::begin_scissor_mode(0, 30, half_w, rl::get_screen_height() - 30);
			self.renderer.draw_buffer(&self.state, 50, 50, half_w - 50); 
		rl::end_scissor_mode();
		
		rl::draw_line(half_w, 30, half_w, rl::get_screen_height(), rl::GRAY);
		
		rl::begin_scissor_mode(half_w, 30, half_w, rl::get_screen_height() - 30);
			self.renderer.draw_markdown_preview(&self.state, half_w + 10, 50, half_w - 20);
		rl::end_scissor_mode();
	}
	else
	{
		int sw = rl::get_screen_width();
		self.renderer.draw_buffer(&self.state, 50, 50, sw - 50);
	}
	
	if (self.active_menu > 0)
	{
		self.renderer.draw_menu_dropdown(self.active_menu, &self.state);
	}
	
	if (self.active_modal != 0)
	{
		if (self.active_modal >= 3)
		{
            if (self.active_modal == 5)
            {
                self.renderer.draw_font_selector();
            }
            else
            {
                char* title = (self.active_modal == 3) ? "Open File" : "Save File As";
                self.renderer.draw_file_browser(&self.browser, title, (char*)&self.input_buf);
            }
		}
		else
		{
			char* title = (self.active_modal == 1) ? "Open File (Path):" : "Save File (Path):";
			self.renderer.draw_modal(title, (char*)&self.input_buf);
		}
	}
	
	platform::end_drawing();
}
