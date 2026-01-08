module markpad::editor;
import std::core::mem;
import std::io;

struct GapBuffer
{
	char* data;
	usz capacity;
	usz gap_start;
	usz gap_end;
}

fn void GapBuffer.init(GapBuffer *self, usz initial_capacity = 1024)
{
	self.capacity = initial_capacity;
	self.data = (char*)mem::alloc_array(char, initial_capacity);
	self.gap_start = 0;
	self.gap_end = initial_capacity;
}

fn void GapBuffer.free(GapBuffer *self)
{
	mem::free(self.data);
	self.data = null;
	self.capacity = 0;
}

fn usz GapBuffer.len(GapBuffer *self)
{
	return self.capacity - (self.gap_end - self.gap_start);
}

fn usz GapBuffer.gap_size(GapBuffer *self)
{
	return self.gap_end - self.gap_start;
}

fn void GapBuffer.insert_char(GapBuffer *self, char c) 
{
	if (self.gap_size() == 0) {
		self.grow();
	}
	
	self.data[self.gap_start] = c;
	self.gap_start++;
}

fn void GapBuffer.grow(GapBuffer *self)
{
	usz new_capacity = self.capacity * 2;
	char* new_data = (char*)mem::alloc_array(char, new_capacity);
	
	mem::move(new_data, self.data, self.gap_start);
	
	usz right_len = self.capacity - self.gap_end;
	mem::move(new_data + (new_capacity - right_len), self.data + self.gap_end, right_len);
	
	mem::free(self.data);
	self.data = new_data;
	self.gap_end = new_capacity - right_len;
	self.capacity = new_capacity;
}

fn void GapBuffer.print_debug(GapBuffer *self)
{
	io::printn("Buffer Content: ");
	for (usz i = 0; i < self.gap_start; i++) {
		io::printf("%c", self.data[i]);
	}
	for (usz i = self.gap_end; i < self.capacity; i++) {
		io::printf("%c", self.data[i]);
	}
	io::printn("");
}

fn void GapBuffer.move_gap(GapBuffer *self, usz new_pos)
{
	if (new_pos > self.len()) new_pos = self.len();
	
	if (new_pos < self.gap_start)
	{
		usz dist = self.gap_start - new_pos;
		mem::move(self.data + self.gap_end - dist, self.data + new_pos, dist);
		self.gap_start -= dist;
		self.gap_end -= dist;
	}
	else if (new_pos > self.gap_start)
	{
		usz dist = new_pos - self.gap_start;
		mem::move(self.data + self.gap_start, self.data + self.gap_end, dist);
		self.gap_start += dist;
		self.gap_end += dist;
	}
}

fn void GapBuffer.delete_backward(GapBuffer *self)
{
	if (self.gap_start > 0)
	{
		self.gap_start--;
	}
}

fn char GapBuffer.get_char_at(GapBuffer *self, usz index)
{
	if (index < self.gap_start) {
		return self.data[index];
	}
	return self.data[index + (self.gap_end - self.gap_start)];
}
