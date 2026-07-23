# Todos

## UI

The UI still needs a lot of work.

- [x] Manual hash map: Move from map[string]... -> some custom implementation using a u64 as a key
    - [x] Find a good hash function for small strings
    - [x] Support `##` and `###` in the strings provided for hashing.
    - [x] Only have one hash map and use the `Box.last_frame` as the indicator for wether we should free it or not
- [x] More rect settings
    - [x] Border
    - [x] Border Color
    - [x] Font
            "working_dir": "$project_path"
    - [x] Font Size
- [ ] Scrollable areas
- [ ] Polish
- [ ] More default widgets
    - [ ] Well working text editing widget, think about BiDi and such.

## Font

Quite nice already, works for my use case.

- [ ] Figure out why so unclear
- [ ] Rename ID -> Key/Handle

## Window

Needs a general refactor for multiple, nice to have, features.

- [ ] Refactor window creation out and make it reusable, also track all created windows.
    - [ ] Has to support multiple EGL contextes
    - [ ] Support popups for stuff like hover text and so on, maybe, not sure yet.
    - [ ] Also support real popups
- [ ] Windows support, needs to be done before shipping anything
- [ ] A bit of cleanup would never hurt

## Render

Currently works well enough.

- [ ] Figure out why text unclear -> Font#1
- [ ] Support multiple OpenGL contextes

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
