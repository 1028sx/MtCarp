class_name PlayerState
extends Node

var player: CharacterBody2D
var state_machine

var state_name := "PlayerState"


func enter() -> void:
	pass

func exit() -> void:
	pass

func process_input(_event: InputEvent) -> void:
	pass

func process_physics(_delta: float) -> void:
	pass

func process_frame(_delta: float) -> void:
	pass

func get_transition() -> PlayerState:
	return null
