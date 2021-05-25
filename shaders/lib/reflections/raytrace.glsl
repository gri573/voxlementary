vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5) * 1.95, abs(coord.t-0.5) * 2.0);
}

vec4 Raytrace(sampler2D depthtex, vec3 viewPos, vec3 normal, float dither) {
	vec3 pos = vec3(0.0);
	float dist = 0.0;

	#if AA > 1
		dither = fract(dither + frameTimeCounter);
	#endif

	vec3 start = viewPos;

    vec3 vector = reflect(normalize(viewPos), normalize(normal));
    viewPos += vector;
	vec3 tvector = vector;

    int sr = 0;

    for(int i = 0; i < 30; i++) {
        pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;
		if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) break;

		vec3 rfragpos = vec3(pos.xy, texture2D(depthtex,pos.xy).r);
        rfragpos = nvec3(gbufferProjectionInverse * nvec4(rfragpos * 2.0 - 1.0));
		dist = length(start - rfragpos);

        float err = length(viewPos - rfragpos);
		float lVector = length(vector);
		if (lVector > 1.0) lVector = pow(lVector, 1.14);
		if (err < lVector) {
                sr++;
                if(sr >= 6) break;
				tvector -= vector;
                vector *= 0.1;
		}
        vector *= 2.0;
        tvector += vector * (dither * 0.05 + 1.0);
		viewPos = start + tvector;
    }

	return vec4(pos, dist);
}