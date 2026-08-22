extends GutTest

func test_harness_runs():
	assert_true(true, "GUT harness executes")

func test_godot_version_is_4_5_or_later():
	var info := Engine.get_version_info()
	assert_true(
		info.major > 4 or (info.major == 4 and info.minor >= 5),
		"Expected Godot 4.5+, got %d.%d" % [info.major, info.minor]
	)
