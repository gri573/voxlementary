//WARNING: needs voxelPos to be included
vec3 voxelTrace[5](vec3 startPos, vec3 vect0, float mode, float end) {
	float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
	vec2 midtexcoord0 = vec2(-1000.0);
	vec4 intersect = vec4(1000);
	vec4 vxData = vec4(0.0);
	vec4 pos = vec4(startPos, 0.0);
	vec3 normal = vec3(0.0);
	vec3 glcolor = vec3(0.0);
	float isFound = 0.0;
	int i = 0;
	float xstep = - fract(startPos.x) / vect0.x;
	float ystep = - fract(startPos.y) / vect0.y;
	float zstep = - fract(startPos.z) / vect0.z;

	while((abs(pos.x) < vxDist && abs(pos.y) < 32 * VXHEIGHT * VXHEIGHT - 0.5 && abs(pos.z) < vxDist && i < 1 + 3 * vxDist) || sign(pos.xyz) * sign(vect0) != vec3(1, 1, 1)){
		float presentPerfect = float(i > 0);
		pos.w = max(min(xstep, min(ystep, zstep)), 0.0);
		if (pos.w > end) break;
		vec3 facing0 = vec3(float(xstep <= ystep && xstep <= zstep), float(ystep <= zstep && ystep <= xstep), float(zstep <= xstep && zstep <= ystep));
		pos.xyz = startPos + pos.w * vect0 * presentPerfect;
		//if(abs(dot(fract(pos.xyz), facing0) - 0.5) > 0.499) {
			vec3 facing = facing0;
			vec3[2] posNorm = getVoxelPos(floor(pos.xyz + sign(vect0) * facing * 0.1 * presentPerfect) + vec3(0.5));
			vec2 texCoord = posNorm[0].xz /shadowMapResolution + vec2(0.5);
			vec4 vxData0 = texture2D(shadowcolor0, texCoord) * posNorm[1].x;

			if (i < 0.5) midtexcoord0 = vxData0.xy;
			float isDifferent = float(abs(midtexcoord0.x - vxData0.x) / vxData0.z > 0.5 || abs(midtexcoord0.y - vxData0.y) / vxData0.z > 0.5);
			float isEmpty = float(256 * vxData0.a < 0.5);
			if(abs(dot(fract(pos.xyz), facing0) - 0.5) > 0.4998 && (mode + (1 - 2 * mode) * isEmpty < 0.5 || mode * isDifferent > 0.5)) {
				if (isEmpty < 0.5 && isDifferent > 0.5) mode = 0;
				posNorm = getVoxelPos(floor(pos.xyz + sign(vect0) * facing * (0.1 - 0.2 * mode) * presentPerfect) + vec3(0.5));
				texCoord = posNorm[0].xz /shadowMapResolution + vec2(0.5);
				glcolor = texture2D(shadowcolor1, texCoord).rgb * posNorm[1].x;
				vxData0 = texture2D(shadowcolor0, texCoord) * posNorm[1].x;
				isFound = 1.0;
				normal = -facing * sign(vect0);
				vxData = vec4(vxData0.rgb, vxData0.a - 26/255.0);
				break;
			}
		//}
		xstep += facing0.x / abs(vect0.x) * presentPerfect;
		ystep += facing0.y / abs(vect0.y) * presentPerfect;
		zstep += facing0.z / abs(vect0.z) * presentPerfect;
		i++;
	}
	return vec3[5](pos.xyz, vxData.rgb, normal, vec3(isFound, pos.w, vxData.a), glcolor);
}