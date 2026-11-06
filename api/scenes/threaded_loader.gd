class_name ThreadedLoader

@warning_ignore_start("shadowed_global_identifier")
@warning_ignore_start("shadowed_variable_base_class")

static var active_load_requests: Dictionary = {}


static func _process(_delta: float = 0.0) -> void:
	if active_load_requests.is_empty():
		_set_polling(false)
		return

	var completed_resource_paths: Array[String] = []

	for resource_path in active_load_requests.keys():
		var progress_status_array: Array = []
		var current_load_status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(resource_path, progress_status_array)

		match current_load_status:
			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
				var progress_percentage: float = progress_status_array[0] as float if progress_status_array else 0.0
				for callback_function: Callable in active_load_requests[resource_path].progress_callbacks:
					if callback_function.is_valid():
						callback_function.call(progress_percentage)

			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
				var final_resource: Resource = ResourceLoader.load_threaded_get(resource_path)

				for callback_function: Callable in active_load_requests[resource_path].progress_callbacks:
					if callback_function.is_valid():
						callback_function.call(1.0)

				for callback_function: Callable in active_load_requests[resource_path].completion_callbacks:
					if callback_function.is_valid():
						callback_function.call(final_resource)
				completed_resource_paths.append(resource_path)

			ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED, ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
				printerr("ThreadedLoader: Failed to load: ", resource_path)
				for callback_function: Callable in active_load_requests[resource_path].completion_callbacks:
					if callback_function.is_valid():
						callback_function.call(null)
				completed_resource_paths.append(resource_path)

	for resource_path in completed_resource_paths:
		active_load_requests.erase(resource_path)

	if active_load_requests.is_empty():
		_set_polling(false)


static func load_async(resource_path: String, on_load_finished: Callable, on_progress_updated: Callable = Callable()) -> void:
	if ResourceLoader.has_cached(resource_path):
		on_load_finished.call(ResourceLoader.load(resource_path))
		return

	if not active_load_requests.has(resource_path):
		var error_code: Error = ResourceLoader.load_threaded_request(resource_path, "", true)
		if error_code != OK:
			printerr("ThreadedLoader: Thread request error for: ", resource_path)
			on_load_finished.call(null)
			return

		active_load_requests[resource_path] = {
			"completion_callbacks": [],
			"progress_callbacks": []
		}

	active_load_requests[resource_path].completion_callbacks.append(on_load_finished)
	if on_progress_updated.is_valid():
		active_load_requests[resource_path].progress_callbacks.append(on_progress_updated)

	_set_polling(true)


static func _set_polling(enabled: bool) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	
	var is_connected: bool = tree.process_frame.is_connected(_process)
	if enabled and not is_connected:
		tree.process_frame.connect(_process)
	elif not enabled and is_connected:
		tree.process_frame.disconnect(_process)
