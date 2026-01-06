module markpad::editor;
import std::io;
import std::core::mem;
import raylib55::rl;

struct State
{
	GapBuffer buffer;
	int scroll_y;
	// Path to current file, null if new
	char* current_file;
	
	// Selection: Anchor is where selection started, buffer.gap_start is where it ends (caret)
	usz selection_anchor;
	bool word_wrap;
}

fn void State.init(State *self)
{
	self.buffer.init(1024);
	self.scroll_y = 0;
	self.current_file = null;
	self.selection_anchor = 0;
	self.word_wrap = false;
}

fn void State.insert_char(State *self, char c)
{
	self.delete_selection();
	self.buffer.insert_char(c);
	self.selection_anchor = self.buffer.gap_start;
}

fn void State.insert_string(State *self, char* str)
{
	self.delete_selection();
	while (*str != 0)
	{
		self.buffer.insert_char(*str);
		str++;
	}
	self.selection_anchor = self.buffer.gap_start;
}

fn void State.backspace(State *self)
{
	if (self.has_selection())
	{
		self.delete_selection();
	}
	else
	{
		self.buffer.delete_backward();
		self.selection_anchor = self.buffer.gap_start;
	}
}

fn void State.move_left(State *self, bool select)
{
	if (self.buffer.gap_start > 0)
	{
		self.buffer.move_gap(self.buffer.gap_start - 1);
	}
	if (!select) self.selection_anchor = self.buffer.gap_start;
}

fn void State.move_right(State *self, bool select)
{
	if (self.buffer.gap_start < self.buffer.len())
	{
		self.buffer.move_gap(self.buffer.gap_start + 1);
	}
	if (!select) self.selection_anchor = self.buffer.gap_start;
}

fn void State.move_up(State *self, bool select)
{
	usz cursor = self.buffer.gap_start;
	if (cursor == 0) return;
	
	// Find start of current line and column offest
	usz curr_line_start = cursor;
	while (curr_line_start > 0 && self.buffer.get_char_at(curr_line_start - 1) != '\n')
	{
		curr_line_start--;
	}
	usz column = cursor - curr_line_start;
	
	if (curr_line_start == 0) 
	{
		// On first line, move to start
		self.set_cursor_pos(0, select);
		return;
	}
	
	// Find start of previous line
	usz prev_line_end = curr_line_start - 1; // The newline before current line
	usz prev_line_start = prev_line_end;
	
	// Scan back for start of previous line
	while (prev_line_start > 0 && self.buffer.get_char_at(prev_line_start - 1) != '\n')
	{
		prev_line_start--;
	}
	
	usz prev_line_len = prev_line_end - prev_line_start;
	usz target_col = column;
	if (target_col > prev_line_len) target_col = prev_line_len;
	
	self.set_cursor_pos(prev_line_start + target_col, select);
}

fn void State.move_down(State *self, bool select)
{
	usz cursor = self.buffer.gap_start;
	usz len = self.buffer.len();
	if (cursor >= len) return;
	
	// Find start of current line
	usz curr_line_start = cursor;
	while (curr_line_start > 0 && self.buffer.get_char_at(curr_line_start - 1) != '\n')
	{
		curr_line_start--;
	}
	usz column = cursor - curr_line_start;
	
	// Find end of current line
	usz curr_line_end = cursor;
	while (curr_line_end < len && self.buffer.get_char_at(curr_line_end) != '\n')
	{
		curr_line_end++;
	}
	
	if (curr_line_end == len)
	{
		// On last line, move to end
		self.set_cursor_pos(len, select);
		return;
	}
	
	// Start of next line
	usz next_line_start = curr_line_end + 1;
	usz next_line_end = next_line_start;
	while (next_line_end < len && self.buffer.get_char_at(next_line_end) != '\n')
	{
		next_line_end++;
	}
	
	usz next_line_len = next_line_end - next_line_start;
	usz target_col = column;
	if (target_col > next_line_len) target_col = next_line_len;
	
	self.set_cursor_pos(next_line_start + target_col, select);
}

fn bool State.has_selection(State *self)
{
	return self.selection_anchor != self.buffer.gap_start;
}

fn void State.select_all(State *self)
{
	self.buffer.move_gap(self.buffer.len());
	self.selection_anchor = 0;
}

fn char* State.get_selection_text(State *self)
{
	if (!self.has_selection()) return null;
	
	usz start = self.selection_anchor < self.buffer.gap_start ? self.selection_anchor : self.buffer.gap_start;
	usz end = self.selection_anchor > self.buffer.gap_start ? self.selection_anchor : self.buffer.gap_start;
	usz len = end - start;
	
	char* text = (char*)mem::alloc_array(char, len + 1);
	
	// Complex copy because of gap
	// Ideally we add a get_range method to buffer, but implementing here for speed
	for (usz i = 0; i < len; i++)
	{
		text[i] = self.buffer.get_char_at(start + i);
	}
	text[len] = 0;
	return text;
}

fn void State.delete_selection(State *self)
{
	if (!self.has_selection()) return;
	
	usz start = self.selection_anchor < self.buffer.gap_start ? self.selection_anchor : self.buffer.gap_start;
	usz end = self.selection_anchor > self.buffer.gap_start ? self.selection_anchor : self.buffer.gap_start;
	
	// Move gap to end of selection
	self.buffer.move_gap(end);
	
	// Delete backward until start
	while (self.buffer.gap_start > start)
	{
		self.buffer.delete_backward();
	}
	
	self.selection_anchor = self.buffer.gap_start;
}

fn void State.set_cursor_pos(State *self, usz pos, bool select)
{
	if (pos > self.buffer.len()) pos = self.buffer.len();
	
	self.buffer.move_gap(pos);
	
	if (!select) 
	{
		self.selection_anchor = self.buffer.gap_start;
	}
}

fn void State.save_file(State *self)
{
	if (self.current_file == null)
	{
		io::printn("No file selected to save.");
		return;
	}
	
	usz len = self.buffer.len();
	char* text = (char*)mem::alloc_array(char, len + 1);
	
	// Copy part 1
	mem::copy(text, self.buffer.data, self.buffer.gap_start);
	
	// Copy part 2
	mem::copy(text + self.buffer.gap_start, self.buffer.data + self.buffer.gap_end, self.buffer.capacity - self.buffer.gap_end);
	
	text[len] = 0;
	
	rl::save_file_text((ZString)self.current_file, (ZString)text);
	
	mem::free(text);
	io::printn("Saved.");
}

fn void State.load_file(State *self, char* filename)
{
	char* text = (char*)rl::load_file_text((ZString)filename);
	if (text == null) return;
	
	self.buffer.free();
	
	usz len = 0;
	while (text[len] != 0) len++;
	
	// Init with extra capacity
	self.buffer.init(len + 1024);
	
	// Copy text to buffer start
	mem::copy(self.buffer.data, text, len);
	self.buffer.gap_start = len;
	self.buffer.gap_end = self.buffer.capacity; // Gap at end
	
	rl::unload_file_text((ZString)text);
	
	if (self.current_file) mem::free(self.current_file);
	
	// Copy filename
	usz fn_len = 0;
	while (filename[fn_len] != 0) fn_len++;
	self.current_file = (char*)mem::alloc_array(char, fn_len + 1);
	mem::copy(self.current_file, filename, fn_len + 1);
	
	io::printn("Loaded file.");
}
