@tool
extends Control

var output_label
var ask_button
var input_field
var api_key_field
var provider_option
var http_request

const SAVE_PATH = "user://sceneai_config.cfg"

const PROVIDERS = {
	"Groq (безкоштовно)": {
		"url": "https://api.groq.com/openai/v1/chat/completions",
		"model": "llama-3.1-8b-instant"
	},
	"Google Gemini": {
		"url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=",
		"model": "gemini-2.0-flash"
	},
	"Anthropic Claude": {
		"url": "https://api.anthropic.com/v1/messages",
		"model": "claude-3-haiku-20240307"
	},
	"OpenAI GPT-4o mini": {
		"url": "https://api.openai.com/v1/chat/completions",
		"model": "gpt-4o-mini"
	},
	"OpenRouter (100+ моделей)": {
		"url": "https://openrouter.ai/api/v1/chat/completions",
		"model": "meta-llama/llama-3.2-3b-instruct:free"
	},
	"Mistral AI": {
		"url": "https://api.mistral.ai/v1/chat/completions",
		"model": "mistral-small-latest"
	},
	"Cohere": {
		"url": "https://api.cohere.ai/v1/chat",
		"model": "command-r"
	}
}

func _ready():
	setup_ui()
	setup_http()
	load_config()

func setup_ui():
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	var title = Label.new()
	title.text = "SceneAI Assistant"
	vbox.add_child(title)
	
	var provider_label = Label.new()
	provider_label.text = "AI Provider:"
	vbox.add_child(provider_label)
	
	provider_option = OptionButton.new()
	for provider_name in PROVIDERS.keys():
		provider_option.add_item(provider_name)
	provider_option.item_selected.connect(_on_provider_changed)
	vbox.add_child(provider_option)
	
	var key_label = Label.new()
	key_label.text = "API Key:"
	vbox.add_child(key_label)
	
	api_key_field = LineEdit.new()
	api_key_field.placeholder_text = "Встав свій API ключ..."
	api_key_field.secret = true
	api_key_field.text_changed.connect(_on_key_changed)
	vbox.add_child(api_key_field)
	
	var save_hint = Label.new()
	save_hint.text = "✓ Ключ зберігається автоматично"
	save_hint.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	vbox.add_child(save_hint)
	
	var question_label = Label.new()
	question_label.text = "Питання:"
	vbox.add_child(question_label)
	
	input_field = TextEdit.new()
	input_field.placeholder_text = "Опиши проблему або помилку..."
	input_field.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(input_field)
	
	ask_button = Button.new()
	ask_button.text = "🔍 Ask AI з контекстом сцени"
	ask_button.pressed.connect(_on_ask_pressed)
	vbox.add_child(ask_button)
	
	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.custom_minimum_size = Vector2(0, 200)
	output_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(output_label)

func setup_http():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_response)

func save_config():
	var config = ConfigFile.new()
	config.set_value("settings", "api_key", api_key_field.text)
	config.set_value("settings", "provider", provider_option.selected)
	config.save(SAVE_PATH)

func load_config():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		api_key_field.text = config.get_value("settings", "api_key", "")
		provider_option.selected = config.get_value("settings", "provider", 0)

func _on_key_changed(_new_text):
	save_config()

func _on_provider_changed(_index):
	save_config()

func get_scene_context() -> String:
	var context = ""
	var edited_scene = EditorInterface.get_edited_scene_root()
	if edited_scene:
		context += "ПОТОЧНА СЦЕНА: " + edited_scene.name + "\n"
		context += "НОДИ:\n"
		context += get_node_tree(edited_scene, 0)
	else:
		context += "СЦЕНА: не відкрита\n"
	return context

func get_node_tree(node: Node, depth: int) -> String:
	var result = ""
	var indent = "  ".repeat(depth)
	result += indent + "- " + node.name + " (" + node.get_class() + ")\n"
	for child in node.get_children():
		result += get_node_tree(child, depth + 1)
	return result

func _on_ask_pressed():
	var question = input_field.text.strip_edges()
	var api_key = api_key_field.text.strip_edges()
	
	if question.is_empty():
		output_label.text = "[color=red]Опиши проблему![/color]"
		return
	
	if api_key.is_empty():
		output_label.text = "[color=red]Встав API ключ![/color]"
		return
	
	output_label.text = "[color=yellow]Аналізую твою сцену...[/color]"
	ask_button.disabled = true
	
	var provider_name = provider_option.get_item_text(provider_option.selected)
	var provider = PROVIDERS[provider_name]
	var scene_context = get_scene_context()
	
	var full_prompt = "Ти senior Godot 4 розробник. Відповідай коротко українською.\n\nКОНТЕКСТ СЦЕНИ:\n" + scene_context + "\nПИТАННЯ: " + question
	
	var body = JSON.stringify({
		"model": provider["model"],
		"messages": [{
			"role": "user",
			"content": full_prompt
		}]
	})
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	http_request.request(provider["url"], headers, HTTPClient.METHOD_POST, body)

func _on_response(result, response_code, headers, body):
	ask_button.disabled = false
	
	if response_code != 200:
		output_label.text = "[color=red]Помилка: " + str(response_code) + "[/color]"
		return
	
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	var text = response["choices"][0]["message"]["content"]
	output_label.text = text
