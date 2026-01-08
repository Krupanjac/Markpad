# Markpad

Markpad is a lightweight Markdown editor built using the [C3 programming language](https://c3-lang.org/) and [Raylib](https://www.raylib.com/). It aims to provide a performant writing environment with real-time preview capabilities.

**Note:** This is a personal pet project created to explore the capabilities of C3 in a GUI application.
***README.md*** is written using **Markpad.**

## Features

- **Live Markdown Preview**:
  - Split-screen editing with real-time rendering.
  - Powered by `libcmark` (CommonMark compliant).
  - Supports Headers, Blockquotes, Nested Lists (Ordered/Unordered), Code Blocks, and visual separators.
  - Typography support for **Bold**, *Italic*, and `Inline Code`.
- **Core Editor Engine**: 
  - Implements a **Gap Buffer** for O(1) text insertion and deletion at the cursor.
  - Custom text rendering engine built on Raylib 5.5.
  - Dynamic, strictly-wrapped text layout.
- **Customization**:
  - Bundled developer fonts: **Fira Code**, **JetBrains Mono**, **Cascadia Code**, and **DejaVu Sans**.
  - Toggleable view settings.
- **UI & Tools**:
  - File Browser for opening/saving files.
  - Interactive scrollbar.
  - Standard clipboard operations (Cut, Copy, Paste).

## Requirements

- **C3 Compiler**: Latest stable version.
- **Dependencies**: 
  - `Raylib 5.5` (bindings included).
  - `libcmark` (dynamic link required).

## Building and Running

1. **Clone the repository**:
   ```bash
   git clone https://github.com/krupanjac/Markpad.git
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
