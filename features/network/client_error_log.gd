extends RefCounted
## Patch 4.0.5 item 2: the game server's log of client error and crash
## reports (dedicated_runtime.client_error_report). One JSON line per report
## in <folder>/client_errors.log; past MAX_FILE_BYTES it rotates to
## client_errors.1.log ... client_errors.<KEEP - 1>.log (the oldest is
## deleted). The packaged server's folder is C:\ShippingLanesServer\logs\
## client_errors (its saves are C:\ShippingLanesServer\saves).
## The server trusts nothing: only the known fields, as text, cut to size
## and scrubbed again (ErrorReports.scrub). It writes no peer, captain, key
## or address: only the time it arrived. Each captain is rate limited (a
## small burst, then one every REFILL_S, at most PER_PEER per connection),
## and the whole server writes at most PER_HOUR an hour.
const MAX_FILE_BYTES: int = 1048576
const KEEP: int = 5
const BURST: float = 5.0
const REFILL_S: float = 3.0
const PER_PEER: int = 30
const PER_HOUR: int = 600
## A report bigger than this (as sent) is refused whole.
const MAX_REPORT_BYTES: int = 8192
const FILE_NAME: String = "client_errors"
var folder: String = ""
## peer -> {"tokens", "at" (ms), "total"}
var buckets: Dictionary = {}
var hour_start_ms: int = -3600000
var hour_count: int = 0
var accepted: int = 0
var refused: int = 0
## Test clock (ms). Negative: the real clock.
var now_ms: int = -1

func clock() -> int:
	return now_ms if now_ms >= 0 else Time.get_ticks_msec()

## The folder beside the server's saves: <root>/saves -> <root>/logs/client_errors.
static func folder_for(saves_path: String) -> String:
	return saves_path.get_base_dir().path_join("logs").path_join("client_errors")

func forget(peer: int) -> void:
	buckets.erase(peer)

## Takes one report from `peer`. Returns "" when written, else why not.
func accept(peer: int, report: Variant) -> String:
	var why: String = admit(peer, report)
	if why.is_empty(): why = write(clean(report))
	if why.is_empty(): accepted += 1
	else: refused += 1
	return why

func admit(peer: int, report: Variant) -> String:
	if folder.is_empty(): return "no folder"
	if not report is Dictionary: return "not a report"
	if var_to_bytes(report).size() > MAX_REPORT_BYTES: return "too large"
	var now: int = clock()
	var bucket: Dictionary = buckets.get(peer, {"tokens": BURST, "at": now, "total": 0})
	bucket.tokens = minf(BURST, float(bucket.tokens) + float(now - int(bucket.at)) / 1000.0 / REFILL_S)
	bucket.at = now
	buckets[peer] = bucket
	if int(bucket.total) >= PER_PEER: return "peer limit"
	if float(bucket.tokens) < 1.0: return "rate limit"
	if now - hour_start_ms >= 3600000:
		hour_start_ms = now
		hour_count = 0
	if hour_count >= PER_HOUR: return "server limit"
	bucket.tokens = float(bucket.tokens) - 1.0
	bucket.total = int(bucket.total) + 1
	hour_count += 1
	return ""

## Only the known fields, each as capped, scrubbed text.
static func clean(report: Dictionary) -> Dictionary:
	var text: Callable = func(key: String, limit: int) -> String:
		var value: Variant = report.get(key, "")
		return ErrorReports.scrub(value if value is String else "", limit)
	var scene: String = text.call("scene", ErrorReports.SCENE_LIMIT)
	var count: Variant = report.get("count", 1)
	return {"time": Time.get_datetime_string_from_system(true) + "Z",
		"kind": "crash" if report.get("kind", "") == "crash" else "error",
		"version": text.call("version", 32), "os": text.call("os", 40),
		"scene": scene if scene.begins_with("res://") else "",
		"message": text.call("message", ErrorReports.MESSAGE_LIMIT),
		"location": text.call("location", ErrorReports.LOCATION_LIMIT),
		"stack": text.call("stack", ErrorReports.STACK_LIMIT),
		"count": clampi(int(count) if (count is int or count is float) else 1, 1, 1000000)}

func path(index: int = 0) -> String:
	return folder.path_join(FILE_NAME + (".log" if index == 0 else ".%d.log" % index))

func write(entry: Dictionary) -> String:
	if DirAccess.make_dir_recursive_absolute(folder) != OK and not DirAccess.dir_exists_absolute(folder): return "folder unavailable"
	var line: String = JSON.stringify(entry) + "\n"
	var current: String = path()
	if FileAccess.file_exists(current):
		var size: int = 0
		var reader: FileAccess = FileAccess.open(current, FileAccess.READ)
		if reader != null:
			size = reader.get_length()
			reader.close()
		if size + line.to_utf8_buffer().size() > MAX_FILE_BYTES: rotate()
	var file: FileAccess = FileAccess.open(current, FileAccess.READ_WRITE if FileAccess.file_exists(current) else FileAccess.WRITE)
	if file == null: return "file unavailable"
	file.seek_end()
	file.store_string(line)
	file.close()
	return ""

func rotate() -> void:
	if FileAccess.file_exists(path(KEEP - 1)): DirAccess.remove_absolute(path(KEEP - 1))
	for index: int in range(KEEP - 2, -1, -1):
		if FileAccess.file_exists(path(index)): DirAccess.rename_absolute(path(index), path(index + 1))
