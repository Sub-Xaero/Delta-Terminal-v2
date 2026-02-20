extends Node
## Manages three tradeable stocks. Prices drift over time and react to in-game events.

const SYMBOLS: Array[String] = ["NCORP", "MERI", "SYND"]
const SYMBOL_FACTIONS: Dictionary = {
	"NCORP": "nova_corp",
	"MERI":  "meridian_gov",
	"SYND":  "syn_underground",
}
const TICK_INTERVAL := 30.0
const BASE_PRICES: Dictionary = { "NCORP": 150, "MERI": 80, "SYND": 60 }

var prices: Dictionary = {}    # symbol -> int
var holdings: Dictionary = {}  # symbol -> int (player's shares)
var _tick_timer: float = 0.0
var _price_history: Dictionary = {}  # symbol -> Array[int] last 10 ticks


func _ready() -> void:
	for sym: String in SYMBOLS:
		prices[sym]        = BASE_PRICES[sym]
		holdings[sym]      = 0
		_price_history[sym] = [BASE_PRICES[sym]]
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.credentials_stolen.connect(_on_credentials_stolen)
	EventBus.intrusion_logged.connect(_on_intrusion_logged)


func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer = 0.0
		_drift_prices()


# ── Public API ────────────────────────────────────────────────────────────────

func buy(symbol: String, quantity: int) -> bool:
	if quantity <= 0 or symbol not in prices:
		return false
	var cost: int = prices[symbol] * quantity
	if GameManager.player_data.get("credits", 0) < cost:
		EventBus.log_message.emit("Insufficient credits to buy %d %s." % [quantity, symbol], "error")
		return false
	GameManager.add_credits(-cost)
	holdings[symbol] = holdings.get(symbol, 0) + quantity
	EventBus.log_message.emit(
		"Bought %d %s @ ¥%d each  (¥%d total)" % [quantity, symbol, prices[symbol], cost], "info"
	)
	EventBus.player_stats_changed.emit()
	return true


func sell(symbol: String, quantity: int) -> bool:
	if quantity <= 0 or symbol not in prices:
		return false
	var held: int = holdings.get(symbol, 0)
	if held < quantity:
		EventBus.log_message.emit("You only hold %d shares of %s." % [held, symbol], "error")
		return false
	var proceeds: int = prices[symbol] * quantity
	holdings[symbol] = held - quantity
	GameManager.add_credits(proceeds)
	EventBus.log_message.emit(
		"Sold %d %s @ ¥%d each  (¥%d total)" % [quantity, symbol, prices[symbol], proceeds], "info"
	)
	EventBus.player_stats_changed.emit()
	return true


func portfolio_value() -> int:
	var total := 0
	for sym: String in SYMBOLS:
		total += prices.get(sym, 0) * holdings.get(sym, 0)
	return total


func get_save_data() -> Dictionary:
	return { "prices": prices.duplicate(), "holdings": holdings.duplicate() }


func load_save_data(data: Dictionary) -> void:
	for sym: String in SYMBOLS:
		if data.get("prices", {}).has(sym):
			prices[sym] = int(data["prices"][sym])
		if data.get("holdings", {}).has(sym):
			holdings[sym] = int(data["holdings"][sym])
	EventBus.stock_price_changed.emit("", 0)  # trigger UI refresh


# ── Price mechanics ────────────────────────────────────────────────────────────

func _drift_prices() -> void:
	for sym: String in SYMBOLS:
		var change_pct: float = randf_range(-0.03, 0.03)
		_apply_price_change(sym, change_pct)


func _apply_price_change(symbol: String, pct: float) -> void:
	var old_price: int = prices.get(symbol, 100)
	var new_price: int = maxi(1, roundi(float(old_price) * (1.0 + pct)))
	prices[symbol] = new_price
	var history: Array = _price_history.get(symbol, [])
	history.append(new_price)
	if history.size() > 10:
		history.pop_front()
	_price_history[symbol] = history
	EventBus.stock_price_changed.emit(symbol, new_price)


# ── EventBus reactions ────────────────────────────────────────────────────────

func _on_mission_completed(mission_id: String) -> void:
	var mission: MissionData = MissionManager.available_missions.get(mission_id)
	if not mission:
		return
	for sym: String in SYMBOL_FACTIONS:
		if SYMBOL_FACTIONS[sym] == mission.faction_id:
			_apply_price_change(sym, randf_range(0.03, 0.08))
			break


func _on_credentials_stolen(_node_id: String, _count: int) -> void:
	for sym: String in SYMBOLS:
		if randf() < 0.4:
			_apply_price_change(sym, randf_range(-0.05, -0.01))


func _on_intrusion_logged(_node_id: String) -> void:
	for sym: String in SYMBOLS:
		if randf() < 0.3:
			_apply_price_change(sym, randf_range(-0.03, -0.005))
