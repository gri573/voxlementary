vec3 getVoxelPos[2](vec3 pos){
float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
float discarder = 1.0;
if (abs(pos.x) > vxDist || abs(pos.z) > vxDist || abs(pos.y) > VXHEIGHT * VXHEIGHT * 32) discarder = 0.0;
	pos.y = floor(pos.y) + 0.5;
	pos.x += mod(pos.y, 8 * VXHEIGHT) * 2 * vxDist - 8 * vxDist * VXHEIGHT;
	pos.z += floor(pos.y * 0.125 / VXHEIGHT) * 2 * vxDist + vxDist;
return vec3[2](pos, vec3(discarder));
}