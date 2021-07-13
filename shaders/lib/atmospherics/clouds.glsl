#if !defined END && !defined SEVEN && !defined NETHER

	float CloudNoise(vec2 coord, vec2 wind) {
		float noise = texture2D(noisetex, coord*0.125    + wind * 0.25).x * 7.0;
			  noise+= texture2D(noisetex, coord*0.0625   + wind * 0.15).x * 12.0;
			  noise+= texture2D(noisetex, coord*0.03125  + wind * 0.05).x * 12.0;
			  noise+= texture2D(noisetex, coord*0.015625 + wind * 0.05).x * 24.0;
		return noise*0.34;
	}

	float CloudCoverage(float noise, float coverage, float NdotU, float cosS) {
		float noiseCoverageCosS = abs(cosS);
		noiseCoverageCosS *= noiseCoverageCosS;
		noiseCoverageCosS *= noiseCoverageCosS;
		float NdotUmult = 0.365;
		#ifdef AURORA
			float auroraMult = max(1.0 - sunVisibility - rainStrengthS, 0.0);
			#ifdef AURORA_BIOME_CHECK
				auroraMult *= isSnowy;
			#endif
			#ifdef AURORA_FULL_MOON_CHECK
				auroraMult *= float(moonPhase == 0);
			#endif
			NdotUmult *= 1.0 + 2.5 * auroraMult;
		#endif
		float noiseCoverage = coverage * coverage + CLOUD_AMOUNT
								* (1.0 + noiseCoverageCosS * 0.175) 
								* (1.0 + NdotU * NdotUmult * (1.0-rainStrengthS*3.0))
								- 2.5;

		return max(noise - noiseCoverage, 0.0);
	}

	vec4 DrawCloud(vec3 viewPos, float dither, vec3 lightCol, vec3 ambientCol, float NdotU, int sampleCount) {
		float cosS = dot(normalize(viewPos), sunVec);
		
		#if AA > 1
			dither = fract(16.0 * frameTimeCounter + dither);
		#endif

		float timeBrightnessS = sqrt1(timeBrightness);
		
		float cloud = 0.0;
		float cloudGradient = 0.0;
		float gradientMix = dither * 0.1667;
		float colorMultiplier = CLOUD_BRIGHTNESS * (0.23 + 0.07 * timeBrightnessS);
		float noiseMultiplier = CLOUD_THICKNESS * 0.125;
		#ifdef VANILLAEY_CLOUDS
			noiseMultiplier *= 1.5;
		#endif
		float scattering = 0.5 * pow(cosS * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 6.0);

		float cloudHeightFactor = max(1.07 - 0.001 * eyeAltitude, 0.0);
		cloudHeightFactor *= cloudHeightFactor;
		float cloudHeight = CLOUD_HEIGHT * cloudHeightFactor * 0.5;

		#if !defined GBUFFERS_WATER && !defined DEFERRED
			float cloudframetime = frametime;
		#else
			float cloudframetime = cloudtime;
		#endif
		float cloudSpeedFactor = 0.003;
		vec2 wind = vec2(cloudframetime * CLOUD_SPEED * cloudSpeedFactor, 0.0);
		#ifdef SEVEN
			wind *= 8;
		#endif

		vec3 cloudcolor = vec3(0.0);

		float stretchFactor = 2.5;
		float coordFactor = 0.009375;

		if (NdotU > 0.025) {
			vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
			for(int i = 0; i < sampleCount; i++) {
				if (cloud > 0.99) break;
				vec2 planeCoord = wpos.xz * ((cloudHeight + (i + dither) * stretchFactor * 6.0 / sampleCount) / wpos.y) * 0.0085;
				vec2 coord = cameraPosition.xz * 0.00025 + planeCoord;
				
				float coverage = float(i - 3.0 + dither) * 0.725;

				#ifndef VANILLAEY_CLOUDS
				float ang1 = (i + frametime * 0.025) * 2.391;
				float ang2 = ang1 + 2.391;
				coord += mix(vec2(cos(ang1), sin(ang1)), vec2(cos(ang2), sin(ang2)), dither * 0.25 + 0.75) * coordFactor;

				float noise = CloudNoise(coord, wind);
					  noise = CloudCoverage(noise, coverage, NdotU, cosS) * noiseMultiplier;
					  noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);
				#else
				coord += 0.02 * (texture2D(noisetex, fract(coord * 1000 + vec2(sin(dither), cos(dither)))).rg - 0.5);
				float noise = CloudNoise(VANILLA_CLOUD_SIZE / 5.0 * floor(coord * 5.0 / VANILLA_CLOUD_SIZE - wind * 10), vec2(0.0));
					//noise = clamp(100 * noise - 50, 0.0, 2.0);
					noise = CloudCoverage(noise, coverage, NdotU, cosS) * noiseMultiplier;
					noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);
				#endif
				
				cloudGradient = mix(cloudGradient,
									mix(gradientMix * gradientMix, 1.0 - noise, 0.25),
									noise * (1.0 - cloud));
				//cloud = mix(cloud, 1.0, noise);
				cloud += max(noise - cloud * 0.95, 0.0);
				gradientMix += 0.2 * (6.0 / sampleCount);
			}

			float meFactorP = min((1.0 - min(moonBrightness, 0.6) / 0.6) * 0.115, 0.075);
			vec3 meColor = vec3(0.0);
			if (cosS > 0.0) {
				float meNdotU = 1.0 - NdotU;
				float meFactor = meFactorP * meNdotU * meNdotU * 12.0 * (1.0 - rainStrengthS);
				meColor = mix(lightMorning, lightEvening, mefade);
				meColor *= meColor * meColor;
				meColor *= meFactor * meFactor * cosS;
			}

			float sunVisibility2 = sunVisibility * sunVisibility;
			float sunVisibility4 = sunVisibility2 * sunVisibility2;

			sunVisibility4 = pow(sunVisibility4, 1.0 - meFactorP * 6.0);

			vec3 cloudNightColor = ambientCol * 10.0;
			vec3 cloudDayColor = pow(lightCol, vec3(1.5 + rainStrengthS)) * 1.5;

			vec3 cloudUpColor = mix(cloudNightColor, cloudDayColor, sunVisibility4);
			cloudUpColor *= 1.0 + scattering * (1.0 + pow2(rainStrengthS) * 4.0);
			cloudUpColor += max(meColor, vec3(0.0));

			vec3 cloudDownColor = skyColCustom * 0.175 * sunVisibility4;
			cloudcolor = mix(cloudDownColor, cloudUpColor, cloudGradient);

			cloud *= pow2(pow2(1.0 - exp(- (10.0 - 8.2 * rainStrengthS) * NdotU)));
		}

		return vec4(cloudcolor * colorMultiplier, cloud * CLOUD_OPACITY);
	}

	#ifdef VANILLAEY_CLOUDS
	vec4 DrawVanillaCloud(vec3 viewPos, float dither, vec3 lightCol, vec3 ambientCol, float NdotU, vec3 lightVec) {
		lightVec = normalize((gbufferModelViewInverse * vec4(lightVec, 1.0)).xyz);
		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		vec2 cloudStep = - (mod(cameraPosition.xz, 12) - 12 * vec2(wpos.x < 0, wpos.z < 0)) / wpos.xz;
		vec4 cloudColor = vec4(0);
		float cloudDist = max((128 - cameraPosition.y) / wpos.y, 0);
		float cloudDist1 = max((132 - cameraPosition.y) / wpos.y, 0);
		float cloudDist0 = min(cloudDist, cloudDist1);
		cloudDist1 = max(cloudDist, cloudDist1);
		cloudDist = cloudDist0;
		//cloudStep += floor(cloudDist) / (12 * wpos.xz);
		float dist = 0;
		cloudColor.rgb = 2.5 * ambientCol;
		while (cloudDist < min(cloudDist1 + 0.01, 256) && cloudDist > -1000){
			vec3 cloudPos = cameraPosition + wpos * cloudDist;
			vec2 cloudStepNext = min(cloudStep + 12 / abs(wpos.xz) * vec2(cloudStep.x <= cloudStep.y || cloudStep.x < cloudDist0, cloudStep.x >= 
			cloudStep.y || cloudStep.y < cloudDist0), vec2(cloudDist1 + 0.01));
			float cloudDistNext = min(cloudStepNext.x, cloudStepNext.y);
			if(cloudDist < cloudDist0 && cloudDistNext > cloudDist0) {
				cloudDist = cloudDist0;
			}
			if(cloudDist > cloudDist0 - 0.01 && abs(cloudPos.y - 130) < 2.01) {
				vec2 noiseCoord = (floor(cloudPos.xz / 12.0 + 0.0001 * wpos.xz) + 0.5) / 512.0;
				vec4 noiseColor = texture2D(noisetex, fract(noiseCoord));
				vec3 cloudPosNext = cameraPosition + wpos * cloudDistNext;
				vec2 noiseCoordNext = (floor(cloudPosNext.xz / 12.0 + 0.0001 * wpos.xz) + 0.5) / 512.0;
				vec4 noiseColorNext = texture2D(noisetex, fract(noiseCoordNext));
				float localDist = max(cloudDistNext - cloudDist, 0);
				if(noiseColor.r > (CLOUD_AMOUNT - 5.0) / 10.0) {
					vec3 cloudInnerPos = fract((cloudPos + 0.0001 * wpos) / vec3(12.0, 4.0, 12.0));
					cloudInnerPos -= 0.5;
					cloudInnerPos *= 2;
					cloudInnerPos *= pow(abs(cloudInnerPos), vec3(4));
					cloudColor.rgb += max(lightCol * max(cloudInnerPos.x * lightVec.x, max(cloudInnerPos.y * lightVec.y, cloudInnerPos.z * lightVec.z)), vec3(0));
					dist += localDist;
				}
			}
			cloudStep = cloudStepNext;
			cloudDist = cloudDistNext;
		}
		cloudColor.a = 1 - exp(-dist * 0.3);
		return cloudColor;
	}
	#endif

	#ifdef AURORA

		float AuroraNoise(vec2 coord, vec2 wind) {
			float noise = texture2D(noisetex, coord * 0.175   + wind * 0.25).x;
				  noise+= texture2D(noisetex, coord * 0.04375 + wind * 0.15).x * 5.0;

			return noise;
		}

		vec3 DrawAurora(vec3 viewPos, float dither, int sampleCount, float NdotU) {
			#if AA > 1
				dither = fract(16.0 * frameTimeCounter + dither);
			#endif
			
			float gradientMix = dither / sampleCount;
			float visibility = (1.0 - sunVisibility) * (1.0 - rainStrengthS);
			visibility *= visibility;

			#ifdef AURORA_BIOME_CHECK
				visibility *= isSnowy;
			#endif
			#ifdef AURORA_FULL_MOON_CHECK
				visibility *= float(moonPhase == 0);
			#endif

			#if !defined GBUFFERS_WATER && !defined DEFERRED
				float cloudframetime = frametime;
			#else
				float cloudframetime = cloudtime;
			#endif

			vec2 wind = vec2(cloudframetime * 0.00005);

			vec3 aurora = vec3(0.0);

			float NdotUM = min(1.08 - NdotU, 1.0);
			NdotUM *= NdotUM;
			NdotUM = 1.0 - NdotUM * NdotUM;		

			if (NdotU > 0.0 && visibility > 0.0) {
				vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
				for(int i = 0; i < sampleCount; i++) {
					vec2 planeCoord = wpos.xz * ((8.0 * AURORA_HEIGHT + (i + dither) * 7.0 / sampleCount) / wpos.y) * 0.004;
					vec2 coord = cameraPosition.xz * 0.00001 + planeCoord;

					float noise = AuroraNoise(coord, wind);
						noise = max(1.0 - 1.5 / (1.0 - NdotU * 0.8) * abs(noise - 3.0), 0.0);

					if (noise > 0.0) {
						noise *= texture2D(noisetex, coord * 0.25 + wind * 0.25).x;
						noise *= 0.5 * texture2D(noisetex, coord + wind * 16.0).x + 0.75;
						noise = noise * noise * 3.0 / sampleCount;
						noise *= NdotUM;

						vec3 auroracolor = mix(
										auroraDCol,
										auroraUCol,
										pow(gradientMix, 0.4));

						aurora += noise * auroracolor * exp2(-6.0 * i / sampleCount);
					}
					gradientMix += 1.0 / sampleCount;
				}
			}

			aurora = aurora * visibility * 1.5;

			return aurora;
		}
	#endif
#endif

#ifdef SEVEN

	float GetNoise(vec2 pos) {
		return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
	}

	vec3 DrawStars(inout vec3 color, vec3 viewPos, float NdotU) {
		vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos, 1.0));
		vec3 planeCoord = 0.75 * wpos / (wpos.y + length(wpos.xz));
		vec2 wind = 0.75 * vec2(frametime, 0.0);
		#ifdef SEVEN
			wind = vec2(0.0);
		#endif
		vec2 coord = planeCoord.xz * 0.5 + wind * 0.00125;
		coord = floor(coord*1024.0) / 1024.0;
		
		float multiplier = 5.0 * (1.0 - rainStrengthS) * (1 - (sunVisibility*0.9 + pow(timeBrightness, 0.05)*0.1)) * pow(NdotU, 2.0);
		
		#ifdef SEVEN
			multiplier = sqrt2(NdotU) * 5.0 * (1.0 - rainStrengthS);	
		#endif
		
		float star = 1.0;
		if (NdotU > 0.0) {
			star *= GetNoise(coord.xy);
			star *= GetNoise(coord.xy+0.1);
			star *= GetNoise(coord.xy+0.23);
		}
		star = max(star - 0.825, 0.0) * multiplier;
		
		vec3 stars = star * lightNight * lightNight * 160;

		return vec3(stars);
	}
#endif

#if defined END && defined ENDER_NEBULA

	float CloudCoverageEnd(float noise, float cosT, float coverage) {
		float noiseMix = mix(noise, 21.0, 0.33 * rainStrengthS);
		float noiseFade = clamp(sqrt(cosT * 10.0), 0.0, 1.0);
		float noiseCoverage = ((coverage) + CLOUD_AMOUNT - 2);
		float multiplier = 1.0 - 0.5 * rainStrengthS;

		return max(noiseMix * noiseFade - noiseCoverage, 0.0) * multiplier;
	}

	float CloudNoiseEnd(vec2 coord, vec2 wind) {
		float noise = texture2D(noisetex, coord          + wind * 0.55).x;
			  noise+= texture2D(noisetex, coord*0.5      + wind * 0.45).x * -2.0;
			  noise+= texture2D(noisetex, coord*0.25     + wind * 0.35).x * 2.0;
			  noise+= texture2D(noisetex, coord*0.125    + wind * 0.25).x * -5.0;
			  noise+= texture2D(noisetex, coord*0.0625   + wind * 0.15).x * 20.0;
			  noise+= texture2D(noisetex, coord*0.03125  + wind * 0.05).x * 20.0;
			  noise+= texture2D(noisetex, coord*0.015625 + wind * 0.05).x * -15.0;
		return noise;
	}

	float GetNebulaStarNoise(vec2 pos) {
		return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
	}

	float NebulaNoise(vec2 coord, vec2 wind) {
		float noise = texture2D(noisetex, coord * 0.175   + wind * 0.25).x;
			  noise+= texture2D(noisetex, coord * 0.04375 + wind * 0.15).x * 5.0;

		return noise;
	}

	vec4 DrawEnderNebula(vec3 viewPos, float dither, vec3 lightCol, bool stars) { // Ender Nebula
		float NdotU = dot(normalize(viewPos), upVec);
		float cosS = dot(normalize(viewPos), sunVec);
		cosS *= cosS;
		cosS *= cosS;
		cosS *= cosS;

		#if AA > 1
			dither = fract(16.0 * frameTimeCounter + dither);
		#endif

		int sampleCount = 20;
		
		float gradientMix = dither / sampleCount;

		#if !defined GBUFFERS_WATER && !defined DEFERRED
			float cloudframetime = frametime;
		#else
			float cloudframetime = cloudtime;
		#endif

		vec2 wind = vec2(cloudframetime * 0.000035);

		vec3 aurora = vec3(0.0);

		float NdotUM = abs(NdotU);
		NdotUM = 1.0 - NdotUM;
		NdotUM = pow(NdotUM, (2.0 - NdotUM) * (NEBULA_DISTRIBUTION - 0.8)) * 0.85;
		float compression = pow(NdotUM, NEBULA_COMPRESSION);
		dither *= NEBULA_SMOOTHING;

		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos * 1000.0, 1.0)).xyz);
		for(int i = 0; i < sampleCount; i++) {
			vec2 planeCoord = wpos.xz * (1.0 + (i + dither) * compression * 6.0 / sampleCount) * NEBULA_SIZE;
			vec2 coord = planeCoord + cameraPosition.xz * 0.00004;

			float noise = NebulaNoise(coord, wind);
					noise = max(0.75 - 1.0 / abs(noise - (4.0 + NdotUM * 2.0)), 0.0) * 3.0;

			if (noise > 0.0) {
				noise *= texture2D(noisetex, abs(coord * 0.25) + wind * 4.0).x;
				float fireNoise = texture2D(noisetex, abs(coord * 0.2) + wind * 8.0).x;
				noise *= 0.5 * fireNoise + 0.75;
				noise = noise * noise * 3.0 / sampleCount;
				noise *= NdotUM;

				vec3 auroracolor = 12.0 * lightCol * NEBULA_PURPLE_BRIGHTNESS;
				auroracolor += vec3(1.0, 0.25, 0.0) * NEBULA_ORANGE_BRIGHTNESS * 4.0 * pow(fireNoise, 5.0);
				auroracolor *= gradientMix;

				aurora += noise * auroracolor * exp2(-6.0 * i / sampleCount);
			}
			gradientMix += 1.0 / sampleCount;
		}

		if (stars) {
			vec3 starCoord = 0.75 * wpos / (abs(wpos.y) + length(wpos.xz));
			vec2 starCoord2 = starCoord.xz * 0.7;
			if (NdotU < 0.0) starCoord2 += 100.0;
			float starFactor = 1024.0;
			starCoord2 = floor(starCoord2 * starFactor) / starFactor;
			float star = 1.0;
			star *= GetNebulaStarNoise(starCoord2.xy);
			star *= GetNebulaStarNoise(starCoord2.xy+0.1);
			star *= GetNebulaStarNoise(starCoord2.xy+0.23);
			star = max(star - 0.825, 0.0);
			aurora += star * lightCol * 80.0 * (1.0 - NdotUM) * NEBULA_STAR_BRIGHTNESS;
		}

		return vec4(aurora * 2.0, 1.0);
	}
#endif

#if defined NETHER && defined NETHER_SMOKE
		float NebulaNoise(vec2 coord, vec2 wind) {
			float noise = texture2D(noisetex, coord * 0.175   + wind * 0.25).x;
				  noise+= texture2D(noisetex, coord * 0.04375 + wind * 0.15).x * 5.0;

			return noise;
		}

		vec3 DrawNetherNebula(vec3 viewPos, float dither, vec3 lightCol) {
			float NdotU = dot(normalize(viewPos), upVec);
			float cosS = dot(normalize(viewPos), sunVec);
			cosS *= cosS;
			cosS *= cosS;
			cosS *= cosS;

			#if AA > 1
				dither = fract(16.0 * frameTimeCounter + dither);
			#endif

			int sampleCount = 20;
			
			float gradientMix = dither / sampleCount;

			#if !defined GBUFFERS_WATER && !defined DEFERRED
				float cloudframetime = frametime;
			#else
				float cloudframetime = cloudtime;
			#endif

			vec2 wind = vec2(cloudframetime * 0.00005);

			vec3 aurora = vec3(0.0);

			float NdotUM = abs(NdotU);
			NdotUM = 1.0 - NdotUM;

			vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
			for(int i = 0; i < sampleCount; i++) {
				vec2 planeCoord = wpos.xz * (1.0 + (i + dither) * 6.0 / sampleCount) * 0.03;
				vec2 coord = planeCoord + cameraPosition.xz * 0.0017;

				float noise = NebulaNoise(coord, wind);
					  noise = max(0.75 - 1.0 / abs(noise - 6.0), 0.0) * 3.0;

				if (noise > 0.0) {
					noise *= texture2D(noisetex, abs(coord * 0.25) + wind * 8.0).x;
					float heightNoise = wpos.y;
					float fireNoise = texture2D(noisetex, abs(coord * 0.2) + (heightNoise + cameraPosition.y * 0.01) * 0.01 + wind * -4.0).x;
					noise = noise * noise * 3.0 / sampleCount;
					noise *= NdotUM;

					vec3 auroracolor = pow(lightCol, vec3(0.6, 0.5, 0.6)) * 12.0 * pow(fireNoise, 5.0);
					auroracolor *= gradientMix;

					aurora += noise * auroracolor * exp2(-6.0 * i / sampleCount);
				}
				gradientMix += 1.0 / sampleCount;
			}

			return aurora * 2.0;
		}
#endif