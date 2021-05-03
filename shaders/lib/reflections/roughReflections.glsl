vec4 RoughReflection(vec3 viewPos, vec3 normal, float dither, float smoothness, sampler2D colortex, float alternative) {
    vec4 color = vec4(0.0);

    vec4 pos = Raytrace(depthtex0, viewPos, normal, dither, alternative);
	float border = clamp(1.0 - pow(cdist(pos.st), 50.0), 0.0, 1.0);
	
	if (pos.z < 1.0 - 1e-5) {
		#ifdef REFLECTION_ROUGH
			float dist = 1.0 - exp(-0.125 * (1.0 - smoothness) * pos.a);
			float lod = log2(viewHeight / 8.0 * (1.0 - smoothness) * dist) * 0.35;
		#else
			float lod = 0.0;
		#endif

		float check = float(texture2DLod(depthtex0, pos.st, 0.0).r < 1.0 - 1e-5);
		if (lod < 1.0) {
			color.a = check;
			if (color.a > 0.1) color.rgb = texture2DLod(colortex, pos.st, 0.0).rgb;
		} else {
			float alpha = check;
			if (alpha > 0.1) {
				color.rgb += texture2DLod(colortex, pos.st, max(lod - 1.0, 0.0)).rgb;
				color.a += alpha;
			}
		}
		
		color *= color.a;
		color.a *= border;
	}
	color.rgb *= 1.8 * (1.0 - 0.065 * min(length(color.rgb), 10.0));
	
    return color;
}