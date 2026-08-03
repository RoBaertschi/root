package root_base

import "base:builtin"

when ODIN_DISABLE_ASSERT {
	@require_results
	assert :: proc(condition: bool, message := #caller_expression(condition), loc := #caller_location) -> bool {
		return condition
	}
} else {
	@require_results
	assert :: proc(condition: bool, message := #caller_expression(condition), loc := #caller_location) -> bool {
		builtin.assert(condition, message, loc)
		return condition
	}
}
