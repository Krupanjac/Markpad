module markpad::platform;
import raylib55::rl;
import markpad::config;

// Wrap raylib functions to keep dependencies isolated
fn void init_window()
{
	rl::init_window(config::WINDOW_WIDTH, config::WINDOW_HEIGHT, config::APP_TITLE);
	rl::set_target_fps(config::TARGET_FPS);
	rl::set_window_state(rl::RLConfigFlag.WINDOW_RESIZABLE);
}

fn void close_window()
{
	rl::close_window();
}

fn bool should_close()
{
	return rl::window_should_close();
}

fn void begin_drawing()
{
	rl::begin_drawing();
	rl::clear_background(rl::RAYWHITE);
}

fn void end_drawing()
{
	rl::end_drawing();
}
