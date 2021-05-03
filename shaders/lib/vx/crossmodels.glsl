vec3 crossModel[2](vec3 pos, vec3 dir){
	float offset0 = (pos.x - pos.z) / (dir.z - dir.x);
	float offset1 = (1 - pos.x - pos.z) / (dir.x + dir.z);

	vec2 posRange = vec2(0.1, 0.9);
	vec3 pos0 = pos + min(offset0, offset1) * dir;
	vec3 pos1 = pos + max(offset0, offset1) * dir;
	pos = float(clamp(pos0, vec3(posRange.x, 0.0, posRange.x), vec3(posRange.y, 1.0, posRange.y)) == pos0) * pos0 + float(clamp(pos0, vec3(posRange.x, 0.0, posRange.x), vec3(posRange.y, 1.0, posRange.y)) != pos0 && clamp(pos1, vec3(posRange.x, 0.0, posRange.x), vec3(posRange.y, 1.0, posRange.y)) == pos1) * pos1;
	vec3 normal = vec3(1.0, 0.0, 0.0)  + float(clamp(pos0, vec3(posRange.x, 0.0, posRange.x), vec3(posRange.y, 1.0, posRange.y)) != pos0 && clamp(pos1, vec3(posRange.x, 0.0, posRange.x), vec3(posRange.y, 1.0, posRange.y)) != pos1) * vec3(2.0);
	return vec3[2](pos, normal);
}