extends GutTest

## When anything last took damage (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §10): a save waits CALM after it.

func test_calm_from_the_start():
	var log := DamageLog.new()
	assert_eq(log.busy(), "")

func test_busy_for_calm_after_a_note():
	var log := DamageLog.new()
	log.note()
	assert_eq(log.busy(), "took damage")
	log.tick(DamageLog.CALM - 0.1)
	assert_eq(log.busy(), "took damage")
	log.tick(0.2)
	assert_eq(log.busy(), "")

func test_a_new_note_restarts_the_calm():
	var log := DamageLog.new()
	log.note()
	log.tick(4.0)
	log.note()
	log.tick(4.0)
	assert_eq(log.busy(), "took damage")
