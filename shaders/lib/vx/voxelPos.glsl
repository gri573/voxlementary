vec3[2] getVoxelPos(vec3 pos){
	float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
	float discarder = 1.0;
	if (abs(pos.x) > vxDist || abs(pos.z) > vxDist || abs(pos.y) > VXHEIGHT * VXHEIGHT * 24) discarder = 0.0;
		pos.y = floor(pos.y) + 0.5;
		pos.x += mod(pos.y, 4 * VXHEIGHT) * 2 * vxDist;
		pos.z += floor(pos.y * 0.25 / VXHEIGHT) * 2 * vxDist + vxDist + 0.25 * shadowMapResolution;
		if(pos.z > 0.5 * shadowMapResolution) pos.xz -= vec2(0.5 * shadowMapResolution);
	return vec3[2](pos, vec3(discarder));
}

vec3 getVoxelPosInverse(vec2 voxelScreenPos) {
	float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
	vec3 pos = vec3(fract(voxelScreenPos.x * 8 * VXHEIGHT), 0, fract(voxelScreenPos.y * 8 * VXHEIGHT));
	pos.xz -= 0.5;
	pos.xz *= 2 * vxDist;
	if(voxelScreenPos.x < 0.5) voxelScreenPos.xy += 0.5;
	//voxelScreenPos.y += 0.25;
	pos.y = floor((voxelScreenPos.x) * 8 * VXHEIGHT - 4) + 4 * VXHEIGHT * floor(voxelScreenPos.y * 8 * VXHEIGHT) - 24 * VXHEIGHT * VXHEIGHT;
	//pos.z -= 0.5;
	return pos;
}