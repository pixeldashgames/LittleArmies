class_name OrderInterface extends Node

static var instance: OrderInterface = null

signal prompt_entered(target: String, prompt: String)
signal give_order_button_pressed
signal cancel_button_pressed

@export var targets_selector: OptionButton
@export var error_label: Label
@export var send_button: Button
@export var prompt_input: TextEdit

func _enter_tree():
    instance = self
    reset_prompt()

func hide_button():
    $StartOrderButton.visible = false

func show_button():
    $StartOrderButton.visible = true

func reset_prompt():
    error_label.visible = false
    $GiveOrderPrompt.visible = false
    send_button.disabled = false

func prompt_error(error_text: String):
    error_label.visible = true
    error_label.text = error_text
    send_button.disabled = false

func open_prompter(targets: Array):
    $GiveOrderPrompt.visible = true
    prompt_input.text = ""
    prompt_input.grab_focus()
    targets_selector.clear()
    for target in targets:
        targets_selector.add_item(target)
    targets_selector.selected = 0

func _on_start_order_button_button_down():
    give_order_button_pressed.emit()

func _on_cancel_button_button_down():
    cancel_button_pressed.emit()

func _on_send_button_button_down():
    send_button.disabled = true
    prompt_entered.emit(targets_selector.get_item_text(targets_selector.selected), prompt_input.text)
    