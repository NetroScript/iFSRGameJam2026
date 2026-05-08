@tool
class_name GStateSignalBinding
extends RefCounted

var _connected_signal_name: String = ""

func reconnect_property_changed(property_name: String, callback: Callable) -> bool:
	clear_binding(callback)

	var signal_name: String = property_name + "_changed"
	if not GState.has_signal(signal_name):
		return false

	var signal_reference: Signal = GState.get(signal_name) as Signal
	if not signal_reference.is_connected(callback):
		signal_reference.connect(callback)

	_connected_signal_name = signal_name
	return true

func clear_binding(callback: Callable) -> void:
	if _connected_signal_name == "":
		return

	if GState.has_signal(_connected_signal_name):
		var old_signal: Signal = GState.get(_connected_signal_name) as Signal
		if old_signal.is_connected(callback):
			old_signal.disconnect(callback)

	_connected_signal_name = ""
