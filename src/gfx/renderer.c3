module markpad::gfx;
import std::core::mem;
import std::io;
import raylib55::rl;
import markpad::editor;
import markpad::md;

struct Renderer
{
	rl::RLFont[5] fonts;
    char*[5] font_names;
    int current_font_idx;
    
	rl::RLFont font;
    rl::RLFont font_italic;
	
	int font_size;
	int char_width;
	int line_height;
}

fn void Renderer.init(Renderer* self)
{
	self.fonts[0] = rl::get_font_default();
    self.font_names[0] = "Default";
    
	self.fonts[1] = rl::load_font_ex("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 32, (int*)0, 0);
    if (self.fonts[1].texture.id == 0) self.fonts[1] = rl::get_font_default();
    self.font_names[1] = "DejaVu";
    
    self.fonts[2] = rl::load_font_ex("resources/Fira/FiraCode-Bold.ttf", 32, (int*)0, 0);
    self.font_names[2] = "Fira Code";
    
    self.fonts[3] = rl::load_font_ex("resources/JetBrainsMono/JetBrainsMono-Regular.ttf", 32, (int*)0, 0);
    self.font_names[3] = "JetBrains Mono";
    
    self.fonts[4] = rl::load_font_ex("resources/Cascadia/CascadiaCode.ttf", 32, (int*)0, 0);
    self.font_names[4] = "Cascadia Code";

    self.current_font_idx = 0;
	self.font = self.fonts[0];
    
    // Load Italic Fallback
    self.font_italic = rl::load_font_ex("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Oblique.ttf", 32, (int*)0, 0);
    if (self.font_italic.texture.id == 0) self.font_italic = self.fonts[0];

	self.font_size = 20;
	self.line_height = 24;
    self.recalc_metrics();
}

fn void Renderer.free(Renderer* self)
{
    // Index 0 is default font, we don't own it.
    // Indexes 1-4 are loaded fonts, unless they failed load and are copies of default.
    for (int i = 1; i < 5; i++)
    {
        if (self.fonts[i].texture.id != self.fonts[0].texture.id)
        {
            rl::unload_font(self.fonts[i]);
        }
    }
    
    if (self.font_italic.texture.id != self.fonts[0].texture.id)
    {
        rl::unload_font(self.font_italic);
    }
}

fn void Renderer.recalc_metrics(Renderer* self)
{
    rl::RLVector2 v = rl::measure_text_ex(self.font, "M", (float)self.font_size, 1.0);
    self.char_width = (int)v.x;
}

fn void Renderer.set_font(Renderer* self, int index)
{
    if (index >= 0 && index < 5)
    {
        self.current_font_idx = index;
        if (self.fonts[self.current_font_idx].texture.id != 0)
        {
            self.font = self.fonts[self.current_font_idx];
        }
        else {
             self.font = self.fonts[0];
        }
        self.recalc_metrics();
    }
}

fn void Renderer.toggle_font(Renderer* self)
{
    self.current_font_idx = (self.current_font_idx + 1) % 5;
    
    while (self.fonts[self.current_font_idx].texture.id == 0 && self.current_font_idx != 0)
    {
         self.current_font_idx = (self.current_font_idx + 1) % 5;
    }
    
    self.font = self.fonts[self.current_font_idx];
    self.recalc_metrics();
}

fn void Renderer.draw_simple_text(Renderer* self, char* text, int x, int y, int size, rl::RLColor color)
{
	rl::draw_text((ZString)text, x, y, size, color);
}
