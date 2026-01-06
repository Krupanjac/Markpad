# Markpad

Markpad is a lightweight, efficient text editor built using the [C3 programming language](https://c3-lang.org/) and [Raylib](https://www.raylib.com/). It aims to provide a text editor experience with a focus on performance and simplicity.

## Features

- **Efficient Text Management**: Implements a Gap Buffer data structure for fast text insertion and deletion.
- **Raylib Rendering**: Custom text rendering engine built on top of Raylib 5.5.
- **Standard Editor Controls**: 
  - File Operations: Open, Save, Save As (via modal dialogs).
  - Editing: Cut, Copy, Paste, Select All.
  - Navigation: Arrow keys, Mouse click placement, Drag selection.
- **UI Elements**:
  - Menu Bar (File, Edit, View, Help).
  - Modal Dialogs for file paths.
  - Dynamic Word Wrapping.

## Requirements

- **C3 Compiler**: Version 0.7.9 or later.
- **Raylib 5.5**: The project uses the vendorized bindings or library.

## Building and Running

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Krupanjac/Markpad.git
   cd Markpad
   ```

2. **Build the project**:
   Use the C3 compiler to build the executable.
   ```bash
   c3c build
   ```

3. **Run the editor**:
   ```bash
   ./build/Markpad
   # or
   c3c run
   ```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
