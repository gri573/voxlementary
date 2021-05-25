#ifdef OVERWORLD

#include "/lib/atmospherics/sunGlare.glsl"

#endif

vec3 Fog1(vec3 color, float lWorldPos, float lViewPos, vec3 nViewPos, vec3 extra, float NdotU) {
    #if defined OVERWORLD && !defined ONESEVEN && !defined TWO
		#if FOG1_TYPE < 2
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		#else
		float fog = lViewPos / far * 1.5 * (10/FOG1_DISTANCE);
		#endif

		fog = 1.0 - exp(-0.1 * pow(fog, 10.0));

		if (fog > 0.0) {
			vec3 artificialFogColor = GetSkyColor(lightCol, NdotU, nViewPos, false);
			artificialFogColor = SunGlare(artificialFogColor, nViewPos, lightCol);
			if (eyeAltitude < 2.0) artificialFogColor.rgb *= clamp((eyeAltitude-1.0), 0.0, 1.0);
			color.rgb = mix(color.rgb, artificialFogColor, fog);
		}
	#endif

    #if defined NETHER && defined NETHER_FOG // extra = nether smoke (if enabled)
		#if FOG1_TYPE > 0
		float fog = lViewPos / far * 1.5;
		#else
		float fog = lWorldPos / far * 1.5;
		#endif

		fog = 1.0 - exp(-6.0 * pow(fog, 5.0));
		vec3 artificialFogColor = pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4;
		#ifdef NETHER_SMOKE
			artificialFogColor += extra * fog;
		#endif
		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif

    #ifdef END // extra = viewPos
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10.0));
		if (fog > 0.0) {
			vec3 artificialFogColor = endCol * 0.0584;
			#if defined ENDER_NEBULA && !defined COMPATIBILITY_MODE
				float dither = Bayer64(gl_FragCoord.xy);
				vec4 nebula = DrawEnderNebula(extra.xyz, dither, endCol, false);
				nebula = pow(nebula, vec4(1.0 / 2.2));
				nebula.rgb *= pow(nebula.rgb, vec3(2.2));
				artificialFogColor.rgb += nebula.rgb * fog;
			#endif
			color.rgb = mix(color.rgb, artificialFogColor, fog);
		}
    #endif

    #ifdef TWO
		float fog = lWorldPos / far * 4.0 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 3.0));

		//float NdotU = 1.0 - max(dot(nViewPos, upVec), 0.0);
		NdotU = 1.0 - max(NdotU, 0.0);
		NdotU = NdotU * NdotU;
		#ifndef ABYSS
			vec3 midnightPurple = vec3(0.0003, 0.0004, 0.002) * 1.25;
			vec3 midnightFogColor = fogColor * fogColor * 0.3;
		#else
			vec3 midnightPurple = skyColor * skyColor * 0.00075;
			vec3 midnightFogColor = fogColor * fogColor * 0.09;
		#endif
		vec3 artificialFogColor = mix(midnightPurple, midnightFogColor, NdotU);

		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif
	
    #ifdef SEVEN
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10.0));
		float cosT = dot(nViewPos, upVec);
		vec3 twilightPurple  = vec3(0.005, 0.006, 0.018);
		vec3 twilightGreen = vec3(0.015, 0.03, 0.02);
		#ifdef TWENTY
		twilightPurple = twilightGreen * 0.1;
		#endif
		vec3 artificialFogColor = 2 * (twilightPurple * 2 * clamp(pow(cosT, 0.7), 0.0, 1.0) + twilightGreen * (1-clamp(pow(cosT, 0.7), 0.0, 1.0)));
		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif
	
    #ifdef ONESEVEN
		float fogoneseven = lWorldPos / 16 * (1.35-sunVisibility*0.35);
		fogoneseven = 1.0 - exp(-0.1 * pow(fogoneseven, 3.0));

		if (fogoneseven > 0.0) {
			vec3 artificialFogColor = GetSkyColor(lightCol, NdotU, nViewPos, false);
			artificialFogColor = SunGlare(artificialFogColor, nViewPos, lightCol);
			if (eyeAltitude < 2.0) artificialFogColor.rgb *= clamp((eyeAltitude-1.0), 0.0, 1.0);
			color.rgb = mix(color.rgb, artificialFogColor, fogoneseven);
		}
    #endif
	
	return vec3(color.rgb);
}

vec3 Fog2(vec3 color, float lViewPos, vec3 worldPos) {

    #ifdef OVERWORLD
		#ifdef FOG2_ALTITUDE_MODE
			float altitudeFactor = (worldPos.y + eyeAltitude + 1000 - FOG2_ALTITUDE) * 0.001;
			if (altitudeFactor > 0.965 && altitudeFactor < 1.0) altitudeFactor = pow(altitudeFactor, 1.0 - (altitudeFactor - 0.965) * 28.57);
			altitudeFactor = clamp(pow(altitudeFactor, 20.0), 0.0, 1.0);
		#endif
		
		float fog2 = lViewPos / pow(far, 0.25) * 0.035 * (1.0 + rainStrengthS * FOG2_RAIN_DISTANCE_M) * (1.0 - sunVisibility*0.25*(1.0 - rainStrengthS)) * (32.0/(FOG2_DISTANCE + 0.01));
		fog2 = (1.0 - (exp(-50.0 * pow(fog2*0.125, 3.25) * eBS)));
		fog2 *= min(FOG2_OPACITY * (3.0 + rainStrengthS * FOG2_RAIN_OPACITY_M - sunVisibility * 2.0), 1.0);
		#ifdef FOG2_ALTITUDE_MODE
			fog2 *= pow(clamp((eyeAltitude - FOG2_ALTITUDE*0.2) / FOG2_ALTITUDE, 0.0, 1.0), 2.5 - FOG2_RAIN_ALTITUDE_M * rainStrengthS * 2.5);
			fog2 *= 1.0 - altitudeFactor * (1.0 - FOG2_RAIN_ALTITUDE_M * rainStrengthS);
		#endif
		
		float sunVisibility2 = sunVisibility * sunVisibility;
		float sunVisibility4 = sunVisibility2 * sunVisibility2;
		float sunVisibility8 = sunVisibility4 * sunVisibility4;
		float timeBrightness2 = sqrt1(timeBrightness);
		vec3 fogColor2 = mix(lightCol*0.5, pow(skyColCustom, vec3(0.7))*1.15, timeBrightness2);
		fogColor2 = mix(ambientNight*ambientNight*ambientNight*7.5, fogColor2, sunVisibility8);
		if (rainStrengthS > 0.0) {
			float rainStrengthS2 = 1.0 - (1.0 - rainStrengthS) * (1.0 - rainStrengthS);
			fogColor2 = mix(fogColor2, FOG2_RAIN_BRIGHTNESS_M * skyColCustom * (0.01 + 0.05 * sunVisibility8 + 0.1 * timeBrightness2), rainStrengthS2);
		}
		fogColor2 *= FOG2_BRIGHTNESS;
		if (eyeAltitude < 2.0) fogColor2.rgb *= clamp((eyeAltitude-1.0), 0.0, 1.0);

		color.rgb = mix(color.rgb, fogColor2, fog2);
    #endif

    #ifdef END
		float fog2 = lViewPos / pow(far, 0.25) * 0.035 * (32.0/FOG2_END_DISTANCE);
		fog2 = 1.0 - (exp(-50.0 * pow(fog2*0.125, 4.0)));
		#ifdef FOG2_ALTITUDE_MODE
			float altitudeFactor = clamp((worldPos.y + eyeAltitude + 100 - FOG2_END_ALTITUDE) * 0.01, 0.0, 1.0);
			if (altitudeFactor > 0.75 && altitudeFactor < 1.0) altitudeFactor = pow(altitudeFactor, 1.0 - (altitudeFactor - 0.75) * 4.0);
			fog2 *= 1.0 - altitudeFactor;
		#endif
		fog2 = clamp(fog2, 0.0, 0.125) * (7.0 + fog2);
		fog2 = 1 - pow(1 - fog2, 2.0 - fog2);
		vec3 fogColor2 = endCol * 0.051 * pow(2.5 / 2.25, 1.3);
		color.rgb = mix(color.rgb, fogColor2 * FOG2_END_BRIGHTNESS, fog2 * FOG2_END_OPACITY);
    #endif
	
    #if defined SEVEN && !defined TWENTY
		float fog2 = lViewPos / pow(far, 0.25) * 0.035 * (1 + rainStrengthS) * (32.0/(FOG2_DISTANCE + 0.01));
		fog2 = 1.0 - (exp(-50.0 * pow(fog2*0.125, 4.0) * eBS));
		float altitudeFactor = (worldPos.y + eyeAltitude + 1000 - 90 * (1 + rainStrengthS*0.5)) * 0.001;
		if (altitudeFactor > 0.965 && altitudeFactor < 1.0) altitudeFactor = pow(altitudeFactor, 1.0 - (altitudeFactor - 0.965) * 28.57);
		fog2 *= 1.0 - altitudeFactor;
		fog2 = clamp(fog2, 0.0, 0.125) * (7.0 + fog2);
		vec3 fogColor2 = vec3(0.015, 0.03, 0.02);
		if (eyeAltitude < 2.0) fogColor2.rgb *= clamp((eyeAltitude-1.0), 0.0, 1.0);
		color.rgb = mix(color.rgb, fogColor2, fog2 * 0.80);
    #endif
	
	return vec3(color.rgb);
}

vec3 WaterFog(vec3 color, float lViewPos, float fogrange) {
    float fog = lViewPos / fogrange;
    fog = 1.0 - exp(-3.0 * fog * fog);
	color *= pow(underwaterColor.rgb, vec3(0.5)) * 3.0;
    color = mix(color, 0.8 * pow(underwaterColor.rgb * (1.0 - blindFactor), vec3(2.0)), fog);

	return vec3(color.rgb);
}

vec3 BlindFog(vec3 color, float lViewPos) {
	float fog = lViewPos *0.04* (5.0 / blindFactor);
	fog = (1.0 - exp(-6.0 * fog * fog * fog)) * blindFactor;
	color.rgb = mix(color.rgb, vec3(0.0), fog);
	
	return vec3(color.rgb);
}

vec3 LavaFog(vec3 color, float lViewPos) {
	#ifndef LAVA_VISIBILITY
		float fog = lViewPos * 0.3;
		fog = (1.0 - exp(-4.0 * fog * fog * fog));
		color.rgb = mix(color.rgb, vec3(0.5), fog);
	#else
		float fog = lViewPos * 0.02;
		fog = 1.0 - exp(-3.0 * fog);
		color.rgb = mix(color.rgb, vec3(0.5), fog);
	#endif

	return vec3(color.rgb);
}

vec3 startFog(vec3 color, vec3 nViewPos, float lViewPos, vec3 worldPos, vec3 extra, float NdotU) {
	#if defined FOG2 && !defined GBUFFER_CODING
		if (isEyeInWater == 0) color.rgb = Fog2(color.rgb, lViewPos, worldPos);
	#endif
	
	#if defined FOG1 && !defined GBUFFER_CODING
		if (isEyeInWater == 0) color.rgb = Fog1(color.rgb, length(worldPos.xz) * 1.025, lViewPos, nViewPos, extra, NdotU);
	#endif
	
	if (isEyeInWater == 1 && blindFactor == 0) color.rgb = WaterFog(color.rgb, lViewPos, waterFog * (1.0 + eBS));
	if (isEyeInWater == 2 && blindFactor == 0) color.rgb = LavaFog(color.rgb, lViewPos);
	if (blindFactor > 0.0) color.rgb = BlindFog(color.rgb, lViewPos);
	
	return vec3(color.rgb);
}