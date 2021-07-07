uniform sampler2D shadowcolor1;

#include "/lib/vx/voxelPos.glsl"

#if defined SHADOWS && ((defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER && defined OVERWORLD) || defined COLORED_SHADOWS)
	uniform sampler2DShadow shadowtex1;
#endif

#if (defined OVERWORLD || defined END || defined SEVEN) && defined SHADOWS
	#include "/lib/lighting/shadows.glsl"

	vec3 DistortShadow(inout vec3 worldPos, float distortFactor) {
		worldPos.xy /= distortFactor;
		worldPos.z *= 0.2;
		return worldPos * 0.5 + 0.5;
	}
#endif

#if defined WATER_CAUSTICS && defined OVERWORLD
	#include "/lib/lighting/caustics.glsl"
#endif

float GetFakeShadow(float skyLight) {
	float fakeShadow = 0.0;

	#ifndef END
		if (isEyeInWater == 0) skyLight = pow(skyLight, 30.0);
		fakeShadow = skyLight;
	#else
		#ifdef SHADOWS
			fakeShadow = 1.0;
		#else
			fakeShadow = 0.0;
		#endif
	#endif

	return fakeShadow;
}
#ifndef GBUFFERS_TERRAIN
	void GetLighting(inout vec3 albedo, inout vec3 shadow, inout vec3 lightAlbedo, vec3 viewPos, float lViewPos, vec3 worldPos,
                 vec2 lightmap, float smoothLighting, float NdotL, float quarterNdotU,
                 float parallaxShadow, float emissive, float subsurface, float leaves, float materialAO) {
#else
	void GetLighting(inout vec3 albedo, inout vec3 shadow, inout vec3 lightAlbedo, vec3 viewPos, float lViewPos, vec3 worldPos,
                 vec2 lightmap, float smoothLighting, float NdotL, float quarterNdotU,
                 float parallaxShadow, float emissive, float subsurface, float leaves, float materialAO, vec3 newNormal) {
#endif
	vec3 voxelSpacePos = worldPos + fract(cameraPosition);
	#ifndef GBUFFERS_TERRAIN
		vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * normal);
	#else
		vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * newNormal);
	#endif
	vec3 worldSunVec = mat3(gbufferModelViewInverse) *sunVec;
	vec3 fullShadow = vec3(0.0);
	float fullShadow1 = 0.0;
	float fakeShadow = 0.0;
	float shadowMult = 1.0;
	float shadowTime = 1.0;
	float water = 0.0;

	#ifdef PIXEL_SHADOWS
		float shadowPixel = 16.0;
		worldPos = floor((worldPos + cameraPosition) * shadowPixel + 0.001) / shadowPixel - cameraPosition + 0.5 / shadowPixel;
	#endif

    #if defined OVERWORLD || defined END || defined SEVEN
		#ifdef SHADOWS
			if ((NdotL > 0.0 || subsurface > 0.001)) {
				float shadowLengthX = length(worldPos.xy);
				float shadowLengthZ = length(worldPos.yz);
				float shadowLength = shadowDistance - max(shadowLengthX, shadowLengthZ) - shadowDistance / 12.0;

				#if (defined OVERWORLD || defined SEVEN) && defined LIGHT_LEAK_FIX
					if (isEyeInWater == 0) shadowLength *= float(lightmap.y > 0.001);
				#endif

				if (shadowLength > 0.000001) {
					vec3 shadowPos = ToShadow(worldPos);
					float distb = length(shadowPos.xy);
					float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
					shadowPos = DistortShadow(shadowPos, distortFactor);

					#ifdef NORMAL_MAPPING
						float NdotLm = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0) * 0.99 + 0.01;
						NdotL = min(NdotL, NdotLm);
					#else
						float NdotLm = NdotL * 0.99 + 0.01;
					#endif

					float dotWorldPos = dot(worldPos.xyz, worldPos.xyz);
					
					float biasFactor = sqrt(1.0 - NdotLm * NdotLm) / NdotLm;
					float distortBias = distortFactor * shadowDistance / 256.0;
					distortBias *= 8.0 * distortBias;
					
					float bias = (distortBias * biasFactor + dotWorldPos * 0.000005 + 0.05) / shadowMapResolution;
					float offset = 1.0 / shadowMapResolution;

					if (subsurface > 0.001) {
						bias = 0.0002;
						offset = 0.002;
					}
					if (isEyeInWater == 1) offset *= 5.0;

					#ifdef PIXEL_SHADOWS
						bias += 0.0025 / shadowPixel;
					#endif

					shadowPos.z -= bias;
					shadow = GetShadow(shadowPos, offset, water);

					#if defined PROJECTED_CAUSTICS && defined WATER_CAUSTICS && defined OVERWORLD && !defined GBUFFERS_WATER
						shadowPos.xy *= 0.5;
						if (isEyeInWater == 0) {
							water = float(water > 0.99);
							water *= NdotL;
							float shadowSum = (shadow.r + shadow.g + shadow.b) / 3.0;
							water *= pow2(1.0 - shadowSum);
						}
					#endif
				} else {
					//albedo.rgb *= 0.0;
				}
				float shadowLength2 = shadowLength;
				float shadowSmooth = 16.0;
				if (shadowLength2 < shadowSmooth) {
					float shadowLengthDecider = max(shadowLength2 / shadowSmooth, 0.0);
					float skyLightShadow = GetFakeShadow(lightmap.y);
					shadow = mix(vec3(skyLightShadow), shadow, shadowLengthDecider);
					subsurface *= mix(subsurface * 0.5, subsurface, shadowLengthDecider);
					fakeShadow = mix(1.0, fakeShadow, shadowLengthDecider);
					fakeShadow = 1.0 - fakeShadow;
					fakeShadow *= fakeShadow;
					fakeShadow = 1.0 - fakeShadow;
				}
			}
		#else
			shadow = vec3(GetFakeShadow(lightmap.y));
		#endif
		
		#if defined CLOUD_SHADOW && defined OVERWORLD
			float cloudSize = 0.000025;
			vec2 wind = vec2(frametime, 0.0) * CLOUD_SPEED * 6.0;
			float cloudShadow = texture2D(noisetex, cloudSize * (wind + (worldPos.xz + cameraPosition.xz))).r;
			cloudShadow += texture2D(noisetex, cloudSize * (vec2(1000.0) + wind + (worldPos.xz + cameraPosition.xz))).r;
			cloudShadow = clamp(cloudShadow, 0.0, 1.0);
			cloudShadow *= cloudShadow;
			cloudShadow *= cloudShadow;
			shadow *= cloudShadow;
		#endif

		#ifdef ADV_MAT
			#ifdef SELF_SHADOW
				float shadowNdotL = min(NdotL + 0.5, 1.0);
				shadowNdotL *= shadowNdotL;
				shadow *= mix(1.0, parallaxShadow, shadowNdotL);
			#endif
		#endif

		fullShadow = shadow * max(NdotL, subsurface * (1.0 - max(rainStrengthS, (1.0 - sunVisibility)) * 0.40));

		fullShadow1 = (fullShadow.r + fullShadow.g + fullShadow.b) / 3.0;

		#ifdef ADV_MAT
			shadow *= float(fullShadow1 > 0.01);
		#endif

		#if defined OVERWORLD && !defined TWO
			shadowMult = 1.0 * (1.0 - 0.9 * rainStrengthS);

			shadowTime = abs(sunVisibility - 0.5) * 2.0;
			shadowTime *= shadowTime;
			shadowMult *= shadowTime * shadowTime;

			#ifndef LIGHT_LEAK_FIX
				ambientCol *= pow(lightmap.y, 2.5);
			#else
				if (isEyeInWater == 1) ambientCol *= pow(lightmap.y, 2.5);
			#endif
			
			vec3 lightingCol = pow(lightCol, vec3(1.0 + sunVisibility));
			#ifdef SHADOWS
				lightingCol *= (1.0 + 0.5 * leaves);
			#else
				lightingCol *= (1.0 + 0.4 * leaves);
			#endif
			vec3 shadowDecider = fullShadow * shadowMult;
			if (isEyeInWater == 1) shadowDecider *= pow(min(lightmap.y * 1.03, 1.0), 200.0);
			vec3 sceneLighting = mix(ambientCol * AMBIENT_GROUND, lightingCol * LIGHT_GROUND, shadowDecider);

			#ifdef LIGHT_LEAK_FIX
				if (isEyeInWater == 0) sceneLighting *= pow(lightmap.y, 2.5);
			#endif
		#endif

		#ifdef END
			vec3 ambientEnd = endCol * 0.07;
			vec3 lightEnd   = endCol * 0.17;
			vec3 shadowDecider = fullShadow;
			vec3 sceneLighting = mix(ambientEnd, lightEnd, shadowDecider);
			sceneLighting *= END_I * (0.7 + 0.4 * vsBrightness);
		#endif

		#ifdef TWO
			#ifndef ABYSS
				vec3 sceneLighting = vec3(0.0003, 0.0004, 0.002) * 10.0;
			#else
				vec3 sceneLighting = pow(fogColor, vec3(0.2)) * 0.125;
			#endif
		#endif
		
		#if defined SEVEN && !defined SEVEN_2
			sceneLighting = vec3(0.005, 0.006, 0.018) * 133 * (0.3 * fullShadow + vec3(0.025));
		#endif
		#ifdef SEVEN_2
			vec3 sceneLighting = vec3(0.005, 0.006, 0.018) * 33 * (1.0 * fullShadow + vec3(0.025));
		#endif
		#if defined SEVEN || defined SEVEN_2
			sceneLighting *= lightmap.y * lightmap.y;
		#endif
		
		#if defined SHADOWS && defined OVERWORLD
			if (subsurface > 0.001) {
				float VdotL = clamp(dot(normalize(viewPos.xyz), lightVec), 0.0, 1.0);
				//sceneLighting *= 5.0 * (1.0 - fakeShadow) * shadowTime * fullShadow * (1.0 + leaves) * pow(VdotL, 10.0) + vec3(1.0);
				
				vec3 subsurfaceGlow = (5.5 + 22.0 * leaves) * (1.0 - fakeShadow) * shadowTime * fullShadow * pow(VdotL, 10.0);
				albedo.rgb += albedo.g * normalize(sqrt(albedo.rgb * lightCol)) * subsurfaceGlow;
			}
		#endif
    #else
		#ifdef NETHER
			#if MC_VERSION <= 11600
			#else
				if (quarterNdotU < 0.5625) quarterNdotU = 0.5625 + (0.4 - quarterNdotU * 0.7111111111111111);
			#endif
		
			vec3 sceneLighting = netherCol * (1 - pow(length(fogColor / 3), 0.25)) * NETHER_I * (vsBrightness*0.5 + 0.5);
		#else
			vec3 sceneLighting = vec3(0.0);
		#endif
    #endif

	float finalHandLight = 0;
	#ifdef DYNAMIC_SHADER_LIGHT
		float handLight = min(float(heldBlockLightValue2 + heldBlockLightValue), 15.0) / 15.0;

		if (heldItemId == 12001 || heldItemId2 == 12001) // Lava Bucket
			#if defined GBUFFERS_HAND && defined COMPBR
				handLight = 0.87, emissive = max(albedo.r * 2.0 - albedo.g - albedo.b, 0.0) * 0.5;
			#else
				handLight = 1.0;
			#endif
		if (heldItemId == 12002 || heldItemId2 == 12002) // Optifine Item Emissives
			handLight = min(handLight + 0.5, 1.0);

		float handLightFactor = 1.0 - min(DYNAMIC_LIGHT_DISTANCE * handLight, lViewPos) / (DYNAMIC_LIGHT_DISTANCE * handLight);
		#ifdef GBUFFERS_WATER
			if (mat > 0.05) handLight *= 0.9;
		#endif
		#ifdef GBUFFERS_HAND
			handLight = min(handLight, 0.95);
		#endif
		finalHandLight = handLight * handLightFactor;
		lightmap.x = max(finalHandLight * 0.95, lightmap.x);
	#endif

	float newLightmap  = pow(lightmap.x, 10.0) * 5 + max((lightmap.x - 0.05) * 0.925, 0.0) * (vsBrightness*0.25 + 0.9);

	#ifdef BLOCKLIGHT_FLICKER
		float frametimeM = frametime * 0.5;
		float lightFlicker = min(((1 - clamp(sin(fract(frametimeM*2.7) + frametimeM*3.7) - 0.75, 0.0, 0.25) * BLOCKLIGHT_FLICKER_STRENGTH)
					* max(fract(frametimeM*1.4), (1 - BLOCKLIGHT_FLICKER_STRENGTH * 0.25))) / (1.0 - BLOCKLIGHT_FLICKER_STRENGTH * 0.2)
					, 0.8) * 1.25
					* 0.8 + 0.2 * clamp((cos(fract(frametimeM*0.47) * fract(frametimeM*1.17) + fract(frametimeM*2.17))) * 1.5, 1.0 - BLOCKLIGHT_FLICKER_STRENGTH * 0.25, 1.0);
		newLightmap *= lightFlicker;
	#endif

	#if defined GBUFFERS_ENTITIES || defined GBUFFERS_BLOCK
		worldNormal = vec3(0);
	#endif
	vec3 blockLighting = vec3(0);
	#if (defined OVERWORLD || defined NETHER || defined END) && !defined GBUFFERS_BEACONBEAM
	float border = (max(max(abs(worldPos.x), abs(worldPos.z)) - 0.0625 / VXHEIGHT * shadowMapResolution, abs(worldPos.y) - 24 * pow2(VXHEIGHT)) + 5) * 0.2;
	if (border < 1) {
		voxelSpacePos += worldNormal;
		float floorVxSpacePosY = floor(voxelSpacePos.y + 0.51);
		vec3[2] voxelPos0 = getVoxelPos(vec3(voxelSpacePos.x, floorVxSpacePosY - 0.01, voxelSpacePos.z));
		vec3 blockLightCol0 = texture2D(shadowcolor1, voxelPos0[0].xz / shadowMapResolution + vec2(0.5)).rgb;// * float(abs(voxelPos0[0].x / shadowMapResolution) < 0.5 && abs(voxelPos0[0].z / shadowMapResolution) < 0.5);
		vec3[2] voxelPos1 = getVoxelPos(vec3(voxelSpacePos.x, floorVxSpacePosY + 0.99, voxelSpacePos.z));
		vec3 blockLightCol1 = texture2D(shadowcolor1, voxelPos1[0].xz / shadowMapResolution + vec2(0.5)).rgb;// * float(abs(voxelPos1[0].x / shadowMapResolution) < 0.5 && abs(voxelPos1[0].z / shadowMapResolution) < 0.5);
		blockLighting = mix(blockLightCol0, blockLightCol1, voxelSpacePos.y + 0.51 - floorVxSpacePosY);
		blockLighting = pow(blockLighting, vec3(1.5));
		vec3 blockLighting0 = BLOCKLIGHT_I * vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B) * newLightmap * newLightmap * 0.5 / 255.0;
		blockLighting = mix(blockLighting, blockLighting0, clamp(border, 0, 1));
		float blockLightBrightness = max(max(blockLighting.r, blockLighting.g), blockLighting.b);
		finalHandLight *= finalHandLight * BLOCKLIGHT_I;
		finalHandLight = max(finalHandLight, 0.0);
		blockLighting = max(blockLightBrightness, finalHandLight) * mix(blockLighting / (blockLightBrightness + 0.0001), vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B) / max(BLOCKLIGHT_R * 1.0, max(BLOCKLIGHT_G * 1.0, BLOCKLIGHT_B * 1.0)), finalHandLight / (finalHandLight + blockLightBrightness + 0.0001));
	}else{
	#endif
	
	#ifdef GBUFFERS_BEACONBEAM
		blockLighting = vec3(1.0);
	#else
		blockLighting = BLOCKLIGHT_I * vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B) * newLightmap * newLightmap * 0.5/255.0;
	#endif
	#if defined OVERWORLD || defined NETHER || defined END
	}
	#endif

	#ifndef MIN_LIGHT_EVERYWHERE
		float minLighting = 0.000000000001 + (MIN_LIGHT * 0.0035 * (vsBrightness*0.08 + 0.01)) * (1.0 - eBS);
	#else
		float minLighting = 0.000000000001 + (MIN_LIGHT * 0.0035 * (vsBrightness*0.08 + 0.01));
	#endif
	#ifdef GBUFFERS_WATER
		minLighting += MIN_LIGHT * 0.0035 * (vsBrightness*0.08 + 0.01);
	#endif
	
	float shade = pow(quarterNdotU, SHADING_STRENGTH);

	vec3 emissiveLighting = albedo.rgb * emissive * 20.0 / shade;

    float nightVisionLighting = nightVision * 0.25;

	smoothLighting = clamp(smoothLighting, 0.0, 1.0);
	smoothLighting = pow(smoothLighting, 
						(2.0 - min(length(fullShadow * shadowMult), 1.5)) * VAO_STRENGTH
						);

	if (materialAO < 1.0) {
		smoothLighting *= pow(materialAO, max(1.0 - shadowTime * length(shadow) * NdotL - lmCoord.x, 0.0));
	}

    albedo *= sceneLighting + blockLighting + emissiveLighting + nightVisionLighting + minLighting;
	albedo *= shade;
	if (smoothLighting > 0.01) albedo *= smoothLighting;

	#if defined WATER_CAUSTICS && defined OVERWORLD
		#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
		if (water > 0.0 || isEyeInWater == 1) {
		#else
		if (isEyeInWater == 1) {
		#endif
			vec3 albedoCaustic = albedo;

			float skyLightMap = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
			
			float causticfactor = 1.0 - lightmap.x * 0.8;

			vec3 causticpos = worldPos.xyz + cameraPosition.xyz;
			float caustic = getCausticWaves(causticpos * 0.75);
			vec3 causticcol = underwaterColor.rgb / UNDERWATER_I;
			
			#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
				if (isEyeInWater == 0) {
					//causticfactor *= (1.0 - skyLightMap * skyLightMap);
					causticfactor *= 1.0 - pow2(pow2((1.0 - skyLightMap)));
					causticfactor *= 10.0;

					causticcol *= causticcol;
					causticcol *= causticcol;
					albedoCaustic = albedo.rgb * mix(underwaterColor.rgb * 20.0, causticcol * 1000.0, sunVisibility);
					causticcol *= 150.0;
				} else {
			#endif
					causticfactor *= shadow.g * NdotL * (1.0 - rainStrengthS);
					causticfactor *= 0.25 - 0.15 * pow2(pow2((1.0 - skyLightMap)));
					if (skyLightMap > 0.98) causticfactor *= (1.0 - skyLightMap) * 50.0;

					albedoCaustic = (albedo.rgb + albedo.rgb * underwaterColor.rgb * 16.0) * 0.225;
					causticcol = sqrt(causticcol) * 30.0;
			#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
				}
			#endif

			vec3 lightcaustic = caustic * causticfactor * causticcol * UNDERWATER_I;
			albedoCaustic *= 1.0 + lightcaustic;

			#if defined PROJECTED_CAUSTICS && !defined GBUFFERS_WATER
				if (isEyeInWater == 0) albedo = mix(albedo, albedoCaustic, max(water - rainStrengthS, 0.0));
				else albedo = albedoCaustic;
			#else
				albedo = albedoCaustic;
			#endif
		}
	#endif

	#if defined GBUFFERS_HAND && defined HAND_BLOOM_REDUCTION
		float albedoStrength = (albedo.r + albedo.g + albedo.b) / 10.0;
		if (albedoStrength > 1.0) albedo.rgb = albedo.rgb * max(2.0 - albedoStrength, 0.34);
	#endif

	//if (water > 0.0) albedo = vec3(1.0, 0.0, 1.0);
}