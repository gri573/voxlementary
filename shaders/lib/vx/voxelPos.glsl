vec3[2] getVoxelPos(vec3 pos){
	float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
	float discarder = 1.0;
	if (abs(pos.x) > vxDist || abs(pos.z) > vxDist || abs(pos.y) > VXHEIGHT * VXHEIGHT * 32) discarder = 0.0;
		pos.y = floor(pos.y) + 0.5;
		pos.x += mod(pos.y, 8 * VXHEIGHT) * 2 * vxDist - 8 * vxDist * VXHEIGHT;
		pos.z += floor(pos.y * 0.125 / VXHEIGHT) * 2 * vxDist + vxDist;
	return vec3[2](pos, vec3(discarder));
}

vec3 getVoxelPosInverse(vec2 voxelScreenPos) {
	float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
	vec3 pos = vec3(fract(voxelScreenPos.x * 8 * VXHEIGHT), 0, fract(voxelScreenPos.y * 8 * VXHEIGHT));
	pos.xz -= 0.5;
	pos.xz *= 2 * vxDist;
	//pos.xz -= vxDist;
	pos.y = floor(voxelScreenPos.x * 8 * VXHEIGHT) + 8 * VXHEIGHT * floor(voxelScreenPos.y * 8 * VXHEIGHT) - 32 * VXHEIGHT * VXHEIGHT;
	//pos.z -= 0.5;
	return pos;
}