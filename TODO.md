# Todos

## UI

The UI still needs a lot of work.

- [x] Manual hash map: Move from map\[string\]... -> some custom implementation using a u64 as a key
    - [x] Find a good hash function for small strings
    - [x] Support `##` and `###` in the strings provided for hashing.
    - [x] Only have one hash map and use the `Box.framed` as the indicator for wether we should free it or not
- [x] More rect settings
    - [x] Border
    - [x] Border Color
    - [x] Font
    - [x] Font Size
    - [x] Text Align
    - [x] Text Padding
- [ ] Scrollable areas
- [ ] Polish
- [ ] More default widgets
    - [ ] Well working text editing widget, think about BiDi and such.

## Font

Quite nice already, works for my use case.

- [x] Figure out why so unclear
- [ ] Rename ID -> Key/Handle

## Window

Needs a general refactor for multiple, nice to have, features.

- [x] Refactor window creation out and make it reusable, also track all created windows.
    - [x] Has to support multiple EGL surfaces
    - [ ] Support popups for stuff like hover text and so on, maybe, not sure yet.
    - [ ] Also support real popups
- [ ] Windows support, needs to be done before shipping anything
- [x] A bit of cleanup would never hurt

## Render

Currently works well enough.

- [x] Figure out why text unclear -> Font#1
- [ ] Support multiple OpenGL contextes

## File Interface (NEW)

We need some uniform file interface for managing files. These files should come from the local file system and some few files should be embedable (and also hot-reloadable via access over the file system).
In the future we would want to support different kind of remote files, like WSL, SSH or other. This means, the system should be able to support
a loading state, some form of streaming, maybe local cache for large files, some metadata gathering and most importantly, a namespace system.

### Namespace System
The editor needs to be able to handle files from multiple sources at the **same** time. For example, it should be able to load the config file from windows
while still connected to a WSL project. This boils down to a key to implementation+mount point. So the current project is one of those mount points. The local system is one, WSL is one and so on.

## General

- [ ] Maybe figure out some sort of panel system.
- [ ] Text buffer datastructure (Keywords: Piece Table, Piece Tree (see vscode), Ropes (probably not), Gap Buffer (probably not))
- [ ] Improve styles
- [ ] Figure out allocation story
- [ ] Figure out the extension/plugins system (Keywords: out-of-process, shared memory, ring buffers)
    - [ ] Maybe some metaprogramming could help when creating the API's
    - [ ] Maybe also just in-process dynamic libraries
    - [ ] WASM? Probably not, but would be easy to do better than Zed
    - [ ] Scripting Language, probably not...
        - [ ] Possibly Lua?
        - [ ] Possibly JavaScript? (hell no)
        - [ ] Possibly Python? (Nuh uh)
        - [ ] Some functional language (((((not t)))))
