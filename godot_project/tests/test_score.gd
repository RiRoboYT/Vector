extends SceneTree
func check(name, rolls, expect_total):
	var s = BowlingScore.new()
	for r in rolls: s.add(r)
	var ok = s.total() == expect_total and s.is_over()
	print("%s %s total=%d over=%s marks=%s" % ["PASS" if ok else "FAIL", name, s.total(), s.is_over(), s.marks()])
func _init():
	check("perfect", [10,10,10,10,10,10,10,10,10,10,10,10], 300)
	check("all 9-", [9,0,9,0,9,0,9,0,9,0,9,0,9,0,9,0,9,0,9,0], 90)
	check("all spares 5", [5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5], 150)
	check("gutter", [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], 0)
	check("mixed", [10,7,3,9,0,10,0,8,8,2,0,6,10,10,10,8,1], 167)
	check("10th X then 7/", [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,10,7,3], 20)
	var s = BowlingScore.new(); s.add(10); s.add(3)
	print("after X,3: frame=%d roll=%d standing=%d" % [s.current_frame(), s.roll_in_frame(), s.pins_standing()])
	quit()
