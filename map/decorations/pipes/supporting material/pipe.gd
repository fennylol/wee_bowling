extends Node3D
class_name Pipe

var _WindStrength: float = 25

func _apply_wind(windbox: Area3D, wind_direction: Vector3, delta: float) -> void:
   for body in windbox.get_overlapping_bodies():
      if body is Player or body is GameObject:
         _blow(body, basis * wind_direction * _WindStrength * delta)

func _blow(body: Node3D, force: Vector3) -> void:
   if body is Player:
      if body.velocity.length() < _WindStrength:
         body.velocity += force
   if body is GameObject:
      if body.linear_velocity.length() < _WindStrength:
         body.linear_velocity += force
