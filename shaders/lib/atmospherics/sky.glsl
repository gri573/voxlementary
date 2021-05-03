vec3 GetSkyColor(vec3 lightCol, float NdotU, vec3 nViewPos, bool doGround) {
    float sunVisibility2 = sunVisibility * sunVisibility;
    float sunVisibility4 = sunVisibility2 * sunVisibility2;

    vec3 sky = skyCol;

    float NdotS = clamp(dot(nViewPos, sunVec) * 0.5 + 0.5, 0.001, 1.0);
    NdotS *= NdotS;
    NdotS *= NdotS;

    float absNdotU = abs(NdotU);
    float NdotUp = NdotU;
    float NdotU2 = min(1.0 - NdotU, 1.0);
    NdotU2 = 1.0 - NdotU2 * NdotU2;
    NdotU = 1.0 - NdotU;
    NdotU = pow(NdotU, 2.0 - NdotUp);
    NdotU = max(1.0 - NdotU, 0.0);

    float horizonExponent = 1.5 * (1.0 - NdotS) * sunVisibility4
                            + 3.75;
    float horizon = pow(1.0 - 0.54 * max(NdotUp, 0.0), horizonExponent);
    horizon *= (sunVisibility4 * 0.4 + 0.3) * (1.0 - rainStrengthS * 0.75);

    float timeBrightness4 = 1.0 - timeBrightness;
    timeBrightness4 *= timeBrightness4;
    timeBrightness4 = 1.0 - timeBrightness4 * timeBrightness4;
    
    float lightmix = NdotS * max(1.0 - absNdotU * 2.0, 0.0) * 0.5
                     + horizon * 0.15 * 6.0 + 0.05;
    lightmix *= sunVisibility * (1.0 - rainStrengthS) * (1.0 - timeBrightness4);

    sky = sky * (1.5 + 0.75 * sunVisibility4 + 1.7 * timeBrightness4) * 0.5;
	
	float ground = 0.0;

    #ifndef SKY_REF_FIX_2
        doGround = false;
    #endif
    //doGround = true;
    
    float mult = (0.1 * (1.0 + rainStrengthS) + horizon * (0.65 - 0.2 * timeBrightness4 * (1.0 - rainStrengthS * 5.0)));

	if (doGround == true) {
        float invNdotU = clamp(dot(nViewPos, -upVec), 0.0, 1.0);
        float groundFactor = 0.5 * (11.0 * rainStrengthS + 1.0) * (-5.0 * sunVisibility4 + 6.0);
        ground = exp(-groundFactor / (invNdotU * 6.0));
        ground = smoothstep(0.0, 1.0, ground);
        mult *= (1.0 - ground);
    }
	
	float meFactorP = min((1.0 - min(moonBrightness, 0.6) / 0.6) * 0.115, 0.075);
    vec3 meSkyColor = vec3(0.0);
    if (NdotS > 0.0) {
        float meNdotU = 1.0 - absNdotU;
        float meFactor = meFactorP * meNdotU * meNdotU * 15.0 * (1.0 - rainStrengthS);
        meSkyColor = mix(lightMorning, lightEvening, mefade);
        meSkyColor *= meSkyColor * meSkyColor;
        meSkyColor *= meFactor * meFactor * NdotS;
    }

    sunVisibility4 = pow(sunVisibility4, 1.0 - meFactorP * 10.0);
	
    vec3 finalSky = mix(sky * pow(max(1.0 - lightmix, 0.0), sunVisibility), lightCol * sqrt(lightCol), lightmix) * sunVisibility4;
	if (sunVisibility4 < 1.0) {
        vec3 nightSky = lightNight*lightNight*lightNight * 7.0;
        finalSky+= (1.0 - sunVisibility4) * nightSky * (1.0 + 3.0 * nightVision);
    }

    finalSky *= max(1.0 - length(meSkyColor) * 0.5, 0.0);
    finalSky += meSkyColor * 0.8;
    
    vec3 weatherSky = weatherCol * weatherCol;
    weatherSky *= GetLuminance(ambientCol / (weatherSky)) * 1.4;
    finalSky = mix(finalSky, weatherSky, rainStrengthS) * mult;

    #ifdef LIGHTNING_BOLTS_FIX
        float sunVisF = pow2(1.0 - meFactorP);
        sunVisF *= sunVisF * (1.0 - sunVisibility);
        sunVisF *= sunVisF * min(moonBrightness, 0.5);
        sunVisF *= sunVisF;
        if (rainStrengthS > 0.99) sunVisF = mix(0.001, sunVisF, pow2(1.0 - min(timeBrightness, 0.5)));
        finalSky += pow(length(skyColor), 10.0) * finalSky * 200.0 * (1.0 + NdotU) * sunVisF;
    #endif

    return pow(finalSky, vec3(1.125));
}