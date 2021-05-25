//WARNING: only works in GBuffers, needs texture atlas and shadowcolor0 to be declared

#include "/lib/vx/voxelTrace.glsl"
#include "/lib/vx/aabb.glsl"
#include "/lib/vx/crossmodels.glsl"
const int raySteps = 5;
vec4 getWorldData(vec3 pos, vec3 dir){
	bool rayEnd = false;
	vec4 rayColor = vec4(0);
	vec2 oldmidtexcoord = vec2(0.0);
	float mode = 0;
	vec3 epsilon = 0.0001 * dir;
	for(int l = 0; !rayEnd && l < raySteps; l++){
		float skip = 0;
		vec3[5] voxelData = vec3[5](vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
		voxelTrace(pos, dir, mode, 10000, voxelData); // contents of voxelData: vec3[5](pos.xyz, vec3(midtexcoord, texturesize), normal, vec3(isFound, distance-ish, blockID), glcolor)
		pos = voxelData[0];
		int ID = int(voxelData[3].z * 255 + 0.5);
		float isAABB = float(ID >= 5 && ID < 57);
		vec3[2] posNorm = vec3[2](vec3(0.0), vec3(0.0));
		if (ID >= 57 && ID <= 62) skip = 1;
		if (ID == 4){
			vec3 localPos = fract(pos + epsilon);
			posNorm = crossModel(localPos, dir);
			if(posNorm[1].y < 1.5) {
				posNorm[0] -= localPos - epsilon;
				pos += posNorm[0];
				voxelData[2] = posNorm[1];
				voxelData[1].xy -= vec2(voxelData[1].z) * float(dir.x > 0.0);
			}else{
				skip = 1;
			}
		}
		if (isAABB > 0.5) {
			if (ID >= 50 && ID < 53) ID = 18;
			if (ID >= 53 && ID < 55) ID = 19;
			if (ID >= 55 && ID < 57) ID = 5;
			ID -= 5;
			vec3 localPos = fract(pos + epsilon);
			posNorm = aabb(localPos, dir, ID);
			if (posNorm[1].x < 900){
				posNorm[0] -= localPos - epsilon;
				pos += posNorm[0];
				voxelData[2] = posNorm[1];
			}else{
				skip = 1;
			}
		}
		if(length(voxelData[2]) < 0.9) voxelData[2] = fract(pos);
		vec2 midtexcoord = voxelData[1].xy;
		vec4 rayColor0 = vec4(1.0);
		if (ID == 120 || ID == 3){
			rayColor0 = vec4(voxelData[1], 0.5);
		}

		rayColor0 *= 1 - skip;
		rayColor0.rgb *= voxelData[4];
		rayColor.rgb += rayColor0.rgb * (1.0 -  rayColor.a) * rayColor0.a;
		rayColor.a = 1.0 - (1.0 - rayColor.a) * (1.0 - rayColor0.a) * float(l + 1 != raySteps);
		//rayColor.a = 1.0;
		//rayColor.rgb = fract(pos + 0.00001 * normalize(dir));
		mode = (1 - float(ID == 4) - isAABB) * float(voxelData[3].z * 256 > 0.5);
		if(voxelData[3].x < 0.5 || rayColor.a > 0.9999) rayEnd = true;
		oldmidtexcoord = midtexcoord;
		pos += 0.005 * normalize(dir) - posNorm[0];
	}
	vec4 color = rayColor;
	return color;
}