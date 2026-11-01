class_name UI
## Tema e piccoli mattoni dell'interfaccia: pergamena, cornici di legno scuro e oro, come le carte del gioco.

const LEGNO := Color(0.13, 0.10, 0.07)
const LEGNO_CHIARO := Color(0.24, 0.18, 0.12)
const ORO := Color(0.86, 0.69, 0.36)
const ORO_SCURO := Color(0.58, 0.44, 0.20)
const PERGAMENA := Color(0.94, 0.89, 0.78)
const INCHIOSTRO := Color(0.20, 0.13, 0.08)
const CENERE := Color(0.80, 0.75, 0.66)
const VERDE := Color(0.45, 0.62, 0.32)
const ROSSO := Color(0.80, 0.16, 0.12)
const ROSSO_SCURO := Color(0.48, 0.08, 0.06)
const SPERANZA := Color(0.98, 0.82, 0.45)
const COLORI_ARMATE := {"gondor": Color(0.32, 0.62, 0.92), "rohirrim": Color(0.62, 0.42, 0.22),
	"elfi": Color(0.36, 0.78, 0.36), "nani": Color(0.62, 0.62, 0.62)}

static var font_titolo: Font
static var font_decorato: Font
static var font_testo: Font
static var font_grassetto: Font
static var font_corsivo: Font
static var _tex := {}


static func carica_font() -> void:
	if font_testo != null:
		return
	font_titolo = load("res://assets/fonts/Cinzel-Bold.ttf")
	font_decorato = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	font_testo = load("res://assets/fonts/Alegreya-Regular.ttf")
	font_grassetto = load("res://assets/fonts/Alegreya-Bold.ttf")
	font_corsivo = load("res://assets/fonts/Alegreya-Italic.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func carta_tex(id: int) -> Texture2D:
	return tex("res://assets/carte/%d.webp" % id)


static func pedina(nome: String) -> Texture2D:
	return tex("res://assets/pedine/%s.webp" % nome)


static func make_theme() -> Theme:
	carica_font()
	var t := Theme.new()
	t.default_font = font_testo
	t.default_font_size = 20
	t.set_color("font_color", "Label", PERGAMENA)
	t.set_color("default_color", "RichTextLabel", PERGAMENA)
	t.set_font("bold_font", "RichTextLabel", font_grassetto)
	t.set_font("italics_font", "RichTextLabel", font_corsivo)
	var n := _stile_bottone(Color(0.26, 0.19, 0.12), ORO_SCURO)
	var h := _stile_bottone(Color(0.36, 0.26, 0.15), ORO)
	var p := _stile_bottone(Color(0.46, 0.32, 0.14), ORO)
	var d := _stile_bottone(Color(0.18, 0.15, 0.12), Color(0.32, 0.27, 0.20))
	t.set_stylebox("normal", "Button", n)
	t.set_stylebox("hover", "Button", h)
	t.set_stylebox("pressed", "Button", p)
	t.set_stylebox("disabled", "Button", d)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PERGAMENA)
	t.set_color("font_hover_color", "Button", Color(1, 0.96, 0.86))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.56, 0.5))
	t.set_font("font", "Button", font_grassetto)
	t.set_font_size("font_size", "Button", 19)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.09, 0.07, 0.05, 0.92)
	le.border_color = ORO_SCURO
	le.set_border_width_all(2)
	le.set_corner_radius_all(4)
	le.content_margin_left = 10
	le.content_margin_right = 10
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", PERGAMENA)
	t.set_stylebox("normal", "OptionButton", n)
	t.set_stylebox("hover", "OptionButton", h)
	t.set_stylebox("pressed", "OptionButton", p)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", PERGAMENA)
	t.set_font("font", "OptionButton", font_grassetto)
	var pm := StyleBoxFlat.new()
	pm.bg_color = Color(0.16, 0.12, 0.08)
	pm.border_color = ORO_SCURO
	pm.set_border_width_all(2)
	pm.set_corner_radius_all(4)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", PERGAMENA)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font("font", "PopupMenu", font_testo)
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_color("font_color", "CheckBox", PERGAMENA)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", PERGAMENA)
	t.set_font("font", "CheckBox", font_testo)
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	var tt := StyleBoxFlat.new()
	tt.bg_color = Color(0.09, 0.07, 0.05, 0.97)
	tt.border_color = ORO
	tt.set_border_width_all(2)
	tt.set_corner_radius_all(3)
	tt.content_margin_left = 10
	tt.content_margin_right = 10
	tt.content_margin_top = 6
	tt.content_margin_bottom = 6
	t.set_stylebox("panel", "TooltipPanel", tt)
	t.set_color("font_color", "TooltipLabel", PERGAMENA)
	t.set_font("font", "TooltipLabel", font_testo)
	t.set_font_size("font_size", "TooltipLabel", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.69, 0.36, 0.55)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.2)
	sbg.set_corner_radius_all(3)
	sbg.content_margin_left = 4
	sbg.content_margin_right = 4
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", cls, sb)
		t.set_stylebox("grabber_highlight", cls, sb)
		t.set_stylebox("grabber_pressed", cls, sb)
		t.set_stylebox("scroll", cls, sbg)
	return t


static func _stile_bottone(bg: Color, bordo: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 7
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	return s


## Pannello scuro con doppia cornice dorata (come i bordi delle carte).
static func pannello(colore := Color(0.11, 0.09, 0.06, 0.94), bordo := ORO_SCURO) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = colore
	s.border_color = bordo
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 7
	p.add_theme_stylebox_override("panel", s)
	return p


## Pannello chiaro di pergamena (testi da leggere).
static func pergamena() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxTexture.new()
	s.texture = tex("res://assets/ui/pergamena.webp")
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", s)
	return p


static func titolo(testo: String, size := 36, col := ORO) -> Label:
	carica_font()
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", font_titolo)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func etichetta(testo: String, size := 20, col := PERGAMENA, grassetto := false) -> Label:
	carica_font()
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if grassetto:
		l.add_theme_font_override("font", font_grassetto)
	return l


static func testo_lungo(testo: String, size := 18, col := PERGAMENA) -> Label:
	var l := etichetta(testo, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func immagine(t: Texture2D, w: float, h: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func bottone(testo: String, size := 19) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", size)
	return b


## Contatore con icona: [icona] n
static func contatore(t: Texture2D, n: int, size := 22, tip := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.add_child(immagine(t, size * 1.3, size * 1.3))
	h.add_child(etichetta(str(n), size, PERGAMENA, true))
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h
