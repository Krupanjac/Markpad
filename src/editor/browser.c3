module markpad::editor;
import raylib55::rl;
import std::core::mem;
import std::io;

struct FileBrowser
{
	char[1024] current_directory;
	rl::RLFilePathList files;
	int selected_index;
	int scroll_offset;
	bool is_open;
	bool is_save_mode;
}

fn void FileBrowser.init(FileBrowser *self)
{
	self.current_directory[0] = '.';
	self.current_directory[1] = '/';
	self.current_directory[2] = 0;
	
	self.refresh();
}

fn void FileBrowser.free(FileBrowser *self)
{
	if (self.files.count > 0)
	{
		rl::unload_directory_files(self.files);
	}
}

fn void FileBrowser.refresh(FileBrowser *self)
{
	if (self.files.count > 0)
	{
		rl::unload_directory_files(self.files);
	}
	self.files = rl::load_directory_files((ZString)&self.current_directory);
	self.selected_index = -1;
	self.scroll_offset = 0;
}

fn void FileBrowser.up_dir(FileBrowser *self)
{
	usz len = 0;
	while (self.current_directory[len] != 0) len++;
	
	if (len < 1020)
	{
		self.current_directory[len] = '.';
		self.current_directory[len+1] = '.';
		self.current_directory[len+2] = '/';
		self.current_directory[len+3] = 0;
		self.refresh();
	}
}

fn void FileBrowser.enter_dir(FileBrowser *self, char* dir_name)
{
	usz len = 0;
	while (self.current_directory[len] != 0) len++;
	usz name_len = 0;
	while (dir_name[name_len] != 0) name_len++;
	
	if (len + name_len + 2 < 1024)
	{
		mem::copy((char*)&self.current_directory + len, dir_name, name_len);
		len += name_len;
		self.current_directory[len] = '/';
		self.current_directory[len+1] = 0;
		self.refresh();
	}
}

fn bool FileBrowser.is_dir(FileBrowser *self, char* path)
{
	return rl::directory_exists((ZString)path);
}
