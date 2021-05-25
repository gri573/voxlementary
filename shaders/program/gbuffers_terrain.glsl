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
		#endif

		#ifdef PARALLAX
			float skipParallax = float(blockEntityId == 63 || material == 4.0); // Fixes broken signs and lava with pom
			if (skipParallax < 0.5) {
				GetParallaxCoord(parallaxFade, newCoord);
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
				if (mat > 100.5 && mat < 10000.0) {
				if (mat < 109.5) {
				if (mat < 104.5) {
					if (material == 101.0) { // Redstone Stuff
						float comPos = fract(worldPos.y + cameraPosition.y);
						if (comPos > 0.18) emissive = float((albedo.r > 0.65 && albedo.r > albedo.b * 1.0) || albedo.b > 0.99);
						else emissive = float(albedo.r > albedo.b * 3.0 && albedo.r > 0.5) * 0.125;
						emissive *= max(0.65 - 0.3 * dot(albedo.rgb, vec3(1.0, 1.0, 0.0)), 0.0);
						if (specB > 900.0) { // Observer
							emissive *= float(albedo.r > albedo.g * 1.5);
						}
					}
					#ifdef EMISSIVE_NETHER_STEMS
					else if (material == 102.0) { // Warped Stem+
						float core = float(albedo.r < 0.1);
						float edge = float(albedo.b > 0.35 && albedo.b < 0.401 && core == 0.0);
						emissive = core * 0.195 + 0.035 * edge;
					}
					else if (material == 103.0) { // Crimson Stem+
						emissive = float(albedo.b < 0.16);
						emissive = min(pow2(lAlbedoP * lAlbedoP) * emissive * 3.0, 0.3);
					}
					#endif
					else if (material == 104.0) { // Command Blocks
						vec3 comPos = fract(worldPos.xyz + cameraPosition.xyz);
						comPos = abs(comPos - vec3(0.5));
						float comPosM = min(max(comPos.x, comPos.y), min(max(comPos.x, comPos.z), max(comPos.y, comPos.z)));
						emissive = 0.0;
						if (comPosM < 0.1875) { // Command Block Center
							vec3 dif = vec3(albedo.r - albedo.b, albedo.r - albedo.g, albedo.b - albedo.g);
							dif = abs(dif);
							emissive = float(max(dif.r, max(dif.g, dif.b)) > 0.1) * 25.0;
							emissive *= float(albedo.r > 0.44 || albedo.g > 0.29);
						}
						smoothness = 0.385;
						metalness = 1.0;
					}
				} else {
					if (material == 105.0) { // Snowy Grass Block
						if (lAlbedoP > 1.0) smoothness = lAlbedoP * lAlbedoP * 0.165;
						else metalness = 0.003;
					}
					else if (material == 107.0) // Furnaces Lit
						emissive = 0.75 * float(albedo.r * albedo.r > albedo.b * 4.0 || (albedo.r > 0.9 && (albedo.r > albedo.b || albedo.r > 0.99)));
					else if (material == 108.0) // Torch, Soul Torch
						emissive = float(albedo.r > 0.9 || albedo.b > 0.65) * (1.4 - albedo.b * 1.05);
					else if (material == 109.0) { // Obsidian++
						smoothness = max(smoothness, 0.375);
						if (specB > 0.5) { // Crying Obsidian, Respawn Anchor
							emissive = (albedo.b - albedo.r) * albedo.r * 6.0;
							emissive *= emissive * emissive;
							emissive = clamp(emissive, 0.05, 1.0);
							if (lAlbedoP > 1.6 || albedo.r > albedo.b * 1.7) emissive = 1.0;
						} else {
							if (lAlbedoP > 0.75) { // Enchanting Table Diamond
								f0 = smoothness;
								smoothness = 0.9 - f0 * 0.1;
								metalness = 0.0;
							}
							if (albedo.r > albedo.g + albedo.b) { // Enchanting Table Cloth
								smoothness = max(smoothness - 0.45, 0.0);
								metalness = 0.0;
							}
						}
					}
				}
				} else {
				if (mat < 113.5) {
					if (material == 110.0) { // Campfires, Powered Lever
						if (albedo.g + albedo.b > albedo.r * 2.3 && albedo.g > 0.38 && albedo.g > albedo.b * 0.9) emissive = 0.09;
						if (albedo.r > albedo.b * 3.0 || albedo.r > 0.8) emissive = 0.65;
						emissive *= max(1.0 - albedo.b + albedo.r, 0.0);
						emissive *= lAlbedoP;
					}
					else if (material == 111.0) { // Cauldron, Hopper, Anvils
						if (color.r < 0.99) { // Cauldron
							cauldron = 1.0, smoothness = 1.0, metalness = 0.0;
							skymapMod = lmCoord.y * 0.475 + 0.515;
							#if defined REFLECTION_RAIN && defined RAIN_REF_BIOME_CHECK
								noRain = 1.0;
							#endif
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
						}
					}
					else if (material == 112.0) { // Chorus Plant, Chorus Flower Age 5
						if (albedo.g > 0.55 && albedo.r < albedo.g * 1.1) {
							emissive = 1.0;
						}
					}
					else if (material == 113.0) { // Emissive Ores
						float stoneDif = max(abs(albedo.r - albedo.g), max(abs(albedo.r - albedo.b), abs(albedo.g - albedo.b)));
						float brightFactor = max(lAlbedoP - 1.5, 0.0);
						float ore = max(max(stoneDif - 0.175 + specG, 0.0), brightFactor);
						emissive *= sqrt4(ore) * 0.15;
						metalness = 0.0;
						if (albedo.r > 0.95 && albedo.b + albedo.g < 1.1 && albedo.b + albedo.g > 0.5 && albedo.g < albedo.b + 0.1)
							// White pixels of the new Redstone Ore
							albedo.rgb *= vec3(0.8, 0.2, 0.2);
					}
				} else {
					if (material == 114.0) { // Wet Farmland
						if (lAlbedoP > 0.3) smoothness = lAlbedoP * 0.7;
						else smoothness = lAlbedoP * 2.7;
						smoothness = min(smoothness, 1.0);
					}
					else if (material == 115.0) { // Beacon
						vec3 comPos = fract(worldPos.xyz + cameraPosition.xyz);
						comPos = abs(comPos - vec3(0.5));
						float comPosM = max(max(comPos.x, comPos.y), comPos.z);
						if (comPosM < 0.4 && albedo.b > 0.5) { // Beacon Core
							albedo.rgb = vec3(0.625, 1.0, 0.975);
							emissive = 1.9;
						}
					}
					else if (material == 116.0) { // End Rod
						if (lAlbedoP > 1.3) {
							smoothness = 0.0;
							emissive = 0.45;
						}
					}
					else if (material == 117.0) { // Rails
						if (albedo.r > albedo.g * 2.0 + albedo.b) {
							if (lAlbedoP > 0.45) { // Rail Redstone Lit
								emissive = lAlbedoP;
							} else { // Rail Redstone Unlit
								smoothness = 0.4;
								metalness = 1.0;
							}
						} else {
							if (albedo.r > albedo.g + albedo.b || abs(albedo.r - albedo.b) < 0.1) { // Rail Gold, Rail Iron
								smoothness = 0.4;
								metalness = 1.0;
							}
						}
					}
				}
				}
				}

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
							else           dif = min(dif + normalClamp, 0.0);
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
					parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix);
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
					parallaxShadow, emissive, subsurface, leaves, materialAO);

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
								f0         = mix(f0        , 0.02, skymapModx2);

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
			
			vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
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

	if (blockID ==  31 || blockID ==   6 || blockID ==  59 || 
		blockID == 175 || blockID == 176 || blockID ==  83 || 
		blockID == 104 || blockID == 105 || blockID == 11019) // Foliage
		mat = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87), quarterNdotUfactor = 0.0;
		
	if (blockID == 18 || blockID == 9600 || blockID == 9100 || blockID == 10231) // Leaves, Vine, Lily Pad, Cave Vines
		#ifdef COMPBR
			specR = 12.07, specG = 0.003,
		#endif
		mat = 2.0;

	if (blockID == 10) // Lava
		#ifdef COLORED_LIGHT
			lightVarying = 3.0,
		#endif
		mat = 4.0,
		specB = 0.25, quarterNdotUfactor = 0.0, color.a = 1.0, lmCoord.x = 0.9, color.rgb = vec3(LAVA_INTENSITY * 0.83);
	if (blockID == 1010) // Fire
		#ifdef COLORED_LIGHT
			lightVarying = 3.0,
		#endif
		specB = 0.25, lmCoord.x = 0.98, color.a = 1.0, color.rgb = vec3(FIRE_INTENSITY * 0.67);
	if (blockID == 210) // Soul Fire
		#ifdef COLORED_LIGHT
			lightVarying = 2.0,
		#endif
		#ifdef SNOW_MODE
			noSnow = 1.0,
		#endif
		specB = 0.25, lmCoord.x = 0.0, color.a = 1.0, color.rgb = vec3(FIRE_INTENSITY * 0.53);

	if (blockID == 12345) // Custom Emissive
		lmCoord = vec2(0.0), specB = 2.05;

	#ifdef COMPBR
	if (blockID < 10218.5) {
    if (blockID < 10115.5) {
    if (blockID < 10052.5) {
    if (blockID < 10008.5) {
	if (blockID < 10002.5) {
        if (blockID == 10000) { // Grass Block
			if (color.b < 0.99) { // Grass Block Grass
				specR = 8.034, specG = 0.003;
			} else { // Grass Block Dirt
				specR = 2.035, specG = 0.003;
			}
		}
		else if (blockID == 10001) // Snowy Grass Block
			mat = 105.0,
			specR = 2.035;
		else if (blockID == 10002) // Sand
			specR = 80.004, mat = 3.0;
	} else {
		if (blockID == 10003) // Stone+, Deepslate+
			specR = 20.04;
		else if (blockID == 10007) // Dirt, Coarse Dirt, Podzol, Grass Path, Dirt Path, Farmland Dry
			specR = 2.035, specG = 0.003;
		else if (blockID == 10008) // Glass, Glass Pane
			specR = 0.8, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87), mipmapDisabling = 1.0;
	}
    } else {
	if (blockID < 10012.5) {
		if (blockID == 10009) // Snow, Snow Block
			specR = 18.037, mat = 3.0;
		else if (blockID == 10010) // Gravel
			specR = 32.06;
		else if (blockID == 10012) // Cobblestone+, Clay
			specR = 18.037;
	} else {
		if (blockID == 10050) // Red Sand
			specR = 80.115, mat = 3.0;
		else if (blockID == 10051) // Andesite, Diorite, Granite, Basalt+, Calcite, Tuff, Dripstone+
			specR = 12.05;
		else if (blockID == 10052) // Terracottas
			specR = 2.045, mat = 15000.0, color.rgb = vec3(0.03, 1.0, 0.0);
    }
	}
    } else {
    if (blockID < 10106.5) {
	if (blockID < 10102.5) {
		if (blockID == 10053) // Packed Ice, Blue Ice, Purpur Block+
			specR = 20.055;

		else if (blockID == 10101) // Birch Log+
			specR = 3.055;
		else if (blockID == 10102) // Oak Log+, Bone Block
			specR = 8.055;
	} else {
		if (blockID == 10103) // Jungle Log+, Acacia Log+
			specR = 6.055;
		else if (blockID == 10105) // Spruce Log+, Scaffolding, Cartography Table, Bee Nest, Beehive
			specR = 6.06;
		else if (blockID == 10106) // Warped Log+
			specR = 10.07, mat = 102.0,
			mipmapDisabling = 1.0;
	}
    } else {
	if (blockID < 10111.5) {
		if (blockID == 10107) // Crimson Log+
			specR = 10.07, mat = 103.0,
			mipmapDisabling = 1.0;
		else if (blockID == 10108) // Dark Oak Log+
			specR = 2.04;		
		else if (blockID == 10111) // Birch Planks+, Fletching Table, Loom
			specR = 20.036;
	} else {
		if (blockID == 10112) // Oak Planks+, Jungle Planks+, Bookshelf, Composter
			specR = 20.055;
		else if (blockID == 10114) // Acacia Planks+, Barrel, Honeycomb Block
			specR = 20.075;
		else if (blockID == 10115) // Spruce Planks+, Smithing Table
			specR = 20.12;
    }
	}
    }
    } else {
    if (blockID < 10207.5) {
	if (blockID < 10201.5) {
	if (blockID < 10118.5) {
		if (blockID == 10116) // Warped Planks+
			specR = 12.075;
		else if (blockID == 10117) // Crimson Planks+, Note Block, Jukebox
			specR = 12.095;
		else if (blockID == 10118) // Dark Oak Planks+
			specR = 20.4;
	} else {
		if (blockID == 10199) // Stone Bricks++
			specR = 20.09;
		else if (blockID == 10200) // Netherrack, Crimson/Warped Nylium, Nether Ores, Blackstone++
			specR = 12.087, mat = 20000.0, color.rgb = vec3(1.0, 0.7, 1.0);
		else if (blockID == 10201) // Polished Andesite, Polished Diorite, Polished Granite, Melon
			specR = 6.085;
	}
	} else {
	if (blockID < 10205.5) {
		if (blockID == 10202) // Nether Bricks+
			specR = 12.375, mat = 20000.0, color.rgb = vec3(0.55, 1.0, 1.0);
		else if (blockID == 10203 || blockID == 10204) // Iron Block+
			specR = 6.07, specG = 131.0;
		else if (blockID == 10205) // Gold Block+
			specR = 8.1, mat = 30000.0, color.rgb = vec3(1.0, 1.0, 1.0), specG = 1.0;
	} else {
		if (blockID == 10206) // Diamond Block
			specR = 100.007, mat = 106.0;
		else if (blockID == 10207) // Emerald Block
			specR = 7.2, mat = 106.0;
	}
	}
    } else {
	if (blockID < 10212.5) {
	if (blockID < 10209.5) {
		if (blockID == 10208) // Netherite Block
			specR = 12.135, specG = 0.7;
		else if (blockID == 10209) // Ancient Debris
			#ifdef GLOWING_DEBRIS
				specB = 6.3, color.a = 1.0,
			#endif
			specR = 8.07, specG = 0.7;
	} else {
		if (blockID == 10210) // Block of Redstone
			#ifdef GLOWING_REDSTONE_BLOCK
				specB = 7.99, mat = 20000.0, color.rgb = vec3(1.1), color.a = 1.0,
			#endif
			specR = 8.05, specG = 1.0;
		else if (blockID == 10211) // Lapis Lazuli Block
			#ifdef GLOWING_LAPIS_BLOCK
				specB = 6.99, mat = 20000.0, color.rgb = vec3(1.13), color.a = 1.0,
			#endif
			specR = 16.11;
		else if (blockID == 10212) // Carpets, Wools
			specR = 2.02, mat = 15000.0, color.rgb = vec3(0.03, 1.0, 0.0), specG = 0.003, lmCoord.x *= 0.96;
	}
	} else {
	if (blockID < 10215.5) {
		if (blockID == 10213) // Obsidian
			specR = 2.15, specG = 0.6, mat = 109.0;
		else if (blockID == 10214) // Enchanting Table
			specR = 2.15, specG = 0.6, mat = 109.0;
		else if (blockID == 10215) // Chain
			specR = 0.5, specG = 1.0,
			lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
	} else {
		if (blockID == 10216) // Cauldron, Hopper, Anvils
			specR = 1.08, specG = 1.0, mat = 111.0,
			lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
		else if (blockID == 10217) // Sandstone+
			specR = 24.029;
		else if (blockID == 10218) // Red Sandstone+
			specR = 24.085;
	}
	}
    }
    }
    } else {
	if (blockID < 11009.5) {
	if (blockID < 10231.5) {
	if (blockID < 10225.5) {
	if (blockID < 10221.5) {
		if (blockID == 10219) // Quartz+, Daylight Detector, Dried Kelp Block
			specR = 16.082;
		else if (blockID == 10220) // Chorus Plant, Chorus Flower Age 5
			mat = 112.0, specR = 6.1,
			mipmapDisabling = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
		else if (blockID == 10221) // Chorus Flower Age<=4
			specB = 5.0001, specR = 5.07,
			mipmapDisabling = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
	} else {
		if (blockID == 10222) // End Stone++, Smooth Stone+, Lodestone, TNT, Pumpkin+, Mushroom Blocks, Polished Deepslate+
			specR = 12.065;
		else if (blockID == 10224) // Concretes
			specR = 3.044, mat = 15000.0, color.rgb = vec3(0.03, 1.0, 0.0);
		else if (blockID == 10225) // Concrete Powders
			specR = 6.014, mat = 15000.0, color.rgb = vec3(0.01, 1.0, 0.0);
	}
	} else {
	if (blockID < 10228.5) {
		if (blockID == 10226) // Bedrock
			specR = 16.0675;
		else if (blockID == 10227) // Hay Block, Target
			specR = 16.085, specG = 0.003, mat = 20000.0, color.rgb = vec3(1.0, 0.0, 0.0);
		else if (blockID == 10228) // Bricks+, Furnaces Unlit, Dispenser, Dropper
			specR = 10.07;
	} else {
		if (blockID == 10229) // Farmland Wet
			mat = 114.0;
		else if (blockID == 10230) // Crafting Table
			specR = 24.06;
		else if (blockID == 10231) // Cave Vines (Hanging Glow Berries)
			specB = 8.3, mat = 20000.0, color.rgb = vec3(1.2, -5.0, 0.0),
			mipmapDisabling = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
	}
	}
	} else {
	if (blockID < 11003.5) {
	if (blockID < 10234.5) {
		if (blockID == 10232) // Prismarine+
			specR = 3.08, specG = 0.75;
		else if (blockID == 10233) // Dark Prismarine+
			specR = 3.11, specG = 0.75;
		else if (blockID == 10234) // Glazed Terracottas
			specR = 0.5;
	} else {
		if (blockID == 11001) // Glowstone
			#ifdef COLORED_LIGHT
				lightVarying = 3.0,
			#endif
			lmCoord.x = 0.87, specB = 3.075, color.rgb = vec3(0.69, 0.68, 0.65),
			mipmapDisabling = 1.0;
		else if (blockID == 11002) // Sea Lantern
			#ifdef COLORED_LIGHT
				lightVarying = 4.0,
			#endif
			lmCoord.x = 0.93, specB = 9.0055, color.rgb = vec3(0.62, 0.60, 0.657),
			quarterNdotUfactor = 0.0, mipmapDisabling = 1.0;
		else if (blockID == 11003) // Magma Block
			lmCoord.x = 0.0, specB = 2.05, color.rgb = vec3(0.85, 0.84, 0.7),
			quarterNdotUfactor = 0.0, mipmapDisabling = 1.0;
	}
	} else {
	if (blockID < 11006.5) {
		if (blockID == 11004) // Shroomlight
			#ifdef COLORED_LIGHT
				lightVarying = 1.0,
			#endif
			lmCoord.x = 0.93, specB = 16.005, color.rgb = vec3(0.45),
			quarterNdotUfactor = 0.0;
		else if (blockID == 11005) // Redstone Lamp Lit
			#ifdef COLORED_LIGHT
				lightVarying = 3.0,
			#endif
			lmCoord.x = 0.915, specB = 5.099, color.rgb = vec3(0.6), quarterNdotUfactor = 0.0,
			specG = 0.63, specR = 0.55, mipmapDisabling = 1.0;
		else if (blockID == 11006) // Redstone Lamp Unlit
			specG = 0.63, specR = 3.15,	mipmapDisabling = 1.0;
	} else {
		if (blockID == 11007) // Jack o'Lantern
			#ifdef COLORED_LIGHT
				lightVarying = 3.0,
			#endif
			specR = 12.065, lmCoord.x = 0.87, specB = 16.0001, color.rgb = vec3(1.0, 1.0, 1.15), mipmapDisabling = 1.0;
		else if (blockID == 11008) // Beacon
			#ifdef COLORED_LIGHT
				lightVarying = 4.0,
			#endif
			mat = 115.0, lmCoord.x = 0.87;
		else if (blockID == 11009) // End Rod
			#ifdef COLORED_LIGHT
				lightVarying = 4.0,
			#endif
			specR = 1.0, lmCoord.x = 0.88, mat = 116.0;
	}
	}
	}
	} else {
	if (blockID < 11021.5) {
	if (blockID < 11015.5) {
	if (blockID < 11012.5) {
		if (blockID == 11010) // Dragon Egg
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			specB = 4.1, mat = 20000.0, color.rgb = vec3(10.0);
		else if (blockID == 11011) // Redstone Wire
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			specB = smoothstep(0.0, 1.0, pow2(length(color.rgb))) * 0.07;
		else if (blockID == 11012) // Redstone Torch
			#ifdef COLORED_LIGHT
				lightVarying = 2.0,
			#endif
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			mat = 101.0, lmCoord.x = min(lmCoord.x, 0.86), mipmapDisabling = 1.0;
	} else {
		if (blockID == 11013) // Redstone Repeater & Comparator Powered
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			mat = 101.0, mipmapDisabling = 1.0;
		else if (blockID == 11014) // Redstone Repeater & Comparator Unpowered
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			mat = 101.0, mipmapDisabling = 1.0;
		else if (blockID == 11015) // Observer
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			specR = 10.07, mat = 101.0, specB = 1000.0;
	}
	} else {
	if (blockID < 11018.5) {
		if (blockID == 11016) // Command Blocks
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			mat = 104.0, mipmapDisabling = 1.0;
		else if (blockID == 11017) // Lantern
			#ifdef COLORED_LIGHT
				lightVarying = 3.0,
			#endif
			lmCoord.x = 0.87, specB = 3.4, mat = 20000.0, color.rgb = vec3(1.0, 0.0, 0.0),
			specR = 0.5, specG = 1.0;
		else if (blockID == 11018) // Soul Lantern
			#ifdef COLORED_LIGHT
				lightVarying = 2.0,
			#endif
			lmCoord.x = min(lmCoord.x, 0.87), specB = 4.15, mat = 20000.0, color.rgb = vec3(0.0, 1.0, 0.0),
			specR = 0.5, specG = 1.0;
	} else {
		if (blockID == 11019) // Crimson Fungus, Warped Fungus
			specB = 16.007, mat = 20000.0, color.rgb = vec3(1.0, 0.0, 0.0);
		else if (blockID == 11020) // Furnaces Lit
			#ifdef COLORED_LIGHT
				lightVarying = 3.0,
			#endif
			specR = 10.07, mat = 107.0, lmCoord.x = pow(lmCoord.x, 1.5);
		if (blockID == 11021) // Torch
			#ifdef COLORED_LIGHT
				lightVarying = 1.0,
			#endif
			lmCoord.x = min(lmCoord.x, 0.86), mat = 108.0, mipmapDisabling = 1.0;
	}
	}
	} else {
	if (blockID < 11028.5) {
	if (blockID < 11025.5) {
		if (blockID == 11022) // Soul Torch
			#ifdef COLORED_LIGHT
				lightVarying = 2.0,
			#endif
			lmCoord.x = min(lmCoord.x, 0.86), mat = 108.0, mipmapDisabling = 1.0;
		else if (blockID == 11023) // Crying Obsidian, Respawn Anchor
			#ifdef COLORED_LIGHT
				lightVarying = 2.0,
			#endif
			specR = 2.15, specG = 0.6, mat = 109.0,
			specB = 0.75, lmCoord.x = min(lmCoord.x, 0.88), mipmapDisabling = 1.0;
		else if (blockID == 11024) // Campfire, Powered Lever
			#ifdef COLORED_LIGHT
				lightVarying = 3.0,
			#endif
			lmCoord.x = min(lmCoord.x, 0.885), mat = 110.0;
		else if (blockID == 11025) // Soul Campfire
			#ifdef COLORED_LIGHT
				lightVarying = 2.0,
			#endif
			lmCoord.x = min(lmCoord.x, 0.885), mat = 110.0;
	} else {
		if (blockID == 11026) // Jigsaw Block, Structure Block
			#ifdef SNOW_MODE
				noSnow = 1.0,
			#endif
			specB = 8.004, quarterNdotUfactor = 0.0;
		else if (blockID == 11027) // Sea Pickle
			specB = 12.0003, lmCoord.x = min(lmCoord.x, 0.885), mipmapDisabling = 1.0;
		else if (blockID == 11028) // Spawner
			specR = 0.5, specG = 0.8, specB = 32.01, mat = 20000.0, color.rgb = vec3(2.6, 0.0, 0.0), mipmapDisabling = 1.0;
	}
	} else {
	if (blockID < 11032.5) {
		if (blockID == 11029) // Diamond Ore, Emerald Ore
			#ifdef EMISSIVE_ORES
				specB = 0.30, mat = 113.0, mipmapDisabling = 1.0,
			#endif
			specR = 20.04;
		else if (blockID == 11030) // Gold Ore, Lapis Ore
			#ifdef EMISSIVE_ORES
				specB = 0.08, mat = 113.0, mipmapDisabling = 1.0,
			#endif
			specR = 20.04;
		else if (blockID == 11031) // Redstone Ore Unlit
			#ifdef EMISSIVE_ORES
				specB = 4.27, mat = 113.0, mipmapDisabling = 1.0,
			#endif
			specR = 20.04;
		else if (blockID == 11032) // Redstone Ore Lit
			#ifdef COLORED_LIGHT
				lightVarying = 2.0,
			#endif
			lmCoord.x *= 0.9,
			specB = 4.27, mat = 113.0, mipmapDisabling = 1.0,
			specR = 20.04;
	} else {
		if (blockID == 11033) // Iron Ore
			#ifdef EMISSIVE_ORES
				specB = 0.05, mat = 113.0, mipmapDisabling = 1.0, specG = 0.07,
			#endif
			specR = 20.04;
		else if (blockID == 11034) // Copper Ore
			#ifdef EMISSIVE_ORES
				specB = 0.20, mat = 113.0, mipmapDisabling = 1.0, specG = 0.175,
			#endif
			specR = 20.04;
		else if (blockID == 11050) // Rails
			mat = 117.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87), mipmapDisabling = 1.0;
    }
	}
	}
	}
	}

		// Too bright near a light source fix
		if (blockID == 99 || blockID == 10204)
			lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);

		// No shading
		if (blockID == 20091 || blockID == 901 || blockID == 97)
			quarterNdotUfactor = 0.0;

		// Mipmap Fix
		if (blockID == 880 || blockID == 76 || blockID == 98 || blockID == 95)
			mipmapDisabling = 1.0;
	#endif

	#if !defined COMPBR && defined COLORED_LIGHT
	if (blockID < 11012.5) {
	if (blockID < 11005.5) {
		if (blockID == 11001) // Glowstone
			lightVarying = 3.0;
		else if (blockID == 11002) // Sea Lantern
			lightVarying = 4.0;
		else if (blockID == 11004) // Shroomlight
			lightVarying = 1.0;
		else if (blockID == 11005) // Redstone Lamp Lit
			lightVarying = 3.0;
	} else {
		if (blockID == 11007) // Jack o'Lantern
			lightVarying = 3.0;
		else if (blockID == 11008) // Beacon
			lightVarying = 4.0;
		else if (blockID == 11009) // End Rod
			lightVarying = 4.0;
		else if (blockID == 11012) // Redstone Torch
			lightVarying = 2.0;
	}
	} else {
	if (blockID < 11022.5) {
		if (blockID == 11017) // Lantern
			lightVarying = 3.0;
		else if (blockID == 11018) // Soul Lantern
			lightVarying = 2.0;
		else if (blockID == 11020) // Furnaces Lit
			lightVarying = 3.0;
		else if (blockID == 11021) // Torch
			lightVarying = 1.0;
		else if (blockID == 11022) // Soul Torch
			lightVarying = 2.0;
	} else {
		if (blockID == 11023) // Crying Obsidian, Respawn Anchor
			lightVarying = 2.0;
		else if (blockID == 11024) // Campfire
			lightVarying = 3.0;
		else if (blockID == 11025) // Soul Campfire
			lightVarying = 2.0;
		else if (blockID == 11032) // Redstone Ore Lit
			lightVarying = 2.0;
	}
	}
	#endif

	if (blockID == 300) // No Vanilla AO
		color.a = 1.0;

	if (lmCoord.x > 0.99) // Clamp full bright emissives
		lmCoord.x = 0.9, quarterNdotUfactor = 0.0;

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