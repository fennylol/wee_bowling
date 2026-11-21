extends Label3D
class_name Message

var _MaxTravelTime: float
var _MaxHoverTime : float
var _StartPos     : Vector3
var _TargetPos    : Vector3
var _Lifetime     : float   = 0
var _Traveling    : bool    = true

func _init(message: String, text_size: float, color: Color, outline_color: Color, traveltime: float = 2.0, hovertime: float = 1.0, start_pos: Vector3 = Vector3(0,0,0), target_pos: Vector3 = Vector3(0,1,0)) -> void:
   _MaxTravelTime = traveltime
   _MaxHoverTime  = hovertime
   _StartPos      = start_pos
   _TargetPos     = target_pos
   
   fixed_size = true
   pixel_size = text_size/100
   text = message
   modulate = color
   outline_modulate = outline_color
   billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _process(delta: float) -> void:
   _Lifetime += delta
   
   if _Traveling:
      var progress: float = inverse_lerp(0.0, _MaxTravelTime, _Lifetime)
      position = lerp(_StartPos, _TargetPos, ease(progress, 0.2))
      _Traveling = _Lifetime <= _MaxTravelTime
   else:
      var progress: float = inverse_lerp(0.0, _MaxHoverTime, _Lifetime-_MaxTravelTime)
      modulate.a = lerp(1.0, 0.0, progress)
      outline_modulate.a = lerp(1.0, 0.0, progress)
      if _Lifetime >= _MaxHoverTime+_MaxTravelTime: queue_free()
   
