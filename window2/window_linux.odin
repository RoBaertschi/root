#+private
package root_window2

// #region Event

_Interaction_Key :: distinct u32

// #endregion

// #region Window

@(private="package")
_Window_Platform :: struct {}

_window_platform_init :: proc(w: ^Window) {
}

// #endregion

// #region State

_State_Platform :: struct {}

_state_platform_init :: proc(s: ^State) -> bool {
	

	return true
}

// #endregion
