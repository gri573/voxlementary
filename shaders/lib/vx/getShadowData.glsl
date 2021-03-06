//WARNING: only works in GBuffers, needs texture atlas and shadowcolor0 to be declared

#include "/lib/vx/voxelTrace.glsl"
#include "/lib/vx/aabb.glsl"
#include "/lib/vx/crossmodels.glsl"
const int raySteps = 15;
vec4 GetShadow(vec3 pos, vec3 dir){
	float vxDist = 0.0625 * shadowMapResolution / VXHEIGHT;
	vec3 pos0 = pos + 0.01 * dir;
	pos = vec3(vxDist, 32 * VXHEIGHT * VXHEIGHT, vxDist) - pos * (dir) / (abs(dir) + vec3(0.0000001));
	pos /= abs(dir) + vec3(0.0000001);
	float offset = (min(pos.x, min(pos.y, pos.z)) - 1.5)/length(dir);
	pos = pos0 + offset * dir;
	dir *= -1;
	
	bool rayEnd = false;
	vec4 rayColor = vec4(1.0, 1.0, 1.0, 0.0);
	vec2 oldmidtexcoord = vec2(0.0);
	float mode = 0;
	vec3 epsilon = 0.0001 * dir;
	for(int l = 0; !rayEnd && l < raySteps; l++){
		float skip = 0;
		mat3 voxelData = mat3(vec3(0.0), vec3(0.0), vec3(0.0));
		vec3 coloretc = dir;
		voxelTrace(pos, coloretc, mode, offset, voxelData); // outputs voxelData: vec3[5](pos.xyz, vec3(midtexcoord, texturesize), normal, vec3(isFound, distance-ish, blockID), glcolor)
		int ID = int(floor(voxelData[1].z * 255 + 0.5));
		float isAABB = float(ID >= 5 && ID < 57);
		vec3[2] posNorm = vec3[2](0.0);
		if (ID >= 57 && ID <= 62 || ID == 4 || ID == 229) skip = 1;
		if (isAABB > 0.5) {
			float height = coloretc.z;
			if (ID >= 50 && ID < 53) ID = 18;
			if (ID >= 53 && ID < 55) ID = 19;
			if (ID >= 55 && ID < 57) ID = 5;
			ID -= 5;
			vec3 localPos = fract(pos + epsilon);
			posNorm = aabb(localPos, dir, ID, height);
			if (posNorm[1].x < 900){
				posNorm[0] -= localPos - epsilon;
				pos += posNorm[0];
				voxelData[2] = posNorm[1];
			}else{
				skip = 1;
				posNorm[0] = vec3(0);
			}
			ID += 5;
		}

		if(length(voxelData[0]) < 0.9) voxelData[0] = vec3(1, 0, 0);
		vec2 midtexcoord = coloretc.xy;
		vec4 rayColor0 = vec4(float(ID == 1 || (ID >= 60 && ID != 65 && ID != 72 &&(ID < 79 || ID > 82))));
		if (ID == 120 || ID == 3){
			rayColor0 = vec4(coloretc, 0.5 + 0.25 * float(ID == 3));
		}
		if(ID == 121) {
			rayColor0.a = float(float(abs(fract(pos.x) - 0.5) > 0.4375) + float(abs(fract(pos.y) - 0.5) > 0.4375) + float(abs(fract(pos.z) - 0.5) > 0.4375) > 1.5);
		}
		float isnLast = float(l + 1 < raySteps);
		offset = (pos0.x - pos.x) / dir.x + 0.00001;
		pos += (45 * float(posNorm[0] != vec3(0)) + 5) * epsilon - posNorm[0];
		rayColor0.a = mix(rayColor0.a, 1.0, float(isnLast < 0.5 || isAABB > 0.5));
		rayColor0.a = mix(rayColor0.a, 0.0, float(offset < 0.0));
		rayColor0.a = rayColor0.a * rayColor0.a * 0.5 + rayColor0.a * 0.5;
		rayColor0 *= 1 - skip * isnLast;
		rayColor0.rgb *= vec3(1.0) - float(ID == 3) * vec3(1 - WATER_COL_R, 1 - WATER_COL_G, 1 - WATER_COL_B)/255.0;
		rayColor0.rgb = (1 - abs(2 * rayColor0.a - 1)) * rayColor0.rgb + max(1 - 2 * rayColor0.a, 0.0) * vec3(1.0);
		rayColor.rgb *= rayColor0.rgb;
		rayColor.a = offset;
		mode = (1 - float(ID == 4) - isAABB) * float(voxelData[1].z * 256 > 0.5);
		if(offset < 0.0 || voxelData[1].x < 0.5 || length(rayColor.rgb) < 0.01) rayEnd = true;
		oldmidtexcoord = midtexcoord;
	}
	vec4 color = rayColor;
	return color;
}