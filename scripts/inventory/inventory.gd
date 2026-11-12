class_name Inventory
## Pure helpers for slot arrays. A slot is null or {"id": String, "n": int}.


static func make(size: int) -> Array:
	var slots := []
	slots.resize(size)
	return slots


## Adds n of id, filling existing stacks first. Returns how many did not fit.
static func add(slots: Array, id: String, n: int) -> int:
	var cap := ItemDB.stack(id)
	for s in slots:
		if n <= 0:
			break
		if s != null and s["id"] == id and int(s["n"]) < cap:
			var put := mini(n, cap - int(s["n"]))
			s["n"] = int(s["n"]) + put
			n -= put
	for i in slots.size():
		if n <= 0:
			break
		if slots[i] == null:
			var put := mini(n, cap)
			slots[i] = {"id": id, "n": put}
			n -= put
	return n


static func count(slots: Array, id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s["id"] == id:
			total += int(s["n"])
	return total


## Removes n of id if (and only if) that many are present.
static func remove(slots: Array, id: String, n: int) -> bool:
	if count(slots, id) < n:
		return false
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if n <= 0:
			break
		if s != null and s["id"] == id:
			var take := mini(n, int(s["n"]))
			s["n"] = int(s["n"]) - take
			n -= take
			if int(s["n"]) <= 0:
				slots[i] = null
	return true


static func has_all(slots: Array, needs: Dictionary) -> bool:
	for id in needs:
		if count(slots, id) < int(needs[id]):
			return false
	return true


## Moves or swaps two slots; merges when both hold the same item.
static func move(slots: Array, from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size():
		return
	var a = slots[from]
	var b = slots[to]
	if a == null:
		return
	if b != null and b["id"] == a["id"]:
		var cap := ItemDB.stack(a["id"])
		var put := mini(int(a["n"]), cap - int(b["n"]))
		b["n"] = int(b["n"]) + put
		a["n"] = int(a["n"]) - put
		if int(a["n"]) <= 0:
			slots[from] = null
		return
	slots[from] = b
	slots[to] = a


static func free_slots(slots: Array) -> int:
	var n := 0
	for s in slots:
		if s == null:
			n += 1
	return n
