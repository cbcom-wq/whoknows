extends GutTest

## Seats (docs/superpowers/specs/2026-10-09-ship-bridge-design.md §3.2-§3.3):
## what every seat shares, which one flies, and the job slot.

class RecordingJob extends SeatJob:
	var calls: Array[String] = []
	func sat(_avatar: Avatar) -> void:
		calls.append("sat")
	func stood(_avatar: Avatar) -> void:
		calls.append("stood")

func test_only_the_pilot_seat_flies():
	var pilot := PilotSeat.new()
	assert_true(pilot.flies)
	pilot.free()
	var chair := CaptainChair.new()
	var station := CrewStation.new()
	assert_false(chair.flies)
	assert_false(station.flies)
	for s in [chair, station]:
		s.free()

func test_every_seat_is_a_seat():
	for s: Node in [PilotSeat.new(), CaptainChair.new(), CrewStation.new()]:
		assert_true(s is Seat)
		s.free()

func test_the_stand_spots_are_shared():
	assert_eq(PilotSeat.STAND_SPOTS, Seat.STAND_SPOTS)
	assert_eq(Seat.STAND_SPOTS[0], Vector3(0, 0, 1.3))

func test_each_says_what_sitting_there_is():
	var seats: Array[Seat] = [PilotSeat.new(), CaptainChair.new(), CrewStation.new()]
	assert_eq(seats[0].prompt_text(), "Take the controls")
	assert_eq(seats[1].prompt_text(), "Take the captain's chair")
	assert_eq(seats[2].prompt_text(), "Sit at the station")
	for s in seats:
		s.free()

func test_a_built_seat_has_an_eye_a_box_and_its_cell():
	var s := Seat.build(CrewStation, Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)), Vector3i(4, 0, -2))
	add_child_autofree(s)
	assert_eq(s.cell, Vector3i(4, 0, -2))
	assert_almost_eq(s.position, Vector3(1, 2, 3), Vector3.ONE * 0.001)
	assert_not_null(s.eye)
	assert_almost_eq(s.eye.position, InteriorProps.SEATED_EYE, Vector3.ONE * 0.001)
	assert_eq(s.find_children("*", "CollisionShape3D", true, false).size(), 1)
	assert_eq(s.collision_layer, 2)
	assert_true(s.is_in_group("interactable"))

func test_a_job_hears_sitting_and_standing():
	var s := CrewStation.new()
	var job := RecordingJob.new()
	s.job = job
	s.sat(null)
	s.stood(null)
	assert_eq(job.calls, ["sat", "stood"] as Array[String])
	job.free()
	s.free()

func test_no_job_is_fine():
	var s := CaptainChair.new()
	s.sat(null)
	s.stood(null)
	assert_null(s.job)
	s.free()
