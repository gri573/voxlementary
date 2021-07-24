vec4 SimpleReflection(vec3 viewPos, vec3 normal, float dither, float fresnelRT) {
	vec4 reflection = vec4(0.0);

    vec4 pos = Raytrace(depthtex1, viewPos, normal, dither, fresnelRT);
	#ifdef REFLECTION_CAPTURE
		vec4 aroundPos = gbufferProjectionInverse * vec4(vec2(2.0, 2.0) * pos.xy - vec2(1.0, 1.0), 1.0, 1.0);
		aroundPos /= aroundPos.w;

		aroundPos = gbufferModelViewInverse  * aroundPos;
		aroundPos /= length(aroundPos.xz) + 0.000001;
		aroundPos.y = (aroundPos.y + 1.5) / 3.0;
		aroundPos.z = acos(aroundPos.z);
		if(aroundPos.x < 0.0) aroundPos.z = 6.283 - aroundPos.z;
		aroundPos.x = aroundPos.z / 6.283;
		vec4 aroundCol = texture2D(colortex9, fract(aroundPos.xy));
	#endif
	float border = clamp(1.0 - pow(cdist(pos.st), 50.0), 0.0, 1.0);
	pos.z -= 0.00001;
	if (pos.z < 1.0 - 1e-5) {
		reflection.a = float(0.999999 > texture2D(depthtex1, pos.st).r);
		if (reflection.a > 0.001) reflection.rgb = texture2D(gaux2, pos.st).rgb;
		reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));
		#ifdef REFLECTION_CAPTURE
		reflection.rgb = mix(reflection.rgb, aroundCol.rgb, 1 - (border * reflection.a));
		//reflection.rgb = aroundCol.rgb;
		//reflection.a = 1.0;
		reflection.a = reflection.a * border + aroundCol.a;
		#else
		reflection.a *= border;
		#endif
	}

	return reflection;
}