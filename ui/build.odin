package oui

button :: proc(name: string) -> Signal {
	button := box_make(
		{ .Draw_Background, .Clickable, .Draw_Hover, .Draw_Active, .Draw_Text },
		name
	)

	return signal_from_box(button)
}
