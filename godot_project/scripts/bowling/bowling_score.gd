class_name BowlingScore
extends RefCounted
## Standard 10-pin scoring (strikes, spares, 10th-frame bonus balls).

var rolls: Array[int] = []


func reset() -> void:
	rolls.clear()


func add(pins: int) -> void:
	rolls.append(clampi(pins, 0, pins_standing()))


## Splits rolls into frames: Array of Array[int] (last one may be incomplete).
func frame_rolls() -> Array:
	var out: Array = []
	var i := 0
	for f in 10:
		if i >= rolls.size():
			break
		if f < 9:
			if rolls[i] == 10:
				out.append([10])
				i += 1
			elif i + 1 < rolls.size():
				out.append([rolls[i], rolls[i + 1]])
				i += 2
			else:
				out.append([rolls[i]])
				i += 1
		else:
			out.append(rolls.slice(i, mini(i + 3, rolls.size())))
			i = rolls.size()
	return out


func is_over() -> bool:
	var fr := frame_rolls()
	if fr.size() < 10:
		return false
	var t: Array = fr[9]
	if t.size() == 3:
		return true
	return t.size() == 2 and t[0] + t[1] < 10


## 0-based frame index of the next roll (9 at most).
func current_frame() -> int:
	var fr := frame_rolls()
	if fr.is_empty():
		return 0
	var last: Array = fr[fr.size() - 1]
	var idx := fr.size() - 1
	if idx < 9 and (last.size() == 2 or (last.size() == 1 and last[0] == 10)):
		return idx + 1
	return idx


## Which ball of the current frame comes next (0, 1 or 2).
func roll_in_frame() -> int:
	var fr := frame_rolls()
	var f := current_frame()
	if f >= fr.size():
		return 0
	return (fr[f] as Array).size()


## Pins that should be standing for the next roll.
func pins_standing() -> int:
	var fr := frame_rolls()
	var f := current_frame()
	if f >= fr.size():
		return 10
	var r: Array = fr[f]
	if f < 9:
		return 10 - r[0]
	match r.size():
		1:
			return 10 if r[0] == 10 else 10 - r[0]
		2:
			if r[0] == 10:
				return 10 if r[1] == 10 else 10 - r[1]
			return 10 if r[0] + r[1] == 10 else 0
	return 0


## Marks for display: Array (per frame) of Array[String].
func marks() -> Array:
	var out: Array = []
	var fr := frame_rolls()
	for f in fr.size():
		var r: Array = fr[f]
		var m: Array[String] = []
		if f < 9:
			if r[0] == 10:
				m.append("X")
			else:
				m.append(_d(r[0]))
				if r.size() > 1:
					m.append("/" if r[0] + r[1] == 10 else _d(r[1]))
		else:
			for k in r.size():
				var full_rack: bool = k == 0 or (k == 1 and r[0] == 10) or (k == 2 and (r[1] == 10 and r[0] == 10 or r[0] + r[1] == 10 and r[0] != 10))
				if full_rack:
					m.append("X" if r[k] == 10 else _d(r[k]))
				else:
					m.append("/" if r[k - 1] + r[k] == 10 else _d(r[k]))
		out.append(m)
	return out


## Running totals per frame; -1 where not yet known.
func totals() -> Array[int]:
	var out: Array[int] = []
	var sum := 0
	var i := 0
	var fr := frame_rolls()
	for f in fr.size():
		var r: Array = fr[f]
		var v := -1
		if f < 9:
			if r[0] == 10:
				if i + 2 < rolls.size():
					v = 10 + rolls[i + 1] + rolls[i + 2]
				i += 1
			elif r.size() == 2:
				if r[0] + r[1] == 10:
					if i + 2 < rolls.size():
						v = 10 + rolls[i + 2]
				else:
					v = r[0] + r[1]
				i += 2
			else:
				i += 1
		else:
			if is_over():
				v = 0
				for x in r:
					v += x
		if v < 0 or (out.size() > 0 and out[out.size() - 1] < 0):
			out.append(-1)
		else:
			sum += v
			out.append(sum)
	return out


func total() -> int:
	var t := totals()
	for k in range(t.size() - 1, -1, -1):
		if t[k] >= 0:
			return t[k]
	return 0


static func _d(n: int) -> String:
	return "-" if n == 0 else str(n)
