extends "res://tests/test_case.gd"

const UpdaterScript := preload("res://scripts/core/updater.gd")


func test_is_newer_compares_numerically() -> void:
	check(UpdaterScript.is_newer("0.2.0", "0.1.0"), "minor bump is newer")
	check(UpdaterScript.is_newer("0.10.0", "0.9.0"), "0.10.0 is newer than 0.9.0")
	check(UpdaterScript.is_newer("1.0.0", "0.99.99"), "major bump is newer")
	check(not UpdaterScript.is_newer("0.1.0", "0.1.0"), "same version is not newer")
	check(not UpdaterScript.is_newer("0.1.0", "0.2.0"), "older version is not newer")
	check(UpdaterScript.is_newer("0.1.1", "0.1"), "missing parts count as zero")
	check(not UpdaterScript.is_newer("0.1", "0.1.0"), "0.1 equals 0.1.0")
