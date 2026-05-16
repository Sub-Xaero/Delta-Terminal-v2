class_name VoipTerminal
extends ToolWindow
## Standalone VOIP terminal. Dials phone numbers harvested from node files;
## successful calls deliver scrolling transcripts and may grant voice samples.
## Voice-cipher authentication is handled separately by Voice Comms.

const COL_CYAN  := Color(0.0,  0.88, 1.0)
const COL_AMBER := Color(1.0,  0.75, 0.0)
const COL_MUTED := Color(0.35, 0.35, 0.45)
const COL_LIGHT := Color(0.75, 0.92, 1.0)

# Static directory: number → { transcript, voice_sample_for_node }.
# Numbers should appear in node files (e.g. contacts.txt) so the player can
# discover them in-game.
const DIRECTORY: Dictionary = {
	"+1-555-0100": {
		"contact":  "GHOST_OPS",
		"transcript": "[connection negotiating...]\n\"Ghost. We've got eyes on a fresh contract. Check your inbox.\"\n[line ends]",
		"sample_for": "",
	},
	"+1-555-0142": {
		"contact":  "NC_RECRUITER",
		"transcript": "[ringing]\n\"NovaCorp HR — verification required. State your handle.\"\n[player remains silent]\n[call ends abruptly]",
		"sample_for": "novacorp_hq",
	},
	"+1-555-0177": {
		"contact":  "SYN_BROKER",
		"transcript": "[encrypted handshake]\n\"You move credits. We move them faster. We'll be in touch.\"\n[line drops]",
		"sample_for": "syn_underground_market",
	},
}

@onready var number_edit:    LineEdit      = $ContentArea/Margin/VBox/DialRow/NumberEdit
@onready var dial_btn:       Button        = $ContentArea/Margin/VBox/DialRow/DialBtn
@onready var transcript_box: RichTextLabel = $ContentArea/Margin/VBox/TranscriptScroll/Transcript
@onready var history_list:   VBoxContainer = $ContentArea/Margin/VBox/HistoryScroll/HistoryList

var _history: Array[Dictionary] = []  # { number, connected, contact }


func _ready() -> void:
	super._ready()
	dial_btn.pressed.connect(_on_dial)
	number_edit.text_submitted.connect(func(_t: String): _on_dial())
	_setup_theme()
	_render_history()


func _on_dial() -> void:
	var number: String = number_edit.text.strip_edges()
	if number.is_empty():
		return
	var entry: Dictionary = DIRECTORY.get(number, {})
	var connected: bool = not entry.is_empty()
	if connected:
		_play_transcript(entry["transcript"])
		var sample_for: String = entry.get("sample_for", "")
		if not sample_for.is_empty():
			VoiceManager.store_sample(sample_for, {
				"name": "voice_sample_%s.wav" % sample_for,
				"size": 1024,
				"type": "data",
				"source_call": number,
			})
		EventBus.log_message.emit("VOIP: connected to %s (%s)" % [number, entry.get("contact", "")], "info")
	else:
		_play_transcript("[line connecting...]\n[number unreachable — call dropped]")
		EventBus.log_message.emit("VOIP: %s — number unreachable." % number, "warn")
	_history.push_front({ "number": number, "connected": connected, "contact": entry.get("contact", "") })
	EventBus.voip_call_made.emit(number, connected)
	_render_history()


func _play_transcript(text: String) -> void:
	transcript_box.clear()
	transcript_box.append_text("[color=#00E1FF]%s[/color]" % text)


func _render_history() -> void:
	for child in history_list.get_children():
		child.queue_free()
	if _history.is_empty():
		var empty := Label.new()
		empty.text = "(no calls yet)"
		empty.add_theme_color_override("font_color", COL_MUTED)
		history_list.add_child(empty)
		return
	for item: Dictionary in _history:
		var lbl := Label.new()
		var status: String = "CONN" if item["connected"] else "FAIL"
		lbl.text = "%s  %s  %s" % [status, item["number"], item.get("contact", "")]
		lbl.add_theme_color_override("font_color",
			COL_CYAN if item["connected"] else Color(1.0, 0.08, 0.55))
		history_list.add_child(lbl)


func _setup_theme() -> void:
	dial_btn.add_theme_color_override("font_color", COL_AMBER)
