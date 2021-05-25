vec3 GetSkyColor(vec3 lightCol, float NdotU, vec3 nViewPos, bool isReflection) {
    float timeBrightnessInv = 1.0 - timeBrightness;
    float timeBrightnessInv2 = timeBrightnessInv * timeBrightnessInv;
    float timeBrightnessInv4 = timeBrightnessInv2 * timeBrightnessInv2;
    float timeBrightnessInv8 = timeBrightnessInv4 * timeBrightnessInv4;

    float NdotSp = clamp(dot(nViewPos, sunVec) * 0.5 + 0.5, 0.001, 1.0);
    float NdotS = NdotSp * NdotSp;
    NdotS *= NdotS;

    float absNdotU = abs(NdotU);

    vec3 skyColor2 = skyColor * skyColor;
    vec3 sky = mix(skyColor * 0.6, skyColor2, absNdotU) * (0.5 + 0.5 * sunVisibility);

    #ifdef ONESEVEN
        sky = vec3(0.812, 0.741, 0.674) * 0.5;
    #endif

    float horizon = 1.0 - max(NdotU + 0.1, 0.0) * (1.0 - 0.25 * NdotS * sunVisibility);
    horizon = min(horizon, 0.9);
    horizon *= horizon;
    
    float lightmix = NdotS * max(1.0 - absNdotU * 2.0, 0.0) * 0.5 + horizon + 0.05;
    lightmix *= sunVisibility * (1.0 - rainStrengthS) * timeBrightnessInv8;

    sky *= 2.0 - 0.5 * timeBrightnessInv4;
    sky *= mix(SKY_NOON, SKY_DAY, timeBrightnessInv4);
    
    float mult = 0.1 * (1.0 + rainStrengthS) + horizon * (0.3 + 0.1 * sunVisibility);
	
	float meFactorP = min((1.0 - min(moonBrightness, 0.6) / 0.6) * 0.115, 0.075);
    float meNdotU = 1.0 - absNdotU;
    float meFactor = meFactorP * meNdotU * meNdotU * 15.0 * (1.0 - rainStrengthS);
    vec3 meColor = mix(lightMorning, lightEvening, mefade);
    meColor *= meColor * meColor;
    meColor *= meFactor * meFactor * NdotS;

    vec3 finalSky = mix(sky * (1.0 - lightmix), lightCol * sqrt(lightCol), lightmix);
    
    vec3 nightSky = ambientNight * ambientNight * (3.5 + 4.5 * max(NdotU, 0.0));
    nightSky *= mix(SKY_NIGHT, 1.0, sunVisibility);
    finalSky += nightSky;

    finalSky *= max(1.0 - length(meColor) * 0.5, 0.0);
    finalSky += meColor * 0.8;
    
	if (isReflection) {
        float invNdotU = max(-NdotU, 0.0);
        float groundFactor = 0.5 * (11.0 * rainStrengthS + 1.0) * (-5.0 * sunVisibility + 6.0);
        float ground = exp(-groundFactor / (invNdotU * 6.0));
        ground = smoothstep(0.0, 1.0, ground);
        mult *= (1.0 - ground);
    }

    vec3 weatherSky = weatherCol * weatherCol;
    weatherSky *= GetLuminance(ambientCol / (weatherSky)) * 1.4;
    weatherSky *= mix(SKY_RAIN_NIGHT, SKY_RAIN_DAY, sunVisibility);
    weatherSky = max(weatherSky, skyColor2 * 0.75);
    finalSky = mix(finalSky, weatherSky, rainStrengthS) * mult;

    return pow(finalSky, vec3(1.125));
}

/*
vec3 GetTestSkyColor(vec3 lightCol, float NdotU, vec3 nViewPos, bool isReflection) {
    float timeBrightnessInv = 1.0 - timeBrightness;
    float timeBrightnessInv2 = timeBrightnessInv * timeBrightnessInv;
    float timeBrightnessInv4 = timeBrightnessInv2 * timeBrightnessInv2;
    float SdotU = dot( sunVec,upVec);
    float SdotUabs = abs(SdotU);
    float invSdotUabs = 1.0 - SdotUabs;
    float invSdotUabs2 = invSdotUabs * invSdotUabs;
    float invSdotUabs4 = invSdotUabs2 * invSdotUabs2;
    float invSdotUabs8 = invSdotUabs4 * invSdotUabs4;
    float invSdotUabsF = smoothstep(0.0, 1.0, invSdotUabs2);
    float invSdotUabsFN = SdotU > 0.0 ? 1.0 : invSdotUabsF;
    float NdotUabs = abs(NdotU);
    float invNdotUabs = 1.0 - NdotUabs;
    float invNdotUabs2 = invNdotUabs * invNdotUabs;
    float invNdotUabs4 = invNdotUabs2 * invNdotUabs2;
    float invNdotUabs8 = invNdotUabs4 * invNdotUabs4;
    float invNdotUabs16 = invNdotUabs8 * invNdotUabs8;
    float invNdotUabsF = smoothstep(0.0, 1.0, invNdotUabs4);
    float NdotS = dot(nViewPos, sunVec);
    float NdotSM = (1.0 + NdotS) * 0.5;
    vec3 sqrtLight = sqrt(lightCol);
    vec3 lightSunset = lightEvening * lightEvening;
         lightSunset *= (1.0 + sunVisibility) * NdotSM * NdotSM * invSdotUabsFN * (timeBrightnessInv4);
    vec3 skyNight = ambientNight * ambientNight * 5.0 + 0.2 * skyColCustom * invSdotUabsFN;

    vec3 topSky = skyColor * skyColor + skyNight;
    topSky *= 0.5 + 2.0 * invNdotUabs2;

    vec3 middleSky = mix(lightCol, lightSunset, length(lightSunset) * 0.8) * 3.0 + skyNight;

    vec3 downSky = skyColor * (1.25 + 1.0 * invNdotUabs2) * lightCol * 1.5 + skyNight * 2.0;

    float NdotUM = 1.0 - invNdotUabs8;
    NdotUM = NdotUM * (1.0 - 2.0 * float(NdotU < 0.0));
    NdotUM = (NdotUM + 1.0) * 0.5;
    vec3 topDownSky = mix(downSky, topSky, NdotUM);

    vec3 finalSky = mix(topDownSky, middleSky, invNdotUabs8 * 0.4);
    

    return finalSky * 0.1;
    //return vec3(1.0, 0.0, 1.0);
}
*/