vec3 SunGlare(vec3 color, vec3 nViewPos, vec3 lightCol) {
	float cosSp = dot(nViewPos, lightVec);
	if (cosSp > 0.0) {
		float cosS = cosSp;
		cosS *= cosS;
		cosS *= cosS;
		cosS *= cosS;
		float visfactor = 0.075;

		float sunGlare = cosS;
		sunGlare = visfactor / (1.0 - (1.0 - visfactor) * sunGlare) - visfactor;
		//sunGlare = sunGlare * 1.015 / 0.95 - 0.015;
		sunGlare *= cosSp;

		sunGlare *= 0.25 * SUN_GLARE_STRENGTH * (1.0 - rainStrengthS);

		#ifdef SHADOWS
			//sunGlare *= shadowFade;
		#endif
		float shadowTime = abs(sunVisibility - 0.5) * 2.0;
		shadowTime *= shadowTime;
		sunGlare *= shadowTime * shadowTime;

		color += lightCol * sunGlare;
	}
	
	return color;
}