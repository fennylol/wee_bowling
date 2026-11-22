extends Trigger
class_name KillTrigger

enum KillMasks {BALL=1, PIN=2}
@export_flags("BALL", "PIN") var KillMask: int = 3

func _on_ball_entered(ball: Ball) -> void:
   if KillMask & KillMasks.BALL:
      ball.try_clear()

func _on_pin_entered(pin: Pin) -> void:
   if KillMask & KillMasks.PIN:
      pin.try_clear()
