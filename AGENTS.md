## Code style
- camelCase for all variables and method names that aren't Godot APIs
- PascalCase for class names and constants
- break up lines that are over 100 characters
- use type annotations when declaring variables
- no code comments unless the code is very unintuitive
- descriptive variable names
- if a file reaches a certain size break it down into smaller logical pieces. Same principle with large methods more than 100 lines - break them down. Try to ensure code is modular when applicable.
## General
- Godot version is 4.5 - some Godot 3 APIs are not available
- Do not create uid files, Godot will create them automatically.
- If writing any loops, think about how many times it will iterate and if we should consider some optimizations.