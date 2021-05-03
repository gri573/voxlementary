/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Extensions//

//Varyings//
varying float mat, leaves;
varying float mipMapDisabling;
varying float quarterNdotUfactor;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef OLD_LIGHTING_FIX
varying vec3 eastVec, northVec;
#endif

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

varying vec3 binormal, tangent;

varying vec4 vTexCoord;
varying vec4 vTexCoordAM;
#endif

#ifdef SNOW_MODE
varying float grass;
varying float noSnow;
#endif

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int moonPhase;

#ifdef DYNAMIC_SHADER_LIGHT
	uniform int heldBlockLightValue;
	uniform int heldBlockLightValue2;
#endif

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 fogColor;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D noisetex;

#if defined FOG1 && defined FOG1_CHECK
	uniform float far;
#endif

#ifdef ADVANCED_MATERIALS
	uniform sampler2D specular;
	uniform sampler2D normals;

	#ifdef REFLECTION_RAIN
		uniform float wetness;
	#endif

	#if defined PARALLAX || defined SELF_SHADOW
		uniform int blockEntityId;
	#endif

	#if defined NORMAL_MAPPING && !(GENERATED_NORMALS == 0)
		uniform mat4 gbufferProjection;
	#endif
#endif

#if defined WEATHER_PERBIOME || defined REFLECTION_RAIN
	uniform float isDry, isRainy, isSnowy;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#if defined ADVANCED_MATERIALS && (defined NORMAL_MAPPING || defined PARALLAX)
vec2 dcdx = dFdx(texCoord.xy);
vec2 dcdy = dFdy(texCoord.xy);
#else
vec2 dcdx = texCoord.xy;
vec2 dcdy = texCoord.xy;
#endif

#ifdef OVERWORLD
	vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#else
	vec3 lightVec = sunVec;
#endif

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float InterleavedGradientNoise(){
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 32.0);
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/util/encode.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/materialGbuffers.glsl"

#if defined PARALLAX || defined SELF_SHADOW
#include "/lib/util/dither.glsl"
#include "/lib/surface/parallax.glsl"
#endif

#ifdef DIRECTIONAL_LIGHTMAP
#include "/lib/surface/directionalLightmap.glsl"
#endif

#if defined REFLECTION_RAIN && defined OVERWORLD
#include "/lib/reflections/rainPuddles.glsl"
#endif
#endif

//Program//
void main() {
	vec4 albedo = vec4(0.0);
	vec3 albedoP = vec3(0.0);
	if (mipMapDisabling < 0.5) {
		albedoP = texture2D(texture, texCoord).rgb;
		#if defined END && defined COMPATIBILITY_MODE && !defined SEVEN
			albedo.a = texture2DLod(texture, texCoord, 0.0).a;
		#else
			albedo.a = texture2D(texture, texCoord).a;
		#endif
	} else {
		albedoP = texture2DLod(texture, texCoord, 0.0).rgb;
		albedo.a = texture2DLod(texture, texCoord, 0.0).a;
	}
	albedo.rgb = albedoP * color.rgb;
	albedo.rgb = clamp(albedo.rgb, vec3(0.0), vec3(1.0));

	float materialFormatFlag = 1.0;
	
	#ifdef GREY
		albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
	#endif
	
	vec3 newNormal = normal;
	
	float skymapMod = 0.0;

	#ifdef ADVANCED_MATERIALS
		vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
		
		#if defined PARALLAX || defined SELF_SHADOW
			float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
			float skipParallax = float(blockEntityId == 63) + float(mat > 2.98 && mat < 3.02);
		#endif

		#ifdef PARALLAX
			float materialFormatParallax = 0.0;
			GetParallaxCoord(parallaxFade, newCoord, materialFormatParallax);
			if (materialFormatParallax + skipParallax < 0.5) {
				if (mipMapDisabling < 0.5) albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
				if (mipMapDisabling > 0.5) albedo = texture2DLod(texture, newCoord, 0.0) * vec4(color.rgb, 1.0);
			}
		#endif

		float smoothness = 0.0, metalData = 0.0;
		vec3 rawAlbedo = vec3(0.0);
	#endif
	
	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = 1.0;
	#endif

	if (albedocheck > 0.00001) {
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		
		float subsurface        = float(mat > 0.98 && mat < 1.02);
		float emissive          = float(mat > 1.98 && mat < 2.02) * 0.25;
		float definite_emissive = float(mat > 2.98 && mat < 3.52);
		float lava 			    = float(mat > 3.48 && mat < 3.52);
		float custom_emissive   = float(mat > 3.98 && mat < 4.02);
		#ifdef ADVANCED_MATERIALS
			float no_rain_ref   = float(mat > 4.98 && mat < 5.02);
		#endif
		#if defined GLOWING_LAPIS_BLOCK || defined GLOWING_REDSTONE_BLOCK
			float redstonelapis = float(mat > 5.98 && mat < 6.02);
		#endif

		if (custom_emissive > 0.5) {
			emissive = GetLuminance(albedo.rgb);
			emissive *= emissive;
			#ifndef COMPATIBILITY_MODE
				emissive *= emissive;
				lightmap.x = 0.95;
			#else
				emissive *= 0.5;
			#endif
		}
		#ifndef COMPATIBILITY_MODE
			if (lava > 0.5) {
				albedo.rgb = pow(albedo.rgb, vec3(1.3));
			}
		#else
			if (lava > 0.5) {
				albedo.rgb *= 0.925;
			}	
		#endif
		#if defined GLOWING_LAPIS_BLOCK || defined GLOWING_REDSTONE_BLOCK
			if (redstonelapis > 0.5) {
				float albedoB = albedo.b;
				float lAlbedo = length(albedo.rgb);
				//lAlbedo *= lAlbedo;
				albedo.rgb *= lAlbedo;
				emissive = lAlbedo * 6.0;
				#ifndef COMPATIBILITY_MODE
					emissive *= emissive;
				#endif
				if (albedo.r + albedo.b > 0.5) emissive *= 2.0;
				emissive *= 0.5;
				#ifdef COMPATIBILITY_MODE
					emissive *= albedoB * 5.0;
				#endif
			}
		#endif
		
		#if SHADOW_SUBSURFACE == 0
			subsurface = 0.0;
		#endif

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);
		float lViewPos = length(viewPos.xyz);

		#if defined FOG1 && defined FOG1_CHECK
			float lWorldPos = length(worldPos.xz);
			float fog1 = lWorldPos / far * 1.5 * (1 + rainStrengthS*0.3) * (10/FOG1_DISTANCE);
			fog1 = 1.0 - exp(-0.1 * pow(fog1, 10 - rainStrengthS*5));
			if (fog1 > 0.95) discard;
		#endif

		float scattering = 0.0;
		float ao = 1.0;
		#ifdef ADVANCED_MATERIALS
			float metalness = 0.0, f0 = 0.0;
			vec3 normalMap = vec3(0.0);
			float materialFormat = 0.0;
			float cauldron = 0.0;
			GetMaterials(materialFormat, smoothness, metalness, f0, metalData, emissive, ao, scattering, normalMap, newCoord, dcdx, dcdy);
			if (materialFormat > 0.5) {
				float fire           = float(mat > 2.98 && mat < 3.02);
				float glowstone      = float(mat > 100.98  && mat < 101.02 );
				float seaLantern     = float(mat > 101.98  && mat < 102.02 );
				float torches        = float(mat > 102.98  && mat < 103.02 );
				float beacon         = float(mat > 103.98  && mat < 104.02 );
				float shroomlight    = float(mat > 104.98  && mat < 105.02 );
				float redstoneLamp   = float(mat > 105.98  && mat < 106.02 );
				float dragonEgg      = float(mat > 106.98  && mat < 107.02 );
				float magmaBlock     = float(mat > 107.98  && mat < 108.02 );
				float overworldOres  = float(mat > 108.98  && mat < 109.02 );
				float litRedstoneOre = float(mat > 109.98  && mat < 110.02);
				float netherStems    = float(mat > 110.98 && mat < 111.02);
				      cauldron       = float(mat > 111.98 && mat < 112.02);
				float ancientDebris  = float(mat > 112.98 && mat < 113.02);
				float redstone       = float(mat > 114.98 && mat < 115.02);
				float gem 			 = float(mat > 115.98 && mat < 116.02);

				float emissiveBoost = float(mat > 186.98 && mat < 187.02);

				if (fire           > 0.5) albedo.rgb *= 1.1 - 0.35 * float(length(albedo.rgb) > 0.9);
				if (glowstone      > 0.5) emissive *= 1.1;
				if (seaLantern     > 0.5) lightmap.x = 1.0, albedo.b *= 1.1, albedo.rgb *= 0.8, emissive *= 1.25, ao = pow(ao, 1.5);
				if (torches        > 0.5) lightmap.x = min(lightmap.x, 0.86);
				if (beacon         > 0.5) lightmap = vec2(0.0), emissive *= 20.0, skymapMod = 0.995;
				if (shroomlight    > 0.5) albedo.rgb *= 1.05;
				if (redstoneLamp   > 0.5) lightmap.x = 0.925, emissive *= 2.2;
				if (dragonEgg      > 0.5) albedo.rgb *= 1.5, emissive *= 20.0;
				if (magmaBlock     > 0.5) lightmap.x *= 0.9, emissive *= LAVA_INTENSITY*LAVA_INTENSITY;
				if (litRedstoneOre > 0.5) lightmap.x = min(lightmap.x, 0.87);
				if (redstone       > 0.5) albedo.rgb *= sqrt(length(albedo.rgb)) * 0.75;
				if (gem            > 0.5) f0 = metalness, metalness = 0.0, metalData = 0.0;
				if (cauldron       > 0.5) {
					if (smoothness > 0.9) {
						no_rain_ref = 1.0;
						skymapMod = lmCoord.y * 0.475 + 0.515;
						#if WATER_TYPE == 0
							albedo.rgb = waterColor.rgb;
						#elif WATER_TYPE == 1
							albedo.rgb = pow(albedo.rgb, vec3(1.3));
						#else
							albedo.rgb = vec3(0.4, 0.5, 0.4) * (pow(albedo.rgb, vec3(2.8)) + 4 * waterColor.rgb * pow(albedo.r, 1.8)
														+ 16 * waterColor.rgb * pow(albedo.g, 1.8) + 4 * waterColor.rgb * pow(albedo.b, 1.8));
							albedo.rgb = pow(albedo.rgb * 1.5, vec3(0.5, 0.6, 0.5)) * 0.6;
							albedo.rgb *= 1 + length(albedo.rgb) * pow(WATER_OPACITY, 32.0) * 2.0;
						#endif
						#ifdef NORMAL_MAPPING
							vec2 cauldronCoord1 = texCoord + fract(frametime * 0.003);
							float cauldronNoise1 = texture2D(noisetex, cauldronCoord1 * 2.0).r;
							vec2 cauldronCoord2 = texCoord - fract(frametime * 0.003);
							float cauldronNoise2 = texture2D(noisetex, cauldronCoord2 * 2.0).r;
							float waveFactor = 0.0166 + 0.05 * lightmap.y;
							normalMap.xy += (0.5 * waveFactor) * (cauldronNoise1 * cauldronNoise2 - 0.3);
							albedo.rgb *= (1.0 - waveFactor * 0.5) + waveFactor * cauldronNoise1 * cauldronNoise2;
						#endif
					} else cauldron = 0.0;
				}
				#ifndef EMISSIVE_ORES
					if (overworldOres  > 0.5) emissive *= 0.0, metalness *= 0.0;
				#endif
				#ifndef EMISSIVE_NETHER_STEMS
					if (netherStems    > 0.5) emissive *= 0.0;
				#endif
				#ifdef GLOWING_DEBRIS
					if (ancientDebris  > 0.5) emissive = pow(length(albedo.rgb), 5.0) * (5.0 + float(isEyeInWater == 2) * 100.0);
				#endif

				if (emissiveBoost > 0.5) emissive *= 3.0;
			} else {
				materialFormatFlag = 0.0;
			}
			
			#ifdef NORMAL_MAPPING
				#if !(GENERATED_NORMALS == 0)
					#if GENERATED_NORMALS == 1
					if (materialFormat > 0.5 && cauldron < 0.5) {
					#endif
						float lOriginalAlbedo = length(albedoP);
						float fovScale = gbufferProjection[1][1] / 1.37;
						float scale = lViewPos / fovScale;
						float normalMult = clamp(10.0 - scale, 0.0, 8.0) * 0.25;
						float normalClamp = 0.05;
						if (normalMult > 0.0) {
							for(int i = 0; i < 2; i++) {
								vec2 offset = vec2(0.0, 0.0);
								if (i == 0) offset = vec2( 0.0,  1.0);
								if (i == 1) offset = vec2( 1.0,  0.0);
								vec2 offsetCoord = newCoord + offset * 0.0001;

								if (vTexCoord.x > 1.0 - 0.0045 || vTexCoord.y > 1.0 - 0.0045) break;
								//albedo.rgb *= 0.0;

								#ifndef FOG1_CHECK
									float lNearbyAlbedo = length(texture2D(texture, offsetCoord).rgb);
								#else
									float lNearbyAlbedo = length(texture2DLod(texture, offsetCoord, 0.0).rgb); // Because AMD
								#endif
								float dif = lOriginalAlbedo - lNearbyAlbedo;
								if (dif > 0.0) dif = max(dif - normalClamp, 0.0);
								else           dif = min(dif + normalClamp, 0.0);
								dif *= normalMult;
								dif = clamp(dif, -0.5, 0.5);
								if (i == 0) normalMap.y += dif;
								if (i == 1) normalMap.x += dif;
							}
						}
					#if GENERATED_NORMALS == 1
					}
					#endif
				#endif

				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									tangent.y, binormal.y, normal.y,
									tangent.z, binormal.z, normal.z);

				if (normalMap.x > -0.999 && normalMap.y > -0.999)
					newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
			#endif
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef SNOW_MODE
			#ifdef OVERWORLD
				if (noSnow < 0.5) {
					vec3 snowColor = vec3(0.5, 0.5, 0.65);
					float snowNoise = texture2D(noisetex, 0.125 * (vec2(worldPos.y + cameraPosition.y) + worldPos.xz + cameraPosition.xz)).r;
					snowColor *= 0.85 + 0.5 * snowNoise;
					float grassFactor = ((1.0 - abs(albedo.g - 0.3) * 4.0) - albedo.r * 2.0) * max(grass, leaves) * 2.0;
					float snowFactor = clamp(dot(newNormal, upVec), 0.0, 1.0);
					snowFactor *= snowFactor;
					if (grassFactor > 0.0) snowFactor = max(snowFactor * 0.75, grassFactor);
					snowFactor *= pow(lightmap.y, 16.0) * (1.0 - pow(lightmap.x + 0.1, 8.0) * 1.5);
					snowFactor = clamp(snowFactor, 0.0, 0.85);
					albedo.rgb = mix(albedo.rgb, snowColor, snowFactor);
					#ifdef ADVANCED_MATERIALS
						snowFactor = snowFactor * (0.75 + 0.5 * snowNoise);
						smoothness = mix(smoothness, 0.45, snowFactor);
						metalness = mix(metalness, 0.0, snowFactor);
					#endif
				}
			#endif
		#endif

		#ifdef WHITE_WORLD
			albedo.rgb = vec3(0.5);
		#endif

		float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float fullNdotU = dot(newNormal, upVec);
		float quarterNdotU = clamp(0.25 * fullNdotU + 0.75, 0.5, 1.0);
		float quarterNdotUp = quarterNdotU;
			  quarterNdotU*= quarterNdotU;
			  quarterNdotU = mix(1.0, quarterNdotU, quarterNdotUfactor);

		float smoothLighting = color.a;
		#ifdef OLD_LIGHTING_FIX 
			//Probably not worth the %4 fps loss
			//Don't forget to apply the same fix to translucents if I end up making this an option
			if (smoothLighting < 0.9999999) {
				float absNdotE = abs(dot(newNormal, eastVec));
				float absNdotN = abs(dot(newNormal, northVec));
				float NdotD = abs(fullNdotU) * float(fullNdotU < 0.0);

				smoothLighting += 0.4 * absNdotE;
				smoothLighting += 0.2 * absNdotN;
				smoothLighting += 0.502 * NdotD;

				smoothLighting = clamp(smoothLighting, 0.0, 1.0);
				//albedo.rgb = mix(vec3(1, 0, 1), albedo.rgb, pow(smoothLighting, 10000.0));
			}
		#endif

		float parallaxShadow = 1.0;
		float materialAO = 1.0;
		#ifdef ADVANCED_MATERIALS
			rawAlbedo = albedo.rgb * 0.999 + 0.001;
			if (materialFormat > 0.5) {
				albedo.rgb *= ao;
				if (metalness > 0.80) {
					albedo.rgb *= (1.0 - metalness*0.65);
				}
			} else {
				materialAO = ao;
				albedo.rgb *= (1.0 - metalness*0.65);
			}

			float doParallax = 0.0;
			#if defined SELF_SHADOW && defined NORMAL_MAPPING
				#ifdef OVERWORLD
					doParallax = float(lightmap.y > 0.0 && NdotL > 0.0);
				#endif
				#ifdef END
					doParallax = float(NdotL > 0.0);
				#endif
				if (materialFormat > 0.5) doParallax = 0.0;
				
				if (doParallax > 0.5){
					parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix);
				}
			#endif

			#ifdef DIRECTIONAL_LIGHTMAP
				if (materialFormat < 0.5) {
					mat3 lightmapTBN = GetLightmapTBN(viewPos);
					lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
					lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
				}
			#endif
		#endif
		
		float shadow = 0.0;
		float fakeShadow = 0.0;
		GetLighting(albedo.rgb, shadow, fakeShadow, viewPos, lViewPos, worldPos, lightmap, smoothLighting, NdotL, quarterNdotU,
					parallaxShadow, emissive + definite_emissive, subsurface, mat, leaves, scattering, materialAO);
		
		#ifdef ADVANCED_MATERIALS
			#if defined OVERWORLD || defined END
				#ifdef OVERWORLD
					#ifdef REFLECTION_RAIN
						if (quarterNdotUp > 0.85) {
							#ifdef RAIN_REF_BIOME_CHECK
							if (no_rain_ref < 0.1) {
							#endif
								vec2 rainPos = worldPos.xz + cameraPosition.xz;

								skymapMod = lmCoord.y * 16.0 - 15.5;
								float lmCX = pow(lmCoord.x * 1.3, 50.0);
								skymapMod = max(skymapMod - lmCX, 0.0);

								float puddleSize = 0.0025;
								skymapMod *= GetPuddles(rainPos * puddleSize);

								float skymapModx2 = skymapMod * 2.0;
								smoothness = mix(smoothness, 0.8 , skymapModx2);
								metalness  = mix(metalness , 0.0 , skymapModx2);
								metalData  = mix(metalData , 0.0 , skymapModx2);
								f0         = mix(f0        , 0.02, skymapModx2);

								mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
												tangent.y, binormal.y, normal.y,
												tangent.z, binormal.z, normal.z);
								rainPos *= 0.02;
								vec2 wind = vec2(frametime) * 0.01;
								vec3 pnormalMap = vec3(0.0, 0.0, 1.0);
								float pnormalMultiplier = 0.05;

								vec2 pnormalCoord1 = rainPos + vec2(wind.x, wind.y);
								vec3 pnormalNoise1 = TextureSample3R(noisetex, pnormalCoord1);
								vec2 pnormalCoord2 = rainPos + vec2(wind.x * -1.5, wind.y * -1.0);
								vec3 pnormalNoise2 = TextureSample3R(noisetex, pnormalCoord2);

								pnormalMap += (pnormalNoise1 - vec3(0.5)) * pnormalMultiplier;
								pnormalMap += (pnormalNoise2 - vec3(0.5)) * pnormalMultiplier;
								vec3 puddleNormal = clamp(normalize(pnormalMap * tbnMatrix),vec3(-1.0),vec3(1.0));

								albedo.rgb *= 1.0 - sqrt(length(pnormalMap.xy)) * 0.8 * skymapModx2 * (rainStrengthS);
								//albedo.rgb *= 0.0;

								vec3 rainNormal = normalize(mix(newNormal, puddleNormal, rainStrengthS));

								newNormal = mix(newNormal, rainNormal, skymapModx2);
							#ifdef RAIN_REF_BIOME_CHECK
							}
							#endif
						}
					#endif

					vec3 lightME = mix(lightMorning, lightEvening, mefade);
					vec3 lightDayTint = lightDay * lightME * LIGHT_DI;
					vec3 lightDaySpec = mix(lightME, sqrt(lightDayTint), timeBrightness);
					vec3 specularColor = mix(sqrt(lightNight*0.3),
												lightDaySpec,
												sunVisibility);
					#ifdef WATER_CAUSTICS
						if (isEyeInWater == 1) specularColor *= rawWaterColor.rgb * 8.0;
					#endif
					specularColor *= specularColor;

					#ifdef SPECULAR_SKY_REF
						float skymapModM = lmCoord.y;
						#if SKY_REF_FIX_1 == 1
							skymapModM = skymapModM * skymapModM;
						#elif SKY_REF_FIX_1 == 2
							skymapModM = max(skymapModM - 0.80, 0.0) * 5.0;
						#else
							skymapModM = max(skymapModM - 0.99, 0.0) * 100.0;
						#endif
						if (!(metalness <= 0.004 && metalness > 0.0)) skymapMod = max(skymapMod, skymapModM * 0.1);
					#endif
				#endif
				#ifdef END
					vec3 specularColor = endCol;
					if (cauldron > 0.0) skymapMod = (min(length(shadow), 0.475) + 0.515) * float(smoothness > 0.9);
					else skymapMod = min(length(shadow), 0.5);
				#endif
				
				vec3 specularHighlight = vec3(0.0);
				specularHighlight = GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo,
												shadow, newNormal, viewPos, materialFormat);
				#if defined LIGHT_LEAK_FIX && !defined END
					if (isEyeInWater == 0) specularHighlight *= pow(lightmap.y, 2.5);
					else specularHighlight *= 0.15 + 0.85 * pow(lightmap.y, 2.5);
				#endif
				albedo.rgb += specularHighlight * smoothLighting * (1.0 - fakeShadow);
			#endif
		#endif
		
		#ifdef SHOW_LIGHT_LEVELS
			if (lmCoord.x < 0.533334 && quarterNdotU > 0.99 && subsurface + leaves < 0.1) {
				float showLightLevelFactor = fract(frameTimeCounter);
				if (showLightLevelFactor > 0.5) showLightLevelFactor = 1 - showLightLevelFactor;
				albedo.rgb += vec3(0.5, 0.0, 0.0) * showLightLevelFactor;
			}
		#endif
	} else discard;

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(1.0, 1.0, 170.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0361 */
	gl_FragData[1] = vec4(smoothness, metalData, skymapMod, 1.0);
	gl_FragData[2] = vec4(EncodeNormal(newNormal), materialFormatFlag, 1.0);
	gl_FragData[3] = vec4(rawAlbedo, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat, leaves;
varying float mipMapDisabling;
varying float quarterNdotUfactor;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef OLD_LIGHTING_FIX
varying vec3 eastVec, northVec;
#endif

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

varying vec3 binormal, tangent;

varying vec4 vTexCoord;
varying vec4 vTexCoordAM;
#endif

#ifdef SNOW_MODE
varying float grass;
varying float noSnow;
#endif

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#if AA > 1
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

#ifdef ADVANCED_MATERIALS
attribute vec4 at_tangent;
#endif

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#ifdef OVERWORLD
	float timeAngleM = timeAngle;
#else
	#if !defined SEVEN && !defined SEVEN_2
		float timeAngleM = 0.25;
	#else
		float timeAngleM = 0.5;
	#endif
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main(){
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADVANCED_MATERIALS
		binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
		tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
		
		#if defined PARALLAX || defined SELF_SHADOW
			mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
								tangent.y, binormal.y, normal.y,
								tangent.z, binormal.z, normal.z);
		
			viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
			dist = length(gl_ModelViewMatrix * gl_Vertex);
		#endif

		vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoord - midCoord;

		vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
		vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
		
		vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;
	
	float compatibilityFactor = 0.0;
	#ifdef COMPATIBILITY_MODE
		compatibilityFactor = 1.0;
	#endif
	
	mat = 0.0; quarterNdotUfactor = 1.0; mipMapDisabling = 0.0; leaves = 0.0;

	if (mc_Entity.x ==  31 || mc_Entity.x ==   6 || mc_Entity.x ==  59 || mc_Entity.x == 175 ||
	    mc_Entity.x == 176 || mc_Entity.x ==  83 || mc_Entity.x == 104 || mc_Entity.x == 105) // Grass+
		mat = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87), quarterNdotUfactor = 0.0;
	if (mc_Entity.x == 18 || mc_Entity.x == 10600 || mc_Entity.x == 11100) // Leaves, Vine, Lily Pad
		#if SHADOW_SUBSURFACE == 2
			leaves = 1.0, mat = 1.0;
		#else
			leaves = 1.0, mat = 1.5, color.a += 0.15;
		#endif

	if (mc_Entity.x ==  10) // Lava
		mat = 3.5, quarterNdotUfactor = 0.0, color.a = 1.0, lmCoord.x = 1.0, color.rgb = vec3(LAVA_INTENSITY * 0.84);
	if (mc_Entity.x ==  1010) // Fire
		mat = 3.0, lmCoord.x = 0.5, color.a = 1.0, color.rgb = vec3(FIRE_INTENSITY * 0.67);
	if (mc_Entity.x ==  210) // Soul Fire
		mat = 3.0, lmCoord.x = 0.0, color.a = 1.0, color.rgb = vec3(FIRE_INTENSITY * 0.495);
		
	if (mc_Entity.x == 300) // No Vanilla AO
		color.a = 1.0;

	if (mc_Entity.x == 12345) // Custom Emissive
		mat = 4.0, lmCoord.x = 1.0;

	#ifdef GLOWING_REDSTONE_BLOCK
		if (mc_Entity.x == 7776)
			mat = 6.0, lmCoord.x = 1.0;
	#endif

	#ifdef GLOWING_LAPIS_BLOCK
		if (mc_Entity.x == 7775)
			mat = 6.0, lmCoord.x = 1.0;
	#endif

	#if !defined COMPATIBILITY_MODE && defined ADVANCED_MATERIALS
		if (mc_Entity.x == 91) // Glowstone
			lmCoord.x = 0.885, mat = 101.0;
		if (mc_Entity.x == 92) // Sea Lantern
			lmCoord.x = 0.865, color.a = 1.0, mat = 102.0;
		if (mc_Entity.x == 95 || mc_Entity.x == 951 || mc_Entity.x == 952) // Torches
			lmCoord.x = min(lmCoord.x, 0.9), mat = 103.0;
		if (mc_Entity.x == 75) // End Rod
			;
		if (mc_Entity.x == 911) // Lantern
			lmCoord.x = min(lmCoord.x, 0.9);
		if (mc_Entity.x == 912) // Soul Lantern
			lmCoord.x = min(lmCoord.x, 0.885);
		if (mc_Entity.x == 93) // Jack o'Lantern
			lmCoord.x = 0.87;
		if (mc_Entity.x == 917) // Magma Block
			lmCoord = vec2(0.87, 0.0), color.a = 1.0, mat = 108.0;
		if (mc_Entity.x == 138) // Beacon
			lmCoord.x = 0.885, mat = 104.0;
		if (mc_Entity.x == 191) // Shroomlight
			lmCoord.x = 0.865, mat = 105.0;
		if (mc_Entity.x == 901) // Redstone Lamp Lit=True
			lmCoord.x = 0.9, mat = 106.0;
		if (mc_Entity.x == 94 || mc_Entity.x == 941) // Campfire Lit=True, Soul Campfire Lit=True
		    lmCoord.x = min(lmCoord.x, 0.885);
		if (mc_Entity.x == 96 || mc_Entity.x == 961 || mc_Entity.x == 962 || mc_Entity.x == 963) // Sea Pickle
			lmCoord.x = min(lmCoord.x, 0.885);
		if (mc_Entity.x == 866) // Carpets, Wools
			color.a *= (1.0 - pow(lmCoord.x, 6.0) * 0.5);
		if (mc_Entity.x == 871) // Respawn Anchor Charges=1
			lmCoord.x = 0.8;
		if (mc_Entity.x == 872) // Respawn Anchor Charges=2
			lmCoord.x = 0.82;
		if (mc_Entity.x == 873) // Respawn Anchor Charges=3
			lmCoord.x = 0.84;
		if (mc_Entity.x == 874) // Respawn Anchor Charges=4
			lmCoord.x = 0.87;
		if (mc_Entity.x == 139) // Dragon Egg
			mat = 107.0;
		if (mc_Entity.x == 97) // Jigsaw Block, Structure Block
			mat = 187.0;
		if (mc_Entity.x == 98) // Command Blocks
			mat = 187.0;
		if (mc_Entity.x == 62) // Furnaces Lit=True
			lmCoord.x = pow(lmCoord.x, 1.5);
		if (mc_Entity.x == 77 || mc_Entity.x == 771 || mc_Entity.x == 772 || mc_Entity.x == 773 || mc_Entity.x == 774 || mc_Entity.x == 775 || mc_Entity.x == 776) // Overworld Ores
			mat = 109.0;
		if (mc_Entity.x == 777) // Lit Redstone Ore
			mat = 110.0;
		if (mc_Entity.x == 880) // Nether Stems
			mat = 111.0;
		if (mc_Entity.x == 993) // Cauldron
			mat = 112.0;
		if (mc_Entity.x == 1090) // Ancient Debris
			mat = 113.0;
		if (mc_Entity.x == 55) // Redstone Wire
			mat = 115.0;
		if (mc_Entity.x == 7777 || mc_Entity.x == 7778) // Diamond Block, Emerald Block
			mat = 116.0;

		// Too bright near a light source fix
		if (mc_Entity.x == 99 || mc_Entity.x == 991 || mc_Entity.x == 919 || mc_Entity.x == 993)
			lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);

		// No shading
		if (mc_Entity.x == 91 || mc_Entity.x == 901 || mc_Entity.x == 92 || mc_Entity.x == 97 || mc_Entity.x == 191 || mc_Entity.x == 917)
			quarterNdotUfactor = 0.0;

		#ifdef WRONG_MIPMAP_FIX
			if (mc_Entity.x == 917 || mc_Entity.x == 991 || mc_Entity.x == 992 || mc_Entity.x == 880 || mc_Entity.x == 76 || mc_Entity.x == 77 || 
				mc_Entity.x == 919 || mc_Entity.x == 98 || mc_Entity.x ==  96 || mc_Entity.x ==  95 || mc_Entity.x ==  93 || mc_Entity.x ==  901 || 
				mc_Entity.x ==  902 || mc_Entity.x ==  91 || mc_Entity.x ==  92 || mc_Entity.x == 777)
				mipMapDisabling = 1.0;
		#endif
	#endif

	#if defined ADVANCED_MATERIALS && defined REFLECTION_RAIN
		if (mc_Entity.x == 9875) // No Rain Reflections
			mat = 5.0;
	#endif

	#ifdef SNOW_MODE
		grass = float(mc_Entity.x == 31 || mc_Entity.x == 175 || mc_Entity.x == 176 || mc_Entity.x == 6 || mc_Entity.x == 3737);
		noSnow = float(mc_Entity.x == 1010 || mc_Entity.x == 210 || mc_Entity.x == 55 || mc_Entity.x == 993);
	#endif
	
	#ifdef COMPATIBILITY_MODE
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		if (lightmap.x > 0.5) lightmap.x = smoothstep(0.0, 1.0, lightmap.x);
		float newLightmap = pow(lightmap.x, 10.0);
		quarterNdotUfactor *= 1.0 - newLightmap;
	#endif
	
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);

	#ifdef OLD_LIGHTING_FIX
		eastVec = normalize(gbufferModelView[0].xyz);
		northVec = normalize(gbufferModelView[2].xyz);
	#endif

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	vec3 wave = WavingBlocks(position.xyz, istopv);
	position.xyz += wave;

    #ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif