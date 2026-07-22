# Todos

## UI

The UI still needs a lot of work.

- [ ] Manual hash map: Move from map[string]... -> some custom implementation using a u64 as a key
    - [ ] Find a good hash function for small strings
    - [ ] Support `##` and `###` in the strings provided for hashing.
    - [ ] Only have one hash map and use the `Box.last_frame` as the indicator for wether we should free it or not
- [ ] More rect settings
    - [ ] Border
    - [ ] Border Color
    - [ ] Font
    - [ ] Font Size
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
