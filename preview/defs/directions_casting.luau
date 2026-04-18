return {
	-- axis
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
    
	-- edges
	Vector3.new(1, 1, 0),
	Vector3.new(1, -1, 0),
	Vector3.new(-1, 1, 0),
	Vector3.new(-1, -1, 0),

	Vector3.new(1, 0, 1),
	Vector3.new(1, 0, -1),
	Vector3.new(-1, 0, 1),
	Vector3.new(-1, 0, -1),

	Vector3.new(0, 1, 1),
	Vector3.new(0, 1, -1),
	Vector3.new(0, -1, 1),
	Vector3.new(0, -1, -1),

	-- corners
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}