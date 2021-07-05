/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying float mat;
varying float mipmapDisabling;
varying float quarterNdotUfactor;
varying float specR, specG, specB;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef OLD_LIGHTING_FIX
varying vec3 eastVec, northVec;
#endif

#ifdef ADV_MAT
	#if defined PARALLAX || defined SELF_SHADOW
		varying float dist;
		varying vec3 viewVector;
	#endif

	#if !defined COMPBR || defined NORMAL_MAPPING
		varying vec4 vTexCoord;
		varying vec4 vTexCoordAM;
	#endif

	#if defined NORMAL_MAPPING || defined REFLECTION_RAIN
		varying vec3 binormal, tangent;
	#endif
#endif

#ifdef SNOW_MODE
varying float noSnow;
#endif

#ifdef COLORED_LIGHT
varying float lightVarying;
#endif

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int moonPhase;

#ifdef DYNAMIC_SHADER_LIGHT
	uniform int heldItemId, heldItemId2;

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
uniform mat4 gbufferModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D noisetex;

#ifdef ADV_MAT
	#ifndef COMPBR
		uniform sampler2D specular;
		uniform sampler2D normals;
	#endif

	#ifdef REFLECTION_RAIN
		uniform float wetness;
	#endif

	#if defined PARALLAX || defined SELF_SHADOW
		uniform int blockEntityId;
	#endif

	#if defined NORMAL_MAPPING && defined GENERATED_NORMALS
		uniform mat4 gbufferProjection;
	#endif
#endif

#ifdef REFLECTION_RAIN
	uniform float isDry, isRainy, isSnowy;
#endif

#ifdef COLORED_LIGHT
uniform ivec2 eyeBrightness;

uniform sampler2D colortex9;
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

#if defined ADV_MAT && RP_SUPPORT > 2
vec2 dcdx = dFdx(texCoord.xy);
vec2 dcdy = dFdy(texCoord.xy);
#endif

#ifdef OVERWORLD
	vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#else
	vec3 lightVec = sunVec;
#endif
 
//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float InterleavedGradientNoise() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
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

#ifdef ADV_MAT
#include "/lib/util/encode.glsl"
#include "/lib/surface/ggx.glsl"

#ifndef COMPBR
#include "/lib/surface/materialGbuffers.glsl"
#endif

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
	if (mipmapDisabling < 0.5) {
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
	albedo.rgb = albedoP;
	if (mat < 10000.0) albedo.rgb *= color.rgb;
	albedo.rgb = clamp(albedo.rgb, vec3(0.0), vec3(1.0));
	
	float material = floor(mat);
	vec3 newNormal = normal;
	vec3 lightAlbedo = vec3(0.0);
	#ifdef GREEN_SCREEN
		float greenScreen = 0.0;
	#endif

	#ifdef ADV_MAT
		float smoothness = 0.0, metalData = 0.0, metalness = 0.0, f0 = 0.0, skymapMod = 0.0;
		vec3 rawAlbedo = vec3(0.0), normalMap = vec3(0.0, 0.0, 1.0);

		#if !defined COMPBR || defined NORMAL_MAPPING
			vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
		#endif
		
		#if defined PARALLAX || defined SELF_SHADOW
			float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
			float parallaxDepth = 1.0;
		#endif

		#ifdef PARALLAX
			float skipParallax = float(blockEntityId == 63 || material == 4.0); // Fixes broken signs and lava with pom
			if (skipParallax < 0.5) {
				GetParallaxCoord(parallaxFade, newCoord, parallaxDepth);
				if (mipmapDisabling < 0.5) albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
				else 					   albedo = texture2DLod(texture, newCoord, 0.0) * vec4(color.rgb, 1.0);
			}
		#endif
	#endif
	
	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = 1.0;
	#endif

	if (albedocheck > 0.00001) {
		float foliage = float(material == 1.0);
		float leaves  = float(material == 2.0);

		//Emission
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		float emissive = specB * 4.0;
		
		//Subsurface Scattering
		#if SHADOW_SUBSURFACE == 0
			float subsurface = 0.0;
		#elif SHADOW_SUBSURFACE == 1
			float subsurface = foliage * SCATTERING_FOLIAGE;
		#elif SHADOW_SUBSURFACE == 2
			float subsurface = foliage * SCATTERING_FOLIAGE + leaves * SCATTERING_LEAVES;
		#endif

		#ifndef SHADOWS
			if (leaves > 0.5) subsurface *= 0.5;
			else subsurface = pow2(subsurface * subsurface);
		#endif

		#ifdef COMPBR
			float lAlbedoP = length(albedoP);
		
			if (mat > 10000.0) { // More control over lAlbedoP at the cost of color.rgb
				if (mat > 17500.0) {
					if (mat > 25000.0) { // 30000 - Inverted lAlbedoP
						lAlbedoP = max(1.73 - lAlbedoP, 0.0) * color.r + color.g;
					} else { // 20000 - Channel Controlled lAlbedoP
						lAlbedoP = length(albedoP * max(color.rgb, vec3(0.0)));
						if (color.g < -0.0001) lAlbedoP = max(lAlbedoP + color.g * albedo.g * 0.1, 0.0);
					}
				} else { // 15000 - Difference Based lAlbedoP
					vec3 averageAlbedo = texture2DLod(texture, texCoord, 100.0).rgb;
					lAlbedoP = sqrt2(length(albedoP.rgb - averageAlbedo) + color.r) * color.g * 20.0;
					#ifdef GREEN_SCREEN
						if (albedo.g * 1.4 > albedo.r + albedo.b && albedo.g > 0.6 && albedo.r * 2.0 > albedo.b)
							greenScreen = 1.0;
					#endif
				}
				
			}

		//Integrated Emission
			if (specB > 1.02) {
				emissive = pow(lAlbedoP, specB) * fract(specB) * 20.0;
			}

		//Integrated Smoothness
			smoothness = specR;
			if (specR > 1.02) {
				float lAlbedoPsp = lAlbedoP;
				float spec = specR;
				if (spec > 1000.0) lAlbedoPsp = 2.0 - lAlbedoP, spec -= 1000.0;
				smoothness = pow(lAlbedoPsp, spec * 0.1) * fract(specR) * 5.0;
				smoothness = min(smoothness, 1.0);
			}

		//Integrated Metalness+
			metalness = specG;
			if (specG > 10.0) {
				metalness = 3.0 - lAlbedoP * specG * 0.01;
				metalness = min(metalness, 1.0);
			}
		#endif

		//Main
		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);
		float lViewPos = length(viewPos.xyz);

		float ao = 1.0;
		float cauldron = 0.0;

		#ifdef ADV_MAT
			#if defined REFLECTION_RAIN && defined RAIN_REF_BIOME_CHECK
				float noRain = float(material == 3.0);
			#endif

			#ifndef COMPBR
				GetMaterials(smoothness, metalness, f0, metalData, emissive, ao, normalMap, newCoord, dcdx, dcdy);
			#else
				#include "/lib/ifchecking/terrainFragment.glsl"

				#ifdef METALLIC_WORLD
					metalness = 1.0;
					smoothness = sqrt1(smoothness);
				#endif

				f0 = 0.78 * metalness + 0.02;
				metalData = metalness;

				if (material == 106.0) { // Diamond Block, Emerald Block
					f0 = smoothness;
					smoothness = 0.9 - f0 * 0.1;
					if (albedo.g > albedo.b * 1.1) { // Emerald Block
						f0 *= f0 * 1.2;
						f0 *= f0;
						f0 = clamp(f0 * f0, 0.0, 1.0);
					}
				}
			#endif
			
			#ifdef NORMAL_MAPPING
				#if defined GENERATED_NORMALS && defined COMPBR
					float lOriginalAlbedo = length(albedoP);
					float fovScale = gbufferProjection[1][1] / 1.37;
					float scale = lViewPos / fovScale;
					float normalMult = clamp(10.0 - scale, 0.0, 8.0) * 0.25 * (1.0 - cauldron);
					float normalClamp = 0.05;
					if (normalMult > 0.0) {
						for(int i = 0; i < 2; i++) {
							vec2 offset = vec2(0.0, 0.0);
							if (i == 0) offset = vec2( 0.0,  1.0);
							if (i == 1) offset = vec2( 1.0,  0.0);
							vec2 offsetCoord = newCoord + offset * 0.0001220703125;

							if (vTexCoord.x > 1.0 - 0.0045 || vTexCoord.y > 1.0 - 0.0045) break;
							//albedo.rgb *= 0.0;

							float lNearbyAlbedo = length(texture2D(texture, offsetCoord).rgb);
							float dif = lOriginalAlbedo - lNearbyAlbedo;
							if (dif > 0.0) dif = max(dif - normalClamp, 0.0);
							else dif = min(dif + normalClamp, 0.0);
							dif *= normalMult;
							dif = clamp(dif, -0.5, 0.5);
							if (i == 0) normalMap.y += dif;
							if (i == 1) normalMap.x += dif;
						}
					}
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
				if (noSnow + cauldron < 0.5) {
					vec3 snowColor = vec3(0.5, 0.5, 0.65);
					float snowNoise = texture2D(noisetex, 0.125 * (vec2(worldPos.y + cameraPosition.y) + worldPos.xz + cameraPosition.xz)).r;
					snowColor *= 0.85 + 0.5 * snowNoise;
					float grassFactor = ((1.0 - abs(albedo.g - 0.3) * 4.0) - albedo.r * 2.0) * float(color.r < 0.999) * 2.0;
					float snowFactor = clamp(dot(newNormal, upVec), 0.0, 1.0);
					snowFactor *= snowFactor;
					if (grassFactor > 0.0) snowFactor = max(snowFactor * 0.75, grassFactor);
					snowFactor *= pow(lightmap.y, 16.0) * (1.0 - pow(lightmap.x + 0.1, 8.0) * 1.5);
					snowFactor = clamp(snowFactor, 0.0, 0.85);
					albedo.rgb = mix(albedo.rgb, snowColor, snowFactor);
					#ifdef ADV_MAT
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
		float quarterNdotUp = clamp(0.25 * fullNdotU + 0.75, 0.5, 1.0);
		float quarterNdotU = quarterNdotUp * quarterNdotUp;
			  quarterNdotU = mix(1.0, quarterNdotU, quarterNdotUfactor);

		float smoothLighting = color.a;
		#ifdef OLD_LIGHTING_FIX 
			//Probably not worth the %4 fps loss
			//Don't forget to apply the same fix to gbuffers_water if I end up making this an option
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
		#ifdef ADV_MAT
			rawAlbedo = albedo.rgb * 0.999 + 0.001;
			#ifdef COMPBR
				albedo.rgb *= ao;
				if (metalness > 0.801) {
					albedo.rgb *= (1.0 - metalness*0.65);
				}
			#else
				materialAO = ao;
				albedo.rgb *= (1.0 - metalness*0.65);
			#endif

			#if defined SELF_SHADOW && defined NORMAL_MAPPING
				float doParallax = 0.0;
				#ifdef OVERWORLD
					doParallax = float(lightmap.y > 0.0 && NdotL > 0.0);
				#endif
				#ifdef END
					doParallax = float(NdotL > 0.0);
				#endif
				if (doParallax > 0.5) {
					parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix, parallaxDepth);
				}
			#endif

			#ifdef DIRECTIONAL_LIGHTMAP
				mat3 lightmapTBN = GetLightmapTBN(viewPos);
				lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
				lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
			#endif
		#endif
		
		float shadow = 0.0;
		GetLighting(albedo.rgb, shadow, lightAlbedo, viewPos, lViewPos, worldPos, lightmap, smoothLighting, NdotL, quarterNdotU,
					parallaxShadow, emissive, subsurface, leaves, materialAO, newNormal);

		#ifdef ADV_MAT
			#if defined OVERWORLD || defined END
				#ifdef OVERWORLD
					#ifdef REFLECTION_RAIN
						if (quarterNdotUp > 0.85) {
							#ifdef RAIN_REF_BIOME_CHECK
							if (noRain < 0.1) {
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
								f0 = mix(f0, 0.02, skymapModx2);

								mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
													  tangent.y, binormal.y, normal.y,
													  tangent.z, binormal.z, normal.z);
								rainPos *= 0.02;
								vec2 wind = vec2(frametime) * 0.01;
								vec3 pnormalMap = vec3(0.0, 0.0, 1.0);
								float pnormalMultiplier = 0.05;

								vec2 pnormalCoord1 = rainPos + vec2(wind.x, wind.y);
								vec3 pnormalNoise1 = texture2D(noisetex, pnormalCoord1).rgb;
								vec2 pnormalCoord2 = rainPos + vec2(wind.x * -1.5, wind.y * -1.0);
								vec3 pnormalNoise2 = texture2D(noisetex, pnormalCoord2).rgb;

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
						if (isEyeInWater == 1) specularColor *= underwaterColor.rgb * 8.0;
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
					#ifdef COMPBR
						if (cauldron > 0.0) skymapMod = (min(length(shadow), 0.475) + 0.515) * float(smoothness > 0.9);
						else
					#endif
					skymapMod = min(length(shadow), 0.5);
				#endif
				
				vec3 specularHighlight = vec3(0.0);
				specularHighlight = GetSpecularHighlight(smoothness - cauldron, metalness, f0, specularColor, rawAlbedo,
												shadow, newNormal, viewPos);
				#if defined LIGHT_LEAK_FIX && !defined END
					if (isEyeInWater == 0) specularHighlight *= pow(lightmap.y, 2.5);
					else specularHighlight *= 0.15 + 0.85 * pow(lightmap.y, 2.5);
				#endif
				albedo.rgb += specularHighlight;
			#endif
		#endif
		
		#ifdef SHOW_LIGHT_LEVELS
			if (lmCoord.x < 0.533334 && quarterNdotU > 0.99 && foliage + leaves < 0.1) {
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

	#if THE_FORBIDDEN_OPTION > 1
		albedo = min(albedo, vec4(1.0));
	#endif

	#ifdef GREEN_SCREEN
		if (greenScreen > 0.5) {
			albedo.rgb = vec3(0.0, 0.1, 0.0);
			#if defined ADV_MAT && defined REFLECTION_SPECULAR
				smoothness = 0.0;
				metalData = 0.0;
				skymapMod = 0.51;
			#endif
		}
	#endif

/* DRAWBUFFERS:0 */
gl_FragData[0] = albedo;

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
		/* DRAWBUFFERS:0361 */
		gl_FragData[1] = vec4(smoothness, metalData, skymapMod, 1.0);
		gl_FragData[2] = vec4(EncodeNormal(newNormal), 0.0, 1.0);
		gl_FragData[3] = vec4(rawAlbedo, 1.0);

		#ifdef COLORED_LIGHT
			/* DRAWBUFFERS:03618 */
			gl_FragData[4] = vec4(lightAlbedo, 1.0);
		#endif
	#else
		#ifdef COLORED_LIGHT
			/* DRAWBUFFERS:08 */
			gl_FragData[1] = vec4(lightAlbedo, 1.0);
		#endif
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

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

#if defined FOG1 && defined FOG1_CHECK
uniform float far;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

#ifdef ADV_MAT
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
void main() {
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	int blockID = int(mc_Entity.x + 0.5);
	if (blockID > 19999.5) {
		blockID -= 10000;
		if ((blockID > 13009.5 && blockID < 13011.5) || (blockID > 13100.5 && blockID < 13103.5)) blockID = 10009;
		if (blockID > 14023.5 && blockID < 14026.5) blockID = 11023;
		blockID -= int(floor(max(0.5, blockID - 9999.5)/3000.0) * 3000 + 0.5);
	}

	#if defined FOG1 && defined FOG1_CHECK
		float lWorldPos = length(position.xz) * 1;
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10.0));
		if (fog > 0.9) {
			gl_Position = vec4(0.0, 0.0, 1000.0, 0.0);
			return;
		}
	#endif
	
	#if THE_FORBIDDEN_OPTION > 1
		if (length(position.xz) > 0.0) {
			gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
			return;
		}
	#endif

	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADV_MAT
		#if defined NORMAL_MAPPING || defined REFLECTION_RAIN
			binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
			tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
			
			#if defined PARALLAX || defined SELF_SHADOW
				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									  tangent.y, binormal.y, normal.y,
									  tangent.z, binormal.z, normal.z);
			
				viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
				dist = length(gl_ModelViewMatrix * gl_Vertex);
			#endif
		#endif

		vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoord - midCoord;

		#ifdef COMPBR
			float texCoordDist = length(texMinMidCoord);
		#endif
		#if !defined COMPBR || defined NORMAL_MAPPING
			vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
			vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
			
			vTexCoord.xy= sign(texMinMidCoord) * 0.5 + 0.5;
		#endif
	#endif

	color = gl_Color;

	#ifdef SNOW_MODE
		noSnow = 0.0;
	#endif
	#ifdef COLORED_LIGHT
		lightVarying = 0.0;
	#endif
	
	mat = 0.0; quarterNdotUfactor = 1.0; mipmapDisabling = 0.0; specR = 0.0; specG = 0.0; specB = 0.0;

	#include "/lib/ifchecking/terrainVertex.glsl"

	mat += 0.25;
	
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);

	#ifdef OLD_LIGHTING_FIX
		eastVec = normalize(gbufferModelView[0].xyz);
		northVec = normalize(gbufferModelView[2].xyz);
	#endif

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