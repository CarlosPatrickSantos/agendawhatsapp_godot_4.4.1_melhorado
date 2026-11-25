extends Control

const SAVE_PATH := "user://agenda_clientes.json"
const LICENSE_PATH := "user://licenca.json"
const FIRESTORE_BASE_URL := "https://firestore.googleapis.com/v1/projects/agendawhatsapp-d7d0f/databases/(default)/documents/licencas/"

@onready var http_request: HTTPRequest = $HTTPRequest


var clientes: Array[Dictionary] = []

var nome_input: LineEdit
var whatsapp_input: LineEdit
var data_input: LineEdit
var form_fields: Array[Control] = []
var form_host: VBoxContainer
var form_container: VBoxContainer
var lista_container: VBoxContainer
var lista_scroll: ScrollContainer
var status_label: Label

var auth_overlay: ColorRect
var codigo_input: LineEdit
var senha_input: LineEdit
var auth_status_label: Label
var auth_btn: Button
var _codigo_pendente: String = ""
var _senha_pendente: String = ""

func _ready() -> void:
	_load_data()
	_ordenar_clientes()
	_build_interface()
	_refresh_list()
	_verificar_licenca_inicial()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#f2f5f3")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	

	var content_root := VBoxContainer.new()
	content_root.add_theme_constant_override("separation", 16)
	margin.add_child(content_root)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	content_root.add_child(header)

	var title := Label.new()
	title.text = "AgendaWhatsApp"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#153d2b"))
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Cadastre seus clientes e envie lembretes pelo WhatsApp."
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#52645a"))
	header.add_child(subtitle)


	var exit_button := Button.new()
	exit_button.text = "Sair do app"
	exit_button.custom_minimum_size = Vector2(0, 46)
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_button.add_theme_font_size_override("font_size", 19)
	exit_button.add_theme_color_override("font_color", Color.WHITE)
	exit_button.add_theme_stylebox_override("normal", _button_style(Color("#475569")))
	exit_button.add_theme_stylebox_override("hover", _button_style(Color("#334155")))
	exit_button.add_theme_stylebox_override("pressed", _button_style(Color("#1e293b")))
	exit_button.pressed.connect(_on_sair_app_pressed)
	header.add_child(exit_button)
	
	
	var form_panel := PanelContainer.new()
	form_panel.add_theme_stylebox_override("panel", _panel_style(Color.WHITE))
	content_root.add_child(form_panel)

	var form_margin := MarginContainer.new()
	form_margin.add_theme_constant_override("margin_left", 16)
	form_margin.add_theme_constant_override("margin_right", 16)
	form_margin.add_theme_constant_override("margin_top", 16)
	form_margin.add_theme_constant_override("margin_bottom", 16)
	form_panel.add_child(form_margin)

	var form_box := VBoxContainer.new()
	form_box.add_theme_constant_override("separation", 12)
	form_margin.add_child(form_box)

	var form_title := Label.new()
	form_title.text = "Novo agendamento"
	form_title.add_theme_font_size_override("font_size", 27)
	form_title.add_theme_color_override("font_color", Color("#153d2b"))
	form_box.add_child(form_title)

	form_host = VBoxContainer.new()
	form_host.add_theme_constant_override("separation", 11)
	form_box.add_child(form_host)

	nome_input = _make_input("Digite o nome do cliente")
	whatsapp_input = _make_input("DDD + número (ex.: 48 99162-0710)")
	data_input = _make_input("Ex.: 24/11/2026 às 10h ou 09:30h")
	form_fields = [
		_make_labeled_field("Nome", nome_input),
		_make_labeled_field("WhatsApp", whatsapp_input),
		_make_labeled_field("Data e horário", data_input)
	]
	for field in form_fields:
		form_host.add_child(field)

	var add_button := Button.new()
	add_button.text = "+  ADICIONAR AGENDAMENTO"
	add_button.custom_minimum_size = Vector2(0, 68)
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.add_theme_font_size_override("font_size", 23)
	add_button.add_theme_color_override("font_color", Color.WHITE)
	add_button.add_theme_stylebox_override("normal", _button_style(Color("#16834b")))
	add_button.add_theme_stylebox_override("hover", _button_style(Color("#116b3d")))
	add_button.add_theme_stylebox_override("pressed", _button_style(Color("#0d5832")))
	add_button.pressed.connect(_on_add_pressed)
	form_box.add_child(add_button)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#52645a"))
	form_box.add_child(status_label)

	var list_header := HBoxContainer.new()
	list_header.add_theme_constant_override("separation", 8)
	content_root.add_child(list_header)

	var list_title := Label.new()
	list_title.text = "Agendamento (por data e horário)"
	list_title.add_theme_font_size_override("font_size", 25)
	list_title.add_theme_color_override("font_color", Color("#153d2b"))
	list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(list_title)

	var list_count := Label.new()
	list_count.name = "Contador"
	list_count.text = "0 clientes"
	list_count.add_theme_font_size_override("font_size", 19)
	list_count.add_theme_color_override("font_color", Color("#52645a"))
	list_header.add_child(list_count)

	lista_scroll = ScrollContainer.new()
	lista_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(lista_scroll)
	# Aumentar a largura da barra vertical para facilitar o toque
	var barra_vertical := lista_scroll.get_v_scroll_bar()
	barra_vertical.custom_minimum_size.x = 40

	lista_container = VBoxContainer.new()
	lista_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_container.add_theme_constant_override("separation", 11)
	lista_scroll.add_child(lista_container)


func _make_input(placeholder_text: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder_text
	field.clear_button_enabled = true
	field.custom_minimum_size = Vector2(0, 62)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 36)
	field.add_theme_color_override("font_color", Color("#20352a"))
	field.add_theme_color_override("font_placeholder_color", Color("#87958d"))
	return field


func _make_labeled_field(caption: String, input: LineEdit) -> VBoxContainer:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 5)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color("#52645a"))
	field.add_child(label)
	field.add_child(input)
	return field


func _on_add_pressed() -> void:
	var nome := nome_input.text.strip_edges()
	var telefone := _normalizar_telefone(whatsapp_input.text)
	var data_hora := data_input.text.strip_edges()

	if nome.is_empty():
		_set_status("Informe o nome do cliente.")
		nome_input.grab_focus()
		return
	if telefone.is_empty():
		_set_status("Informe um WhatsApp válido com DDD (10 ou 11 dígitos).")
		whatsapp_input.grab_focus()
		return
	if _chave_data_hora(data_hora) == 999999999999:
		_set_status("Data/hora inválida. Use DD/MM/AAAA às HHh ou HH:MMh.")
		data_input.grab_focus()
		return

	clientes.append({"nome": nome, "whatsapp": telefone, "data_hora": data_hora})
	_ordenar_clientes()
	_save_data()
	_refresh_list()
	nome_input.clear()
	whatsapp_input.clear()
	data_input.clear()
	_set_status("Agendamento adicionado e organizado por data e horário.")
	nome_input.grab_focus()


func _normalizar_telefone(valor: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^0-9]")
	var digits := regex.sub(valor, "", true)
	if digits.begins_with("55") and (digits.length() == 12 or digits.length() == 13):
		digits = digits.substr(2)
	if digits.length() != 10 and digits.length() != 11:
		return ""
	return "55" + digits


func _chave_data_hora(valor: String) -> int:
	# Aceita, por exemplo: 24/11/2026 às 10h, 24/11/2026 as 10h,
	# 26/11/2026 09:30h ou 26/11/2026 às 09:30.
	var regex := RegEx.new()
	regex.compile("^(\\d{1,2})/(\\d{1,2})/(\\d{4})\\D+(\\d{1,2})(?::(\\d{2}))?\\s*h?\\s*$")
	var result := regex.search(valor.to_lower())
	if result == null:
		return 999999999999

	var dia := int(result.get_string(1))
	var mes := int(result.get_string(2))
	var ano := int(result.get_string(3))
	var hora := int(result.get_string(4))
	var minuto := 0
	if result.get_string(5) != "":
		minuto = int(result.get_string(5))

	if mes < 1 or mes > 12 or dia < 1 or dia > 31 or hora < 0 or hora > 23 or minuto < 0 or minuto > 59:
		return 999999999999
	var dias_por_mes := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var bissexto := (ano % 4 == 0 and ano % 100 != 0) or ano % 400 == 0
	if bissexto:
		dias_por_mes[1] = 29
	if dia > dias_por_mes[mes - 1]:
		return 999999999999
	return ano * 100000000 + mes * 1000000 + dia * 10000 + hora * 100 + minuto


func _ordenar_clientes() -> void:
	clientes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _chave_data_hora(str(a.get("data_hora", ""))) < _chave_data_hora(str(b.get("data_hora", "")))
	)


func _refresh_list() -> void:
	if lista_container == null:
		return
	for child in lista_container.get_children():
		child.queue_free()

	var count_label := find_child("Contador", true, false) as Label
	if count_label:
		count_label.text = "%d cliente(s)" % clientes.size()

	if clientes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nenhum agendamento cadastrado ainda."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 21)
		empty_label.add_theme_color_override("font_color", Color("#718078"))
		empty_label.custom_minimum_size = Vector2(0, 70)
		lista_container.add_child(empty_label)
		return

	for index in range(clientes.size()):
		_add_client_card(clientes[index], index)


func _add_client_card(cliente: Dictionary, index: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color.WHITE))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_container.add_child(card)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 15)
	padding.add_theme_constant_override("margin_right", 15)
	padding.add_theme_constant_override("margin_top", 13)
	padding.add_theme_constant_override("margin_bottom", 13)
	card.add_child(padding)

	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 10)
	padding.add_child(card_content)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	card_content.add_child(details)

	var name_label := Label.new()
	name_label.text = str(cliente.get("nome", "Sem nome"))
	name_label.add_theme_font_size_override("font_size", 35)
	name_label.add_theme_color_override("font_color", Color("#153d2b"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(name_label)

	var phone_label := Label.new()
	phone_label.text = "WhatsApp: %s" % str(cliente.get("whatsapp", ""))
	phone_label.add_theme_font_size_override("font_size", 30)
	phone_label.add_theme_color_override("font_color", Color("#52645a"))
	details.add_child(phone_label)

	var date_label := Label.new()
	date_label.text = "Agenda: %s" % str(cliente.get("data_hora", ""))
	date_label.add_theme_font_size_override("font_size", 38)
	date_label.add_theme_color_override("font_color", Color("#52645a"))
	date_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(date_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 9)
	card_content.add_child(actions)

	var send_button := Button.new()
	send_button.text = "Enviar WhatsApp"
	send_button.custom_minimum_size = Vector2(0, 75)
	send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_button.add_theme_font_size_override("font_size", 28)
	send_button.add_theme_color_override("font_color", Color.WHITE)
	send_button.add_theme_stylebox_override("normal", _button_style(Color("#16834b")))
	send_button.add_theme_stylebox_override("hover", _button_style(Color("#116b3d")))
	send_button.pressed.connect(_on_send_whatsapp.bind(index))
	actions.add_child(send_button)

	var delete_button := Button.new()
	delete_button.text = "X  Excluir"
	delete_button.custom_minimum_size = Vector2(0, 75)
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.add_theme_font_size_override("font_size", 28)
	delete_button.add_theme_color_override("font_color", Color("#a52a2a"))
	delete_button.add_theme_stylebox_override("normal", _button_style(Color("#fbecec")))
	delete_button.add_theme_stylebox_override("hover", _button_style(Color("#f4dada")))
	delete_button.pressed.connect(_on_delete_pressed.bind(index))
	actions.add_child(delete_button)


func _on_send_whatsapp(index: int) -> void:
	if index < 0 or index >= clientes.size():
		return
	var cliente: Dictionary = clientes[index]
	var telefone := _normalizar_telefone(str(cliente.get("whatsapp", "")))
	if telefone.is_empty():
		_set_status("O número deste cadastro não é válido.")
		return
	var mensagem := "Olá, %s! Lembrando do seu agendamento para %s." % [str(cliente.get("nome", "")), str(cliente.get("data_hora", ""))]
	var url := "https://wa.me/%s?text=%s" % [telefone, mensagem.uri_encode()]
	var error := OS.shell_open(url)
	if error != OK:
		_set_status("Não foi possível abrir o WhatsApp. Verifique se há um navegador instalado.")
	else:
		_set_status("Abrindo o WhatsApp...")


func _on_delete_pressed(index: int) -> void:
	if index < 0 or index >= clientes.size():
		return
	clientes.remove_at(index)
	_save_data()
	_refresh_list()
	_set_status("Agendamento excluído.")


func _save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_set_status("Erro ao salvar os dados.")
		return
	file.store_string(JSON.stringify(clientes, "\t"))
	file.close()


func _load_data() -> void:
	clientes = []
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				clientes.append({
					"nome": str(item.get("nome", "")),
					"whatsapp": str(item.get("whatsapp", "")),
					"data_hora": str(item.get("data_hora", ""))
				})


func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_color = Color("#dce6df")
	style.set_border_width_all(1)
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
	
	
func _verificar_licenca_inicial() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LICENSE_PATH))
	if not http_request.request_completed.is_connected(_on_firestore_request_completed):
		http_request.request_completed.connect(_on_firestore_request_completed)
	if _licenca_local_valida():
		return

	_mostrar_tela_login()


func _licenca_local_valida() -> bool:
	if not FileAccess.file_exists(LICENSE_PATH):
		return false

	var file := FileAccess.open(LICENSE_PATH, FileAccess.READ)
	if file == null:
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false

	var ativo: bool = bool(parsed.get("ativo", false))
	var expira_em: String = str(parsed.get("expira_em", "")).strip_edges()

	if not ativo:
		return false

	if expira_em == "":
		return true

	var hoje := Time.get_datetime_string_from_system(false).substr(0, 10)
	return hoje <= expira_em


func _mostrar_tela_login() -> void:
	if auth_overlay != null:
		auth_overlay.visible = true
		return

	auth_overlay = ColorRect.new()
	auth_overlay.color = Color(0.08, 0.14, 0.11, 0.88)
	auth_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	auth_overlay.z_index = 100
	add_child(auth_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	auth_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_stylebox_override("panel", _panel_style(Color.WHITE))
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "Ativar AgendaWhatsApp"
	lbl_titulo.add_theme_font_size_override("font_size", 36)
	lbl_titulo.add_theme_color_override("font_color", Color("#153d2b"))
	box.add_child(lbl_titulo)

	var lbl_desc := Label.new()
	lbl_desc.text = "Informe seu código de acesso e senha."
	lbl_desc.add_theme_font_size_override("font_size", 36)
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_color_override("font_color", Color("#52645a"))
	box.add_child(lbl_desc)

	codigo_input = LineEdit.new()
	codigo_input.placeholder_text = "Código (ex.: Nome )"
	codigo_input.custom_minimum_size = Vector2(0, 56)
	codigo_input.add_theme_font_size_override("font_size", 36)
	box.add_child(codigo_input)

	senha_input = LineEdit.new()
	senha_input.placeholder_text = "Senha"
	senha_input.secret = true
	senha_input.custom_minimum_size = Vector2(0, 56)
	senha_input.add_theme_font_size_override("font_size", 36)
	box.add_child(senha_input)

	auth_btn = Button.new()
	auth_btn.text = "Entrar"
	auth_btn.custom_minimum_size = Vector2(0, 62)
	auth_btn.add_theme_font_size_override("font_size", 36)
	auth_btn.add_theme_color_override("font_color", Color.WHITE)
	auth_btn.add_theme_stylebox_override("normal", _button_style(Color("#16834b")))
	auth_btn.add_theme_stylebox_override("hover", _button_style(Color("#116b3d")))
	auth_btn.add_theme_stylebox_override("pressed", _button_style(Color("#0d5832")))
	auth_btn.pressed.connect(_on_login_pressed)
	box.add_child(auth_btn)

	auth_status_label = Label.new()
	auth_status_label.text = ""
	auth_status_label.add_theme_font_size_override("font_size", 20)
	auth_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auth_status_label.add_theme_color_override("font_color", Color("#b42318"))
	box.add_child(auth_status_label)


func _on_login_pressed() -> void:
	var codigo := codigo_input.text.strip_edges()
	var senha := senha_input.text.strip_edges()

	if codigo == "" or senha == "":
		auth_status_label.text = "Preencha o código e a senha."
		return

	_codigo_pendente = codigo
	_senha_pendente = senha
	auth_btn.disabled = true
	auth_status_label.text = "Verificando licença..."

	var url := FIRESTORE_BASE_URL + codigo.uri_encode()
	var err := http_request.request(url)
	if err != OK:
		auth_btn.disabled = false
		auth_status_label.text = "Falha ao iniciar conexão com o servidor."


func _on_firestore_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	auth_btn.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		auth_status_label.text = "Código inválido ou sem conexão com a internet."
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not parsed.has("fields"):
		auth_status_label.text = "Resposta inválida do servidor."
		return

	var fields: Dictionary = parsed["fields"]
	var ativo := false
	if fields.has("ativo") and fields["ativo"] is Dictionary:
		ativo = bool(fields["ativo"].get("booleanValue", false))

	var senha_remota := ""
	if fields.has("senha") and fields["senha"] is Dictionary:
		senha_remota = str(fields["senha"].get("stringValue", ""))

	var expira_em := ""
	if fields.has("expira_em") and fields["expira_em"] is Dictionary:
		expira_em = str(fields["expira_em"].get("stringValue", "")).strip_edges()

	if not ativo:
		auth_status_label.text = "Esta licença está desativada."
		return

	if senha_remota != _senha_pendente:
		auth_status_label.text = "Senha incorreta."
		return

	if expira_em != "":
		var hoje := Time.get_datetime_string_from_system(false).substr(0, 10)
		if hoje > expira_em:
			auth_status_label.text = "Licença expirada em " + expira_em + "."
			return

	var dados_licenca := {
		"codigo": _codigo_pendente,
		"ativo": ativo,
		"expira_em": expira_em,
		"validado_em": Time.get_datetime_string_from_system(false)
	}

	var file := FileAccess.open(LICENSE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(dados_licenca, "\t"))
		file.close()

	auth_status_label.text = ""
	if auth_overlay != null:
		auth_overlay.visible = false
	
func _on_sair_app_pressed() -> void:
	get_tree().quit()
