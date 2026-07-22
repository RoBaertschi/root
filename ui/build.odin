package oui

button :: proc(name: string, c: ^Context) -> Signal {
	button := box_make(
		{ .Draw_Background, .Clickable, .Draw_Hover, .Draw_Active, .Draw_Text },
		name,
		c
	)

	return signal_from_box(button, c)
}
