extends SceneTree
## Plays whole runs through the real rules, headless, and writes what happened in each: one
## worker of the balance runs (tools/balance/delve.mjs starts as many as the machine has cores).
##
##   Godot --headless --path . --script tools/balance/delve.gd -- jobs=<jobs.json> out=<runs.jsonl> [pack=<content pack>]
##
## The jobs file is {"jobs": [job, ...]}; a job is
##
##   {id, character, birthstone ("" for the delver's first), mine, seed, hazard,
##    sockets (how many the delver has open), carat, cut, clarity (of the stones they bring),
##    vault (how many stones they choose from), opal_pct, plant_pct, rift_wardens,
##    plant: a skill set on the rail whatever else it holds,
##    kit: [[skill, carat, cut, clarity] | null, ...] (the whole rail by socket, nothing drawn)}
##
## and the bot (tools/balance/bot.gd) plays it. One line of JSON is written per run as it ends
## (`summary` there says what is in it), so a run that is stopped half way has lost nothing it
## finished. `@@ n/total` on the output is its progress.

const Bot: GDScript = preload("res://tools/balance/bot.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var at: int = arg.find("=")
		if at > 0:
			args[arg.substr(0, at)] = arg.substr(at + 1)
	var jobs_path: String = str(args.get("jobs", ""))
	var out_path: String = str(args.get("out", ""))
	if jobs_path.is_empty() or out_path.is_empty():
		printerr("usage: -- jobs=<jobs.json> out=<runs.jsonl> [pack=<content pack>]")
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(jobs_path))
	if not parsed is Dictionary or not parsed.get("jobs", null) is Array:
		printerr("no jobs in " + jobs_path)
		quit(2)
		return
	## A changed copy of the pack, to try a number before it is written into the game's.
	if args.has("pack"):
		DeepContent.use_path(str(args.pack))
	var out: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		printerr("cannot write " + out_path)
		quit(2)
		return
	var jobs: Array = parsed.jobs
	var failed: int = 0
	for index in range(jobs.size()):
		var job: Dictionary = jobs[index]
		var bot: RefCounted = Bot.new()
		var row: Dictionary = bot.play(job)
		if str(row.get("outcome", "")) in ["stuck", "limit"]:
			failed += 1
			printerr("!! %s %s: %s" % [str(job.get("id", "")), str(row.outcome), str(row.get("stuck", ""))])
		out.store_line(JSON.stringify(row))
		out.flush()
		print("@@ %d/%d" % [index + 1, jobs.size()])
	out.close()
	quit(0 if failed == 0 else 1)
