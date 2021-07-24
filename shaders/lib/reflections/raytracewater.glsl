vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5) * 1.82, abs(coord.t-0.5) * 2.0);
}

vec4 Raytrace(sampler2D depthtex, vec3 viewPos, vec3 normal, float dither, float fresnelRT) {
	vec3 pos = vec3(0.0);
	float dist = 0.0;

	#if AA > 1
		dither = fract(dither + frameTimeCounter);
	#endif

	vec3 start = viewPos;
	vec3 nViewPos = normalize(viewPos);
    vec3 vector = 0.5 * reflect(nViewPos, normalize(normal));
    viewPos += vector;
	vec3 tvector = vector;

	float difFactor = fresnelRT;

    int sr = 0;

    for(int i = 0; i < 30; i++) {
        pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;
		float depth = texture2D(depthtex, pos.xy).r;
		if (pos.x < -0.0 || pos.x > 1.0 || pos.y < -0.0 || pos.y > 1.0) depth = 1.0;
		vec3 rfragpos = vec3(pos.xy, depth);//mix(depth, 1.0, clamp(max(abs(pos.x - 0.5) - 0.5, abs(pos.y - 0.5) - 0.5) * 2, 0, 1)));
        rfragpos = nvec3(gbufferProjectionInverse * nvec4(rfragpos * 2.0 - 1.0));
		dist = length(start - rfragpos);

        float err = length(viewPos - rfragpos);
		float lVector = length(vector);
		float dif = length(start - rfragpos);
		if (err < pow(lVector, 1.14) || (dif < difFactor && err > difFactor)) {
                sr++;
                if(sr >= 6) break;
				tvector -= vector;
                vector *= 0.1;
		}
        vector *= 2.0;
        tvector += vector * (dither * 0.05 + 0.75);
		viewPos = start + tvector;
    }

	return vec4(pos, dist);
}