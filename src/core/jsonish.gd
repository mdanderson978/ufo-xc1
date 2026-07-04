class_name Jsonish
extends RefCounted
## Canonical form for JSON-native game state: numbers that are whole are
## ints, everything else untouched. Applied when campaign state is created
## AND when it is loaded, so save round-trips are byte-identical.

static func normalised(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var as_int := int(value)
			return as_int if float(as_int) == value else value
		TYPE_DICTIONARY:
			var dict := {}
			for key: Variant in value:
				dict[key] = normalised(value[key])
			return dict
		TYPE_ARRAY:
			var list := []
			for element: Variant in value:
				list.append(normalised(element))
			return list
		_:
			return value
