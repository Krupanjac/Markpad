module markpad;

fn int main(String[] args)
{
	  mem::@report_heap_allocs_in_scope()
	  {
	App app;
	app.init();
	app.run();
	return 0;
	  };
}
