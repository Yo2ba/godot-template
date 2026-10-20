class_name BinarySaver
extends RefCounted

const MAGIC: PackedByteArray = [89, 79, 50] # YO2
const FORMAT_VERSION: int = 1
const HEADER_SIZE: int = 15


static func save_file(path: String, data: Variant) -> Error:
	var payload: PackedByteArray = var_to_bytes({"data": data})

	var directory: String = path.get_base_dir()
	var absolute_directory: String = ProjectSettings.globalize_path(directory)

	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		return error

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_buffer(MAGIC)
	file.store_32(FORMAT_VERSION)
	file.store_64(payload.size())
	file.store_buffer(payload)
	file.flush()

	error = file.get_error()
	file.close()

	return error
