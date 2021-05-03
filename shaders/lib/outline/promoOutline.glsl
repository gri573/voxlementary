vec2 promoOutlineOffsets[4] = vec2[4](vec2(-1.0,1.0),vec2(0.0,1.0),vec2(1.0,1.0),vec2(1.0,0.0));

void PromoOutline(inout vec3 color, sampler2D depth){
	float ph = 1.0 / 1080.0;
	float pw = ph / aspectRatio;

	float outlined = 1.0;
	float z = GetLinearDepth(texture2D(depth, texCoord).r) * far;
	float totalz = 0.0;
	float maxz = 0.0;
	float sampleza = 0.0;
	float samplezb = 0.0;

	int sampleCount = PROMO_OUTLINE_THICKNESS * 4;

	for(int i = 0; i < sampleCount; i++){
		vec2 offset = (1.0 + floor(i / 4.0)) * vec2(pw, ph) * promoOutlineOffsets[int(mod(float(i), 4))];
		sampleza = GetLinearDepth(texture2D(depth, texCoord + offset).r) * far;
		samplezb = GetLinearDepth(texture2D(depth, texCoord - offset).r) * far;
		if (i < 4) maxz = max(maxz, max(sampleza, samplezb));

		outlined *= clamp(1.0 - ((sampleza + samplezb) - z * 2.0) * 32.0 / z, 0.0, 1.0);

		totalz += sampleza + samplezb;
	}

	#if PROMO_OUTLINE_MODE == 2
		float outlinea = 1.0;
		float outlineb = 1.0;
	#else
		float outlinea = 1.0 - clamp((z * 8.0 - totalz) * 64.0 / z, 0.0, 1.0) *
						 clamp(1.0 - ((z * 8.0 - totalz) * 32.0 - 1.0) / z, 0.0, 1.0);
		float outlineb = clamp(1.0 +  8.0 * (z - maxz) / z, 0.0, 1.0);
	#endif

	float outAB = pow(outlinea * outlineb, 0.1);
	
	float outlinec = clamp(1.0 + 64.0 * (z - maxz) / z, 0.0, 1.0);

	float outline = (0.35 * outAB + 0.65) * 
					(0.75 * (1.0 - outlined) * outlinec + 1.0);

	float fog = 0.0;
	#ifdef FOG1
		float fogZ    = texture2D(depthtex0, texCoord).r;
		vec4 screenPos = vec4(texCoord, fogZ, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
		fog = length(viewPos) / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10));
	#endif

	float outlinePower = PROMO_OUTLINE_STRENGTH / PROMO_OUTLINE_THICKNESS;
	if (outline < 1.0) {
		outlinePower = PROMO_OUTLINE_STRENGTH;
	}
    outline = pow(outline, outlinePower);
	#if PROMO_OUTLINE_MODE == 3
		outline = abs(outline - 1.0) + 1.0;
	#endif
    vec3 color2 = color.rgb * outline;
    color = mix(color2, color, fog);
}
