vec3 aabb[2](vec3 pos, vec3 dir, int ID) {

	vec3 mincoord[30] = vec3[30](
		vec3(0.0),//bottom slab
		vec3(0.0, 0.5, 0.0),//top slab
		vec3(0.0),//bottom trapdoor
		vec3(0.0, 0.8125, 0.0),//top trapdoor
		vec3(0.0),//south trapdoor
		vec3(0.0, 0.0, 0.8125),//north trapdoor
		vec3(0.8125, 0.0, 0.0),//west trapdoor
		vec3(0.0),//east trapdoor
		vec3(0.375, 0.0, 0.375),//fence
		vec3(0.25, 0.0, 0.25),//wall
		vec3(0.0),//bottom two pixels (snow layer etc)
		vec3(0.0),//bottom pixel(carpets etc)
		vec3(0.0625, 0.0, 0.0625),//pressure plates
		vec3(0.4375, 0.0, 0.4375),//torches
		vec3(0.3125, 0.0, 0.3125),//lantern and flowerpot
		vec3(0.4375, 0.0, 0.4375),//chain, iron bar, glass pane
		vec3(0.0),//path, farmland
		vec3(0.0625, 0.0, 0.0625),//cactus
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0),
		vec3(0.0)
	);
	vec3 maxcoord[30] = vec3[30](
		vec3(1.0, 0.5, 1.0),//bottom slab
		vec3(1.0),//top slab
		vec3(1.0, 0.1875, 1.0),//bottom trapdoor
		vec3(1.0),//top trapdoor
		vec3(1.0, 1.0, 0.1875),//south trapdoor
		vec3(1.0),//north trapdoor
		vec3(1.0),//west trapdoor
		vec3(0.1875, 1.0, 1.0),//east trapdoor
		vec3(0.625, 1.0, 0.625), //fence
		vec3(0.75, 1.0, 0.75),//wall
		vec3(1.0, 0.125, 1.0),//bottom two pixels (snow layer etc)
		vec3(1.0, 0.0625, 1.0),//bottom pixel(carpets etc)
		vec3(0.9375, 0.0625, 0.9375),//pressure plates
		vec3(0.5625),//torches
		vec3(0.6875, 0.4375, 0.6875),//lantern and flowerpot
		vec3(0.5625, 1.0, 0.5625),//chain, iron bar, glass pane
		vec3(1.0, 0.9375, 1.0),//path, farmland
		vec3(0.9375, 1.0, 0.9375),//cactus
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0),
		vec3(1.0)
	);

	float offset = 1000000.0;
	vec3 newPos = vec3(0);
	vec3 normal = vec3(0);
	for(int i = 0; i < 6; i++) {
		vec3 facing = vec3(float(i == 3), float(i == 4), float(i == 5)) - vec3(float(i == 0), float(i == 1), float(i == 2));
		vec3 face = mincoord[ID] * float(i < 3) + maxcoord[ID] * float(i > 2);
		float newOffset = dot(sign(face - pos) * sign(dir), abs(facing)) * length((pos - face) * facing) / length(dir * facing);
		float isInBounds = float(((pos.x + dir.x * newOffset > mincoord[ID].x && pos.x + dir.x * newOffset < maxcoord[ID].x) || abs(facing.x) > 0.5) &&
								((pos.y + dir.y * newOffset > mincoord[ID].y && pos.y + dir.y * newOffset < maxcoord[ID].y) || abs(facing.y) > 0.5) &&
								((pos.z + dir.z * newOffset > mincoord[ID].z && pos.z + dir.z * newOffset < maxcoord[ID].z) || abs(facing.z) > 0.5) && length(face * facing) < 1.01);
		if (isInBounds > 0.5 && newOffset < offset) {
			offset = newOffset;
			newPos = pos + dir * offset;
			normal = facing;
		}
	}
	if(offset > 1000) normal = vec3(1000);
	return vec3[2](newPos, normal);
}