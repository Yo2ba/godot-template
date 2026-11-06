@abstract
class_name HTTP

@warning_ignore_start("shadowed_global_identifier")
@warning_ignore_start("native_method_override")

class Response extends RefCounted:
	var ok: bool = false
	var code: int = 0
	var result: int = HTTPRequest.RESULT_CANT_CONNECT
	var headers: Dictionary = {}
	var text: String = ""
	var data: Variant = null
	var raw: PackedByteArray = []


class _SignalBus extends RefCounted:
	signal request_completed(response: Response)

static var _bus := _SignalBus.new()

static var request_completed: Signal:
	get:
		return _bus.request_completed

static var _container: Node
static var timeout: float = 10.0
static var base_url: String = ""
static var default_headers: Dictionary = {}


static func initialize(parent: Node) -> void:
	if is_instance_valid(_container):
		return

	_container = Node.new()
	_container.name = "HTTP"
	parent.add_child(_container)

	Console.log("[Framework] HTTP: Initialized", Color(0.0, 1.0, 1.0, 1.0))


static func fetch(
	url: String,
	headers: Variant = null,
	callback: Callable = Callable()
) -> Response:
	return await _send(url, HTTPClient.METHOD_GET, null, headers, callback)


static func post(
	url: String,
	payload: Variant = null,
	headers: Variant = null,
	callback: Callable = Callable()
) -> Response:
	return await _send(url, HTTPClient.METHOD_POST, payload, headers, callback)


static func _send(
	url: String,
	method: HTTPClient.Method,
	payload: Variant,
	headers: Variant,
	callback: Callable
) -> Response:
	var response := Response.new()

	if not is_instance_valid(_container):
		Console.log("[HTTP] Error: Framework not initialized.", Color.RED)
		return response

	var full_url: String = _resolve_url(url)
	var packed_headers: PackedStringArray = _build_headers(headers, payload)

	var http_req := HTTPRequest.new()
	http_req.timeout = timeout
	_container.add_child(http_req)

	var error: Error
	if payload is PackedByteArray:
		error = http_req.request_raw(full_url, packed_headers, method, payload)
	else:
		var body_str: String = _serialize_payload(payload)
		error = http_req.request(full_url, packed_headers, method, body_str)

	if error != OK:
		http_req.queue_free()
		Console.log(
			"[HTTP] Failed to start request to '%s': %s" % [full_url, error_string(error)],
			Color.RED
		)
		return response

	var raw_result: Array = await http_req.request_completed
	http_req.queue_free()

	response.result = raw_result[0]
	response.code = raw_result[1]
	response.headers = _parse_headers(raw_result[2])
	response.raw = raw_result[3]
	response.ok = response.result == HTTPRequest.RESULT_SUCCESS and response.code >= 200 and response.code < 300

	if not response.raw.is_empty():
		response.text = response.raw.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(response.text)
		response.data = parsed if parsed != null else response.text

	if not response.ok:
		Console.log(
			"[HTTP] Request failed (%d) [Result: %d]: %s\n%s" % [
				response.code,
				response.result,
				full_url.get_slice("?", 0),
				response.text
			],
			Color.YELLOW
		)

	if callback.is_valid():
		callback.call(response)

	request_completed.emit(response)
	return response


static func _resolve_url(url: String) -> String:
	if base_url.is_empty() or url.begins_with("http://") or url.begins_with("https://"):
		return url
	return base_url.trim_suffix("/") + "/" + url.trim_prefix("/")


static func _serialize_payload(payload: Variant) -> String:
	if payload == null:
		return ""
	if payload is String:
		return payload
	return JSON.stringify(payload)


static func _build_headers(custom_headers: Variant, payload: Variant) -> PackedStringArray:
	var merged: Dictionary = default_headers.duplicate()

	if payload is Dictionary or payload is Array:
		merged["Content-Type"] = "application/json"

	if custom_headers is Dictionary:
		for key: Variant in custom_headers:
			merged[str(key)] = str(custom_headers[key])

	var result := PackedStringArray()
	for key: String in merged:
		result.append("%s: %s" % [key, merged[key]])

	if custom_headers is Array or custom_headers is PackedStringArray:
		for item: Variant in custom_headers:
			result.append(str(item))

	return result


static func _parse_headers(raw_headers: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for header: String in raw_headers:
		var split_idx: int = header.find(":")
		if split_idx != -1:
			var key: String = header.substr(0, split_idx).strip_edges().to_lower()
			var val: String = header.substr(split_idx + 1).strip_edges()
			parsed[key] = val
	return parsed
