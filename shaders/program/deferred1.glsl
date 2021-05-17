/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldDay;
uniform int worldTime;

uniform float blindFactor, nightVision;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight, aspectRatio;
uniform float shadowFade;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

#ifdef AO
uniform sampler2D colortex4;
#endif

#ifdef AURORA
uniform int moonPhase;
#endif

#if defined ADVANCED_MATERIALS || defined GLOWING_ENTITY_FIX
uniform sampler2D colortex3;
#endif

#if (defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR) || defined SEVEN || (defined END && END_SKY > 0) || (defined NETHER && defined NETHER_SMOKE)
uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D colortex6;
uniform sampler2D colortex1;
uniform sampler2D noisetex;
#endif

#if defined WEATHER_PERBIOME || defined AURORA
uniform float isDry, isRainy, isSnowy;
#endif

#ifdef INTERACTIVE_WATER
uniform sampler2D colortex8;
uniform sampler2D shadowcolor0;
#endif

//Optifine Constants//
#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
const bool colortex0MipmapEnabled = true;
const bool colortex3MipmapEnabled = false;
const bool colortex6MipmapEnabled = true;
#endif

#ifdef INTERACTIVE_WATER
const bool colortex8Clear = false;
/*
const int colortex8Format = RGBA16F;
*/
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

vec2 aoOffsets[4] = vec2[4](
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0,  0.0),
	vec2( 0.0, -1.0)
);

#if WORLD_TIME_ANIMATION == 2
float modifiedWorldDay = mod(worldDay, 100.0) + 5.0;
float frametime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
float cloudtime = frametime;
#endif
#if WORLD_TIME_ANIMATION == 1
float modifiedWorldDay = mod(worldDay, 100.0) + 5.0;
float frametime = frameTimeCounter * ANIMATION_SPEED;
float cloudtime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
#endif
#if WORLD_TIME_ANIMATION == 0
float frametime = frameTimeCounter * ANIMATION_SPEED;
float cloudtime = frametime;
#endif

#ifdef END
vec3 lightNight = vec3(0.0);
#endif

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

float InterleavedGradientNoise(){
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 32.0);
}

#ifdef AO
float GetAmbientOcclusion(float z) {
	float ao = 0.0;
	float tw = 0.0;
	float lz = GetLinearDepth(z);

	#if AO_QUALITY == 1 && AA > 1
		vec2 halfView = vec2(viewWidth, viewHeight) / 2.0;
		vec2 coord1 = (floor(texCoord * halfView + 1.0)) / halfView;
		vec2 coord2 = texCoord * 0.5;
	#else
		vec2 coord1 = texCoord;
		vec2 coord2 = texCoord;
	#endif
	
	for(int i = 0; i < 4; i++) {
		vec2 offset = aoOffsets[i] / vec2(viewWidth, viewHeight);
		float samplez = GetLinearDepth(texture2D(depthtex0, coord1 + offset * 2.0).r);
		float wg = max(1.0 - 2.0 * far * abs(lz - samplez), 0.0);
		ao += texture2D(colortex4, coord2 + offset).r * wg;
		tw += wg;
	}
	ao /= tw;
	if(tw < 0.0001) ao = texture2D(colortex4, coord2).r;

	float aoStrength = AO_STRENGTH;

	#if AO_QUALITY == 2 || (AO_QUALITY == 1 && AA <= 1)
		aoStrength *= 0.75;
	#endif
	
	//return pow(texture2D(colortex4, coord2).r, AO_STRENGTH);
	return pow(ao, aoStrength);
}
#endif

//Includes//
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"

#ifdef OVERWORLD
#include "/lib/atmospherics/sky.glsl"
#endif

#if defined SEVEN || (defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR && defined OVERWORLD) || (defined END && END_SKY > 0) || (defined NETHER && defined NETHER_SMOKE)
#ifdef AURORA
#include "/lib/color/auroraColor.glsl"
#endif

#include "/lib/atmospherics/clouds.glsl"
#endif

#include "/lib/atmospherics/fog.glsl"

#ifdef BLACK_OUTLINE
#include "/lib/outline/blackOutline.glsl"
#endif

#ifdef PROMO_OUTLINE
#include "/lib/outline/promoOutline.glsl"
#endif

#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
#include "/lib/util/encode.glsl"
#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/materialDeferred.glsl"
#include "/lib/reflections/roughReflections.glsl"
#endif

#ifdef INTERACTIVE_WATER
#include "/lib/vx/voxelPos.glsl"
#endif

//Program//
void main() {
    vec4 color = texture2D(colortex0, texCoord);
	float z    = texture2D(depthtex0, texCoord).r;

	float dither = Bayer64(gl_FragCoord.xy);
	
	vec4 screenPos = vec4(texCoord, z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#if defined NETHER && defined NETHER_SMOKE
		vec3 netherNebula = DrawNetherNebula(viewPos.xyz, dither, pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4);
	#endif

	if (z < 1.0) {
		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);
		float lViewPos = length(viewPos.xyz);
	
		#ifdef AO
			float ao = clamp(GetAmbientOcclusion(z), 0.0, 1.0);
			float ambientOcclusion = ao;
		#endif

		#if defined ADVANCED_MATERIALS || defined GLOWING_ENTITY_FIX
			float skymapMod = texture2D(colortex3, texCoord).b;
			// skymapMod = 1.0 = Glowing Status Effect
			// skymapMod = 0.515 ... 0.99 = Cauldron
			// skymapMod = 0.51 = No SSAO (currently only for infinity rooms)
			// skymapMod = 0.0 ... 0.5 = Rain Puddles
			// skymapMod = 0.0 ... 0.1 = Specular Sky Reflections
		#endif
        
		vec3 worldPos = ToWorld(viewPos.xyz);

		#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
			float smoothness = 0.0, metalness = 0.0, f0 = 0.0, materialFormat = 0.0;
			vec3 normal = vec3(0.0), rawAlbedo = vec3(0.0);

			GetMaterials(materialFormat, smoothness, metalness, f0, normal, rawAlbedo, texCoord);
			float smoothnessP = smoothness;
			smoothness *= smoothness;
			
			float fresnel = pow(clamp(1.0 + dot(normal, nViewPos), 0.0, 1.0), 5.0);
			vec3 fresnel3 = vec3(0.0);
			
			if (materialFormat > 0.9) {
				fresnel3 = mix(mix(vec3(0.02), rawAlbedo*5, metalness), vec3(1.0), fresnel);
				if (metalness <= 0.004 && metalness > 0.0 && skymapMod == 0.0) fresnel3 = vec3(0.0);
				fresnel3 *= 0.25*smoothness;
			} else {
				#if MATERIAL_FORMAT == -1
					fresnel3 = mix(mix(vec3(0.02), rawAlbedo*5, metalness), vec3(1.0), fresnel);
					fresnel3 *= 0.25*smoothness;
				#endif
				#if MATERIAL_FORMAT == 0
					fresnel3 = mix(mix(vec3(max(f0, 0.02)), rawAlbedo*5, metalness), vec3(1.0), fresnel);
					if (f0 >= 0.9 && f0 < 1.0) {
						fresnel3 = ComplexFresnel(fresnel, f0) * 1.5;
						color.rgb *= 1.5;
					}
					fresnel3 *= 0.25*smoothness;
				#endif
			}

			float lFresnel3 = length(fresnel3);
			if (lFresnel3 < 0.0050) fresnel3 *= (lFresnel3 - 0.0025) / 0.0025;

			if (lFresnel3 > 0.0025) {
				vec4 reflection = vec4(0.0);
				vec3 skyReflection = vec3(0.0);

				#ifdef REFLECTION_ROUGH
					vec3 roughPos = worldPos + cameraPosition;
					roughPos *= 1000.0;
					//roughPos += fract(frameTimeCounter * 10.0);
					vec3 roughNoise1 = texture2D(noisetex, roughPos.xz).rgb;
					vec3 roughNoise2 = texture2D(noisetex, roughPos.xy).rgb;
					vec3 roughNoise3 = texture2D(noisetex, roughPos.yz).rgb;
					vec3 roughNoise = (roughNoise1 + roughNoise2 + roughNoise3) / 3.0;

					roughNoise = 0.05 * (roughNoise - vec3(0.5));

					float roughness = 1.0 - smoothnessP;
					if (materialFormat > 0.5) roughness *= 1.0 - 0.35 * float(metalness == 1.0);
					roughness *= roughness;
					roughNoise *= roughness;

					normal += roughNoise * 12.0;
				#endif
				
				float cauldron = float(skymapMod > 0.51 && skymapMod < 0.9905);

				float alternative = cauldron * 0.5;
				
				reflection = RoughReflection(viewPos.xyz, normal, dither, smoothness, colortex0, alternative);

				if (cauldron > 0.5) { 													//Cauldron Reflections
					#ifdef OVERWORLD
						fresnel3 = fresnel3 * 3.33333333 + vec3(0.0333333);

						float skymapModM = (skymapMod - 0.515) / 0.475;
						#if SKY_REF_FIX_1 == 1
							skymapModM = skymapModM * skymapModM;
						#elif SKY_REF_FIX_1 == 2
							skymapModM = max(skymapModM - 0.80, 0.0) * 5.0;
						#else
							skymapModM = max(skymapModM - 0.99, 0.0) * 100.0;
						#endif
						skymapModM = skymapModM * 0.5;

						vec3 skyReflectionPos = reflect(nViewPos, normal);
						float refNdotU = dot(skyReflectionPos, upVec);
						skyReflection = GetSkyColor(lightCol, refNdotU, skyReflectionPos, true);
						skyReflectionPos *= 1000000.0;

						#ifdef AURORA
							skyReflection += DrawAurora(skyReflectionPos, dither, 8, refNdotU);
						#endif
						#ifdef CLOUDS
							vec4 cloud = DrawCloud(skyReflectionPos, dither, lightCol, ambientCol, refNdotU, 3);
							float cloudMixRate = smoothness * smoothness * (3.0 - 2.0 * smoothness);
							skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
						#endif
						skyReflection = mix(vec3(0.001), skyReflection, skymapModM * 2.0);
					#endif
					#ifdef NETHER
						skyReflection = netherCol * 0.005;
					#endif
					#ifdef END
						float skymapModM = (skymapMod - 0.515) / 0.475;
						skyReflection = endCol * 0.025;
						#if END_SKY > 0
							vec3 skyReflectionPos = reflect(nViewPos, normal);
							skyReflectionPos *= 1000000.0;
							vec4 cloud = DrawEndCloud(skyReflectionPos, dither, endCol);
							skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
						#endif
						skyReflection *= 5.0 * skymapModM;
					#endif
					//color.rgb *= vec3(10.0, 0.0, 10.0);
				}
				if (skymapMod > 0.0 && skymapMod < 0.505) {
					#ifdef OVERWORLD												 //Rain Puddle + Specular Sky Reflections
						//fresnel3 = vec3(fresnel * 0.75 + 0.06) * smoothness * 1.6;

						float skymapModM = skymapMod * 2.0;

						vec3 skyReflectionPos = reflect(nViewPos, normal);
						float refNdotU = dot(skyReflectionPos, upVec);
						skyReflection = GetSkyColor(lightCol, refNdotU, skyReflectionPos, true);
						skyReflectionPos *= 1000000.0;

						#ifdef CLOUDS
							vec4 cloud = DrawCloud(skyReflectionPos, dither, lightCol, ambientCol, refNdotU, 3);
							float cloudMixRate = smoothness * smoothness * (3.0 - 2.0 * smoothness);
							skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
						#endif
						skyReflection *= 0.5 + 0.5 * rainStrengthS * rainStrengthS * rainStrengthS;
						skyReflection = mix(vec3(0.001), skyReflection * 5.0, skymapModM);
						//skyReflection = vec3(1.0, 0.0, 1.0);
					#endif
					#if defined END	&& END_SKY == 2	  								//End Ground Reflections
						#ifdef REFLECTION_ROUGH
							//normal += roughNoise * 36.0;
						#endif
						vec3 skyReflectionPos = reflect(nViewPos, normal);
						skyReflectionPos *= 1000000.0;
						vec4 cloud = DrawEndCloud(skyReflectionPos, dither, endCol);
						skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
						//skyReflection *= 4.0;
					#endif
				}

				reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
				
				#ifdef AO
					if (skymapMod < 0.505) reflection.rgb *= pow(min(ao + max(0.25 - lViewPos * 0.01, 0.0), 1.0), lViewPos * 0.75);
					//reflection.rgb *= pow(ao, 13.0 * float(skymapMod < 0.505));
				#endif
				
				color.rgb = color.rgb * (1.0 - fresnel3 * (1.0 - metalness)) +
							reflection.rgb * fresnel3;

				/*
				float timeThing1 = abs(fract(frameTimeCounter * 1.35) - 0.5) * 2.0;
				float timeThing2 = abs(fract(frameTimeCounter * 1.15) - 0.5) * 2.0;
				float timeThing3 = abs(fract(frameTimeCounter * 1.55) - 0.5) * 2.0;
				color.rgb = 3.0 * pow(vec3(timeThing1, timeThing2, timeThing3), vec3(3.2));
				*/

				//color.rgb = vec3(materialFormat);
			}
		#endif
		
		#ifdef GLOWING_ENTITY_FIX
			if (skymapMod > 0.9975) {
				vec2 glowOutlineOffsets[8] = vec2[8](
									vec2(-1.0, 0.0),
									vec2( 0.0, 1.0),
									vec2( 1.0, 0.0),
									vec2( 0.0,-1.0),
									vec2(-1.0,-1.0),
									vec2(-1.0, 1.0),
									vec2( 1.0,-1.0),
									vec2( 1.0, 1.0)
									);

				float outline = 0.0;

				for(int i = 0; i < 64; i++){
					vec2 offset = vec2(0.0);
					offset = glowOutlineOffsets[i-8*int(i/8)] * 0.00025 * (int(i/8)+1);
					outline += clamp(1.0 - texture2D(colortex3, texCoord + offset).b, 0.0, 1.0);
				}
				
				color.rgb += outline * vec3(0.05);
			}
		#endif
		
		#ifdef AO
			if (skymapMod < 0.505)
			color.rgb *= ambientOcclusion;
		#endif
		
		#ifdef PROMO_OUTLINE
			PromoOutline(color.rgb, depthtex0);
		#endif

		vec3 extra = vec3(0.0);
		#if defined NETHER && defined NETHER_SMOKE
			extra = netherNebula;
		#endif
		#ifdef END
			extra = viewPos.xyz;
		#endif

		color.rgb = startFog(color.rgb, nViewPos, lViewPos, worldPos, extra, NdotU);
	
	} else { /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ 
		float NdotU = 0.0;

		#ifdef SKY_BLUR
			vec2 skyBlurOffset[4] = vec2[4](vec2( 0.0,  1.0),
											vec2( 0.0, -1.0),
											vec2( 1.0,  0.0),
											vec2(-1.0,  0.0));
			vec2 wh = vec2(viewWidth, viewHeight);
			vec3 skyBlurColor = vec3(0.0);
			for(int i = 0; i < 4; i++) {
				vec2 texCoordM = texCoord + skyBlurOffset[i] / wh;
				float depth = texture2D(depthtex0, texCoordM).r;
				if (depth == 1.0) skyBlurColor += texture2DLod(colortex0, texCoordM, 0.0).rgb;
				else skyBlurColor += color.rgb;
			}
			color.rgb = skyBlurColor / 4.0;
		#endif

		#ifdef NETHER
			color.rgb = pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4;
			#ifdef NETHER_SMOKE
				color.rgb += netherNebula;
			#endif
		#endif
		
		#ifdef TWENTY
			color.rgb *= 0.1;
		#endif
		
		#ifdef SEVEN
			NdotU = max(dot(normalize(viewPos.xyz), upVec), 0.0);

			vec3 twilightPurple = vec3(0.005, 0.006, 0.018);
			vec3 twilightGreen = vec3(0.015, 0.03, 0.02);

			#ifdef TWENTY
				twilightPurple = twilightGreen * 0.1;
			#endif

			color.rgb = 2 * (twilightPurple * 2 * clamp(pow(NdotU, 0.7), 0.0, 1.0) + twilightGreen * (1-clamp(pow(NdotU, 0.7), 0.0, 1.0)));

			#ifndef TWENTY
				vec3 stars = DrawStars(color.rgb, viewPos.xyz, NdotU);
				color.rgb += stars.rgb;
			#endif
		#endif
		
		#ifdef TWO
			NdotU = 1.0 - max(dot(normalize(viewPos.xyz), upVec), 0.0);
			NdotU *= NdotU;
			#ifndef ABYSS
				vec3 midnightPurple = vec3(0.0003, 0.0004, 0.002) * 1.25;
				vec3 midnightFogColor = fogColor * fogColor * 0.3;
			#else
				vec3 midnightPurple = skyColor * skyColor * 0.00075;
				vec3 midnightFogColor = fogColor * fogColor * 0.09;
			#endif
			color.rgb = mix(midnightPurple, midnightFogColor, NdotU);
		#endif
		
		#ifdef END
			#ifdef COMPATIBILITY_MODE
				color.rgb *= pow(color.rgb, vec3(2.2));
				color.rgb += endCol * 0.055;
			#endif
		#endif

		if (isEyeInWater == 1) {
			NdotU = max(dot(normalize(viewPos.xyz), upVec), 0.0);
			color.rgb = mix(color.rgb, 0.8 * pow(rawWaterColor.rgb * (1.0 - blindFactor), vec3(2.0)), 1 - NdotU*NdotU);
		}
		if (isEyeInWater == 2) color.rgb = vec3(0.5);
		if (blindFactor > 0.0) color.rgb *= 1.0 - blindFactor;
	}
    
	#ifdef BLACK_OUTLINE
		float wFogMult = 1.0 + eBS;
		BlackOutline(color.rgb, depthtex0, wFogMult);
	#endif

	#ifdef END
		//z *= 0.0;
	#endif

	//Interactive Water Waves
	#ifdef INTERACTIVE_WATER
		vec2 waterCoord = texCoord + INTERACTIVE_WATER_RES / vec2(viewWidth, viewHeight) * (floor(cameraPosition.xz) - floor(previousCameraPosition.xz));
		vec4 wdata = texture2D(colortex8, waterCoord);
		color.a = 1.0;
		wdata.a = 1.0;
		vec4[4] wdata0 = vec4[4](
			texture2D(colortex8, waterCoord - vec2(0.0, 1.0 / viewHeight)),
			texture2D(colortex8, waterCoord + vec2(0.0, 1.0 / viewHeight)),
			texture2D(colortex8, waterCoord - vec2(1.0 / viewWidth, 0.0)),
			texture2D(colortex8, waterCoord + vec2(1.0 / viewWidth, 0.0)));
		wdata0[0].a /= max(1.0, abs(wdata0[0].b - wdata.b));
		wdata0[1].a /= max(1.0, abs(wdata0[1].b - wdata.b));
		wdata0[2].a /= max(1.0, abs(wdata0[2].b - wdata.b));
		wdata0[3].a /= max(1.0, abs(wdata0[3].b - wdata.b));
		float walpha0 = wdata0[0].a + wdata0[1].a + wdata0[2].a + wdata0[3].a + 0.01;
		vec4 environment = vec4(0);
		vec3 envcoords = floor(vec3((texCoord.x - 0.5) * viewWidth * 1.0 / INTERACTIVE_WATER_RES, 32 * VXHEIGHT * VXHEIGHT, (texCoord.y - 0.5) * viewHeight * 1.0 / INTERACTIVE_WATER_RES) + vec3(0.5)) + vec3(0.5);
		float inRange = max(abs(envcoords.x), abs(envcoords.z)) / (0.0625 * shadowMapResolution / VXHEIGHT - 1.0);
		while (length(environment) < 0.1 && envcoords.y > -32 * VXHEIGHT * VXHEIGHT && inRange < 1.0){
			vec2 vxPos = getVoxelPos(envcoords)[0].xz;
			vec4 vxData = texture2D(shadowcolor0, vxPos / shadowMapResolution + vec2(0.5));
			envcoords.y -= 1;
			environment.rgb = vec3(abs(vxData.a * 255 - 29) < 0.5);
			wdata.b = envcoords.y;
		}
		vec2 playerdist = (texCoord - vec2(0.5)) * vec2(viewWidth, viewHeight) / INTERACTIVE_WATER_RES + vec2(0.5) - fract(cameraPosition.xz);
		if(abs(envcoords.y + 1) < 1.2 && length(playerdist) < 0.4){
			wdata.r += 2 * (cameraPosition.y - previousCameraPosition.y - 2 * dot(playerdist, cameraPosition.xz - previousCameraPosition.xz));
		}
		float wavgr = wdata0[0].r * wdata0[0].a + wdata0[1].r * wdata0[1].a + wdata0[2].r * wdata0[2].a + wdata0[3].r * wdata0[3].a;
		wdata.g -= 0.1 * exp(0.05 * INTERACTIVE_WATER_RES) * (walpha0 * wdata.r - wavgr);
		wdata.r += wdata.g;
		wdata.rg *= wdata.a * wdata.a;
		if(wdata.a < 0.1 && length(environment) > 0.1) wdata.r = wavgr /(walpha0 + 0.0001);
		wdata.rg *= vec2(1.0) / (vec2(1.0) + 0.01 * wdata.rg * wdata.rg * wdata.rg *wdata.rg);
		wdata.a = float(length(environment.rgb) > 0.1);
		vec2 playerWaterCoord0 = (texCoord - vec2(0.5)) * vec2(viewWidth, viewHeight) / (1.0 * INTERACTIVE_WATER_RES) + 4 * vec2(frameTimeCounter, 0.573 * frameTimeCounter);
		vec2 playerWaterCoord1 = (texCoord - vec2(0.5)) * vec2(viewWidth, viewHeight) / (1.0 * INTERACTIVE_WATER_RES) + 4 * vec2(1.6 * frameTimeCounter, -0.273 * frameTimeCounter);
		vec2 playerWaterCoord2 = (texCoord - vec2(0.5)) * vec2(viewWidth, viewHeight) / (1.0 * INTERACTIVE_WATER_RES) + 4 * vec2(0.8 * frameTimeCounter, -0.473 * frameTimeCounter);
		float stimulantWave = 30 * WATER_BUMP * (sin(dot(playerWaterCoord0 + floor(cameraPosition.xz), vec2(0.573, 0.2257))) + 0.5 * sin(dot(playerWaterCoord1 + floor(cameraPosition.xz), vec2(0.216, -0.173))) + 0.5 * fract(dot(playerWaterCoord2 + floor(cameraPosition.xz), vec2(0.7312, 0.143))) - 0.25);
		wdata.r = mix(wdata.r, stimulantWave, pow(min(inRange, 1.0), 70));
	#endif

	/*DRAWBUFFERS:05*/
    gl_FragData[0] = color;
	gl_FragData[1] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, 1.0);
	#ifdef INTERACTIVE_WATER
	/*DRAWBUFFERS:058*/
	gl_FragData[2] = vec4(wdata);
	#endif

}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Common Variables//
#ifdef OVERWORLD
	float timeAngleM = timeAngle;
#else
	#if !defined SEVEN && !defined SEVEN_2
		float timeAngleM = 0.25;
	#else
		float timeAngleM = 0.5;
	#endif
#endif

//Program//
void main(){
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif
