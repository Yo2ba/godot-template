class_name BinaryLoader
extends RefCounted

const MAGIC: PackedByteArray = [89, 79, 50] # YO2
const FORMAT_VERSION: int = 1
const HEADER_SIZE: int = 15
const MAX_PAYLOAD_SIZE: int = 268435456 # 256 MiB


static func load_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null:
		return _failure(FileAccess.get_open_error())

	if file.get_length() < HEADER_SIZE:
		file.close()
		return _failure(ERR_FILE_CORRUPT)

	var magic: PackedByteArray = file.get_buffer(4)
	if magic != MAGIC:
		file.close()
		return _failure(ERR_FILE_UNRECOGNIZED)

	var version: int = file.get_32()
	if version != FORMAT_VERSION:
		file.close()
		return _failure(ERR_FILE_UNRECOGNIZED)

	var payload_size: int = file.get_64()
	var remaining_size: int = file.get_length() - HEADER_SIZE

	if payload_size < 0 or payload_size > MAX_PAYLOAD_SIZE:
		file.close()
		return _failure(ERR_FILE_CORRUPT)

	if payload_size != remaining_size:
		file.close()
		return _failure(ERR_FILE_CORRUPT)

	var payload: PackedByteArray = file.get_buffer(payload_size)
	var read_error: Error = file.get_error()
	file.close()

	if read_error != OK:
		return _failure(read_error)

	var decoded: Variant = bytes_to_var(payload)

	if not decoded is Dictionary or not decoded.has("data"):
		return _failure(ERR_FILE_CORRUPT)

	return {
		"error": OK,
		"data": decoded["data"]
	}


static func _failure(error: Error) -> Dictionary:
	return {
		"error": error,
		"data": null
	}
