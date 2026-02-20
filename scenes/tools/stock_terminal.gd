extends ToolWindow
## Stock Terminal — buy and sell NCORP, MERI, and SYND shares.

@onready var stock_rows:      VBoxContainer = $ContentArea/Margin/VBox/StockRows
@onready var portfolio_label: Label         = $ContentArea/Margin/VBox/PortfolioLabel

# Per-symbol refs built dynamically: _rows[symbol] = { price_lbl, change_lbl, held_lbl, qty_spin }
var _rows: Dictionary = {}
var _prev_prices: Dictionary = {}


func _ready() -> void:
	super._ready()
	EventBus.stock_price_changed.connect(_on_price_changed)
	EventBus.player_stats_changed.connect(_refresh_portfolio)
	_build_rows()
	_refresh_all()


# ── Row construction ───────────────────────────────────────────────────────────

func _build_rows() -> void:
	for sym: String in MarketManager.SYMBOLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var sym_lbl := _make_label(sym, Color(0.75, 0.92, 1.0))
		sym_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(sym_lbl)

		var price_lbl := _make_label("¥0", Color(0.0, 0.88, 1.0))
		price_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(price_lbl)

		var change_lbl := _make_label("—", Color(0.35, 0.35, 0.45))
		change_lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(change_lbl)

		var held_lbl := _make_label("0", Color(0.55, 0.65, 0.7))
		held_lbl.custom_minimum_size = Vector2(60, 0)
		row.add_child(held_lbl)

		var qty_spin := SpinBox.new()
		qty_spin.min_value = 1
		qty_spin.max_value = 9999
		qty_spin.value = 1
		qty_spin.custom_minimum_size = Vector2(80, 0)
		row.add_child(qty_spin)

		var buy_btn := Button.new()
		buy_btn.text = "BUY"
		buy_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		var captured_sym := sym
		buy_btn.pressed.connect(func() -> void:
			MarketManager.buy(captured_sym, int(qty_spin.value))
			_refresh_row(captured_sym)
		)
		row.add_child(buy_btn)

		var sell_btn := Button.new()
		sell_btn.text = "SELL"
		sell_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
		sell_btn.pressed.connect(func() -> void:
			MarketManager.sell(captured_sym, int(qty_spin.value))
			_refresh_row(captured_sym)
		)
		row.add_child(sell_btn)

		stock_rows.add_child(row)
		_rows[sym] = {
			"price_lbl": price_lbl,
			"change_lbl": change_lbl,
			"held_lbl": held_lbl,
		}
		_prev_prices[sym] = MarketManager.prices.get(sym, 0)


# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	for sym: String in MarketManager.SYMBOLS:
		_refresh_row(sym)
	_refresh_portfolio()


func _refresh_row(symbol: String) -> void:
	if not _rows.has(symbol):
		return
	var refs: Dictionary = _rows[symbol]
	var price: int = MarketManager.prices.get(symbol, 0)
	var held: int  = MarketManager.holdings.get(symbol, 0)
	var prev: int  = _prev_prices.get(symbol, price)

	(refs["price_lbl"] as Label).text = "¥%d" % price

	var delta: int = price - prev
	var change_lbl := refs["change_lbl"] as Label
	if delta > 0:
		change_lbl.text = "+%d" % delta
		change_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	elif delta < 0:
		change_lbl.text = "%d" % delta
		change_lbl.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
	else:
		change_lbl.text = "—"
		change_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))

	(refs["held_lbl"] as Label).text = str(held)


func _refresh_portfolio() -> void:
	var portfolio: int = MarketManager.portfolio_value()
	var credits: int   = GameManager.player_data.get("credits", 0)
	portfolio_label.text = "Portfolio: ¥%d   |   Credits: ¥%d" % [portfolio, credits]


func _on_price_changed(symbol: String, _price: int) -> void:
	if symbol.is_empty():
		_refresh_all()
		return
	_refresh_row(symbol)
	_prev_prices[symbol] = MarketManager.prices.get(symbol, 0)
	_refresh_portfolio()


func _make_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	return lbl
