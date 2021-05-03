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
		float NdotUmult = 0.325;
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
								- 3.0;

		return max(noise - noiseCoverage, 0.0);
	}

	vec4 DrawCloud(vec3 viewPos, float dither, vec3 lightCol, vec3 ambientCol, float NdotU, int sampleCount) {
		float cosS = dot(normalize(viewPos), sunVec);
		
		#if AA > 1
			dither = fract(16.0 * frameTimeCounter + dither);
		#endif

		float timeBrightnessS = sqrt(timeBrightness);
		
		float cloud = 0.0;
		float cloudGradient = 0.0;
		float gradientMix = dither * 0.1667;
		float colorMultiplier = CLOUD_BRIGHTNESS * (0.23 + 0.07 * timeBrightnessS);
		float noiseMultiplier = CLOUD_THICKNESS * 0.125;
		float scattering = 0.5 * pow(cosS * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 6.0);

		float cloudHeightFactor = max(1.14 - 0.002 * eyeAltitude, 0.0);
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

		if (NdotU > 0.0) {
			vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
			for(int i = 0; i < sampleCount; i++) {
				if (cloud > 0.99) break;
				vec2 planeCoord = wpos.xz * ((cloudHeight + (i + dither) * stretchFactor * (6.0 / sampleCount)) / wpos.y) * 0.0085;
				vec2 coord = cameraPosition.xz * 0.00025 + planeCoord;
				/**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ 
				if (coordFactor > 0.0) {
					float ang1 = (i + frametime * 0.025) * 2.391;
					float ang2 = ang1 + 2.391;
					coord += mix(vec2(cos(ang1),sin(ang1)),vec2(cos(ang2),sin(ang2)), dither * 0.25 + 0.75) * coordFactor;
				}
				/**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ 
				float coverage = float(i - 3.0 + dither) * 0.667;

				float noise = CloudNoise(coord, wind);
					noise = CloudCoverage(noise, coverage, NdotU, cosS) * noiseMultiplier;
					noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);

				cloudGradient = mix(cloudGradient,
									mix(gradientMix * gradientMix, 1.0 - noise, 0.25),
									noise * (1.0 - cloud));
				cloud = mix(cloud, 1.0, noise);
				gradientMix += 0.2 * (6.0 / sampleCount);
			}

			float meFactorP = min((1.0 - min(moonBrightness, 0.6) / 0.6) * 0.115, 0.075);
			vec3 meSkyColor = vec3(0.0);
			if (cosS > 0.0) {
				float meNdotU = 1.0 - NdotU;
				float meFactor = meFactorP * meNdotU * meNdotU * 12.0 * (1.0 - rainStrengthS);
				meSkyColor = mix(lightMorning, lightEvening, mefade);
				meSkyColor *= meSkyColor * meSkyColor;
				meSkyColor *= meFactor * meFactor * cosS;
			}

			float sunVisibility2 = sunVisibility * sunVisibility;
			float sunVisibility4 = sunVisibility2 * sunVisibility2;

			sunVisibility4 = pow(sunVisibility4, 1.0 - meFactorP * 6.0);

			vec3 cloudNightColor = pow(lightNight, vec3(3.0 - rainStrengthS)) * (13.5 - rainStrengthS * 10.0) * (1.0 + 3.0 * nightVision);
			vec3 cloudDayColor = pow(lightCol, vec3(1.5 + rainStrengthS)) * 1.75;

			vec3 cloudUpColor = mix(cloudNightColor, cloudDayColor, sunVisibility4);
			cloudUpColor *= 1.0 + scattering * (1.0 + rainStrengthS);
			cloudUpColor += max(meSkyColor, vec3(0.0));

			vec3 cloudDownColor = skyCol * (0.175 + 0.075 * timeBrightnessS) * sunVisibility4;
			cloudGradient = min(cloudGradient, 0.8) * cloud;
			cloudcolor = mix(cloudDownColor, cloudUpColor, cloudGradient);

			cloud *= 1.0 - exp(- (10.0 - 9.0 * rainStrengthS) * NdotU);
		}

		return vec4(cloudcolor * colorMultiplier, cloud * cloud * CLOUD_OPACITY);
	}

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

			aurora = aurora * visibility;

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
			multiplier = sqrt(sqrt(NdotU)) * 5.0 * (1.0 - rainStrengthS);	
		#endif
		
		float star = 1.0;
		if (NdotU > 0.0) {
			star *= GetNoise(coord.xy);
			star *= GetNoise(coord.xy+0.1);
			star *= GetNoise(coord.xy+0.23);
		}
		star = max(star - 0.825, 0.0) * multiplier;
		
		#ifdef COMPATIBILITY_MODE
			vec3 stars = star * lightNight * lightNight * 160;
		#else
			vec3 stars = star * lightNight * lightNight * 320;
		#endif

		return vec3(stars);
	}
#endif

#if defined END && END_SKY > 0

	float CloudCoverageEnd(float noise, float cosT, float coverage) {
		float noiseMix = mix(noise, 21.0, 0.33 * rainStrengthS);
		float noiseFade = clamp(sqrt(cosT * 10.0), 0.0, 1.0);
		float noiseCoverage = ((coverage) + CLOUD_AMOUNT - 2);
		float multiplier = 1.0 - 0.5 * rainStrengthS;

		return max(noiseMix * noiseFade - noiseCoverage, 0.0) * multiplier;
	}

	float CloudNoiseEnd(vec2 coord, vec2 wind) {
		float noise = texture2D(noisetex, coord*1        + wind * 0.55).x;
			noise+= texture2D(noisetex, coord*0.5      + wind * 0.45).x * -2.0;
			noise+= texture2D(noisetex, coord*0.25     + wind * 0.35).x * 2.0;
			noise+= texture2D(noisetex, coord*0.125    + wind * 0.25).x * -5.0;
			noise+= texture2D(noisetex, coord*0.0625   + wind * 0.15).x * 20.0;
			noise+= texture2D(noisetex, coord*0.03125  + wind * 0.05).x * 20.0;
			noise+= texture2D(noisetex, coord*0.015625 + wind * 0.05).x * -15.0;
		return noise;
	}

	#if END_SKY == 1
		vec4 DrawEndCloud(vec3 viewPos, float dither, vec3 lightCol) { // Ender Clouds
			float cosT = dot(normalize(viewPos), upVec);
			float cosS = dot(normalize(viewPos), sunVec);

			#if AA > 1
				dither = fract(16.0 * frameTimeCounter + dither);
			#endif
			
			float cloud = 0.0;
			float cloudGradient = 0.0;
			float gradientMix = dither * 0.5;
			float colorMultiplier = 2.0 * (0.5 - 0.25 * (1.0 - sunVisibility) * (1.0 - rainStrengthS));
			float noiseMultiplier = 0.25;
			float scattering = pow(cosS * 0.5 + 0.5, 6.0);

			float cloudHeightFactor = max(1.14 - 0.002 * eyeAltitude, 0.0);
			cloudHeightFactor *= cloudHeightFactor;
			float cloudHeight = 6.3 + 6.0 * cloudHeightFactor;

				float cloudframetime = frametime;

			vec2 wind = vec2(cloudframetime * CLOUD_SPEED * 0.0035,
							sin(cloudframetime * CLOUD_SPEED * 0.05) * 0.002);

			vec3 cloudcolor = vec3(0.0);

			if (cosT > 0.0) {
				vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
				for(int i = 0; i < 6; i++) {
					if (cloud > 0.99) break;
					vec3 planeCoord = wpos * ((cloudHeight + (i + dither)) / wpos.y) * 0.014;
					vec2 coord = cameraPosition.xz * 0.00025 + planeCoord.xz;
						float ang1 = (i + frametime * 0.0025) * 2.391;
						float ang2 = ang1 + 2.391;
						coord += mix(vec2(cos(ang1),sin(ang1)),vec2(cos(ang2),sin(ang2)), dither * 0.25 + 0.75) * 0.008;
					float coverage = float(i - 3.0 + dither) * 0.667;

					float noise = CloudNoiseEnd(coord, wind);
						noise = CloudCoverageEnd(noise, cosT, coverage*1.5) * noiseMultiplier;
						noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);

					cloudGradient = mix(cloudGradient,
										mix(gradientMix * gradientMix, 1.0 - noise, 0.25),
										noise * (1.0 - cloud * cloud));
					cloud = mix(cloud, 1.0, noise);
					gradientMix += 0.6;
				}
				cloudcolor = lightCol * vec3(6.4, 6.8, 5.0) * (1.0 + scattering) * pow(cloudGradient, 0.75);
				cloudcolor = pow(cloudcolor, vec3(2)) * 6 * vec3(1.4, 1.8, 1.0);
				cloud *= min(cosT*cosT*4, 0.42);
			}

			return vec4(cloudcolor * colorMultiplier * (0.6+(sunVisibility)*0.4), cloud * cloud * 0.1 * CLOUD_OPACITY * (2-(sunVisibility)));
		}

	#else
		float GetStarNoise(vec2 pos) {
			return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
		}

		float NebulaNoise(vec2 coord, vec2 wind) {
			float noise = texture2D(noisetex, coord * 0.175   + wind * 0.25).x;
				noise+= texture2D(noisetex, coord * 0.04375 + wind * 0.15).x * 5.0;

			return noise;
		}

		vec4 DrawEndCloud(vec3 viewPos, float dither, vec3 lightCol) { // Ender Nebula
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

			vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
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

			#ifdef GBUFFERS_SKYTEXTURED
				vec3 starCoord = 0.75 * wpos / (abs(wpos.y) + length(wpos.xz));
				vec2 starCoord2 = starCoord.xz * 0.7;
				if (NdotU < 0.0) starCoord2 += 100.0;
				float starFactor = 1024.0;
				starCoord2 = floor(starCoord2 * starFactor) / starFactor;
				float star = 1.0;
				star *= GetStarNoise(starCoord2.xy);
				star *= GetStarNoise(starCoord2.xy+0.1);
				star *= GetStarNoise(starCoord2.xy+0.23);
				star = max(star - 0.825, 0.0);
				aurora += star * lightCol * 80.0 * (1.0 - NdotUM) * NEBULA_STAR_BRIGHTNESS;
			#endif

			return vec4(aurora * 2.0, 1.0);
		}
	#endif
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