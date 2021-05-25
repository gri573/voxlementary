/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying float mat;
varying float dist;

varying vec2 texCoord, lmCoord;

varying vec3 normal, binormal, tangent;
varying vec3 sunVec, upVec;
varying vec3 viewVector;

varying vec4 color;

#if defined ADV_MAT && defined NORMAL_MAPPING && !defined COMPBR
varying vec4 vTexCoord, vTexCoordAM;
#endif

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int worldDay;
uniform int moonPhase;

#ifdef DYNAMIC_SHADER_LIGHT
	uniform int heldItemId, heldItemId2;

	uniform int heldBlockLightValue;
	uniform int heldBlockLightValue2;
#endif

uniform float frameTimeCounter;
uniform float blindFactor, nightVision;
uniform float far, near;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D gaux2;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#if defined ADV_MAT && defined NORMAL_MAPPING && !defined COMPBR
uniform sampler2D normals;
#endif

#ifdef AURORA
uniform float isDry, isRainy, isSnowy;
#endif

#ifdef COLORED_LIGHT
uniform sampler2D colortex9;
#endif

//Optifine Constants//

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

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

#if defined ADV_MAT && defined NORMAL_MAPPING
vec2 dcdx = dFdx(texCoord.xy);
vec2 dcdy = dFdy(texCoord.xy);
#endif

#ifdef OVERWORLD
	vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
#else
	vec3 lightVec = sunVec;
#endif

#if WATER_TYPE == 0
float waterBump = WATER_BUMP * 1.2;
#else
float waterBump = WATER_BUMP * 0.20;
#endif

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float InterleavedGradientNoise() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
}
 
float GetWaterHeightMap(vec3 worldPos, vec3 nViewPos) {
	float verticalOffset = worldPos.y * 0.005;

	vec2 wind = vec2(frametime) * 0.0015;
	wind *= WATER_SPEED;
	wind -= verticalOffset;

	float noiseA = texture2D(noisetex, (worldPos.xz) / (1.0 * WATER_SIZE) - wind).g;
	float noiseB = texture2D(noisetex, (worldPos.xz) / (0.6 * WATER_SIZE) + wind).g;
	float noiseC = texture2D(noisetex, (worldPos.xz) / (0.35 * WATER_SIZE) + wind).g;
	float noiseD = texture2D(noisetex, (worldPos.xz) / (0.3 * WATER_SIZE) - wind).g;
	vec4 noiseS = vec4(noiseA, noiseB, noiseC, noiseD);
	noiseS *= - noiseS;
	float noise = noiseS.r * WATER_NOISE_1 
				- noiseS.r * noiseS.g * WATER_NOISE_2 
				+ noiseS.g * WATER_NOISE_3 
				+ (noiseS.b - noiseS.a) * WATER_NOISE_4;

	noise *= waterBump * (lmCoord.y*0.9 + 0.1) * 0.35;

    return noise;
}

vec3 GetParallaxWaves(vec3 worldPos, vec3 nViewPos, vec3 viewVector) {
	vec3 parallaxPos = worldPos;
	
	for(int i = 0; i < 4; i++) {
		float height = (GetWaterHeightMap(parallaxPos, nViewPos) - 0.5);
		parallaxPos.xz += 0.05 * height * viewVector.xy / sqrt(dist);
	}
	return parallaxPos;
}

vec3 GetWaterNormal(vec3 worldPos, vec3 nViewPos, vec3 viewVector) {
	vec3 waterPos = worldPos + cameraPosition;
	#ifdef WATER_PARALLAX
		waterPos = GetParallaxWaves(waterPos, nViewPos, viewVector);
	#endif

	float normalOffset = WATER_SHARPNESS;

	float h1 = GetWaterHeightMap(waterPos + vec3( normalOffset, 0.0, 0.0), nViewPos);
	float h2 = GetWaterHeightMap(waterPos + vec3(-normalOffset, 0.0, 0.0), nViewPos);
	float h3 = GetWaterHeightMap(waterPos + vec3(0.0, 0.0,  normalOffset), nViewPos);
	float h4 = GetWaterHeightMap(waterPos + vec3(0.0, 0.0, -normalOffset), nViewPos);

	float xDelta = (h1 - h2) / normalOffset;
	float yDelta = (h3 - h4) / normalOffset;
	float aDelta = xDelta * xDelta + yDelta * yDelta;

	vec3 normalMap = vec3(xDelta, yDelta, 1.0 - aDelta);

	#if defined REFLECTION_ROUGH && WATER_TYPE == 2
		vec3 roughMap = texture2D(noisetex, texCoord * 2097152).rgb;
		normalMap = normalMap + 0.5 * (roughMap - vec3(0.5, 0.5, 1.0));
	#endif

	vec3 normalClamp = vec3(1.75);
	normalMap = clamp(normalMap, normal - normalClamp, normal + normalClamp);
	normalMap = normalMap * 0.03 + vec3(0.0, 0.0, 0.75);

	return normalMap;
}

float GetWaterOpacity(float alpha, float difT, float fresnel) {
	//Fake water fog
	float waterFogDist = 1.0 - min(difT / WATER_FOG * 2.0, 1.0);
	waterFogDist *= waterFogDist;
	alpha = mix(0.97, alpha, min(waterFogDist, 1.0 - fresnel));

	//Hide shadows not being good enough
	alpha = max(min(sqrt(dist) * 0.075, 0.9), alpha);

	return alpha;
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/reflections/raytracewater.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/reflections/simpleReflections.glsl"

#ifdef OVERWORLD
	#ifdef AURORA
	#include "/lib/color/auroraColor.glsl"
	#endif

	#if defined CLOUDS || defined AURORA
	#include "/lib/atmospherics/clouds.glsl"
	#endif
	#include "/lib/atmospherics/sky.glsl"
#endif

#if defined END && defined ENDER_NEBULA
	#include "/lib/color/lightColor.glsl"
	#include "/lib/atmospherics/clouds.glsl"
	#include "/lib/atmospherics/sky.glsl"
#endif

#if defined NETHER && defined NETHER_SMOKE
	#include "/lib/atmospherics/clouds.glsl"
#endif

#include "/lib/atmospherics/fog.glsl"

#if AA == 2 || AA == 3
	#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
	#include "/lib/util/jitter2.glsl"
#endif

//Program//
void main() {
	vec4 albedoP = texture2D(texture, texCoord);
	if (albedoP.a == 0.0) discard; //needed for "Create" mod support
    vec4 albedo = albedoP * vec4(color.rgb, 1.0);
	
	float emissive = 0.0;
	vec3 newNormal = normal;
	vec3 vlAlbedo = vec3(1.0);
	vec3 worldPos = vec3(0.0);
	#ifdef WATER_REFRACT
		float waterMask = 0.0;
	#endif
	
	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = albedo.a * 100000.0;
	#endif

	if (albedocheck > 0.00001) {
		vec2 lightmap = lmCoord;
		
		float water            = float(mat > 0.98 && mat < 1.02);
		float translucent      = float(mat > 1.98 && mat < 2.52);
		float tintedGlass      = float(mat > 2.23 && mat < 2.27);
		float ice      		   = float(mat > 2.48 && mat < 2.52);
		float netherportal 	   = float(mat > 2.98 && mat < 3.02);
		float moddedfluid  	   = float(mat > 3.98 && mat < 5.02);
		float moddedfluidX     = float(mat > 4.98 && mat < 5.02);
		
		#ifndef REFLECTION_TRANSLUCENT
			translucent = 0.0;
		#endif

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ToNDC(screenPos);
		#endif
		worldPos = ToWorld(viewPos);

		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);

		vec3 normalMap = vec3(0.0, 0.0, 1.0);
		
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

		if (water + moddedfluidX > 0.5) {
			#ifdef WATER_REFRACT
				waterMask = 1.0;
			#endif

			float halfNdotUish = abs(dot(newNormal, upVec));
			waterBump *= 0.25 + 0.75 * halfNdotUish;

			normalMap = GetWaterNormal(worldPos, nViewPos, viewVector);
			newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		}

		#ifdef ADV_MAT
			#if defined NORMAL_MAPPING && !defined COMPBR
				if (water < 0.5) {
					vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
					normalMap = texture2DGradARB(normals, newCoord, dcdx, dcdy).xyz;
					normalMap += vec3(0.5, 0.5, 0.0);
					normalMap = pow(normalMap, vec3(NORMAL_MULTIPLIER));
					normalMap -= vec3(0.5, 0.5, 0.0);
					#if RP_SUPPORT == 4
						normalMap = normalMap * 2.0 - 1.0;
					#else
						normalMap = normalMap * 2.0 - 1.0;
						float normalCheck = normalMap.x + normalMap.y;
						if (normalCheck > -1.999) {
							if (length(normalMap.xy) > 1.0) normalMap.xy = normalize(normalMap.xy);
							normalMap.z = sqrt(1.0 - dot(normalMap.xy, normalMap.xy));
							normalMap = normalize(clamp(normalMap, vec3(-1.0), vec3(1.0)));
						} else {
							normalMap = vec3(0.0, 0.0, 1.0);
						}
					#endif

					if (normalMap.x > -0.999 && normalMap.y > -0.999)
						newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
				}
			#endif
			#if defined COMPBR && defined EMISSIVE_NETHER_PORTAL
					if (netherportal > 0.5) emissive = 0.25, albedo.r *= 1.5, albedo.a *= max(pow(albedo.r, 8.0), 0.025), lightmap = vec2(0.0);
			#endif
		#endif
		
		if (moddedfluidX > 0.5) albedo = texture2DLod(texture, texCoord, 100.0) * vec4(color.rgb, 1.0);

    	if (water < 0.5) albedo.rgb = pow(albedo.rgb, vec3(2.2));

		float fresnel = clamp(1.0 + dot(newNormal, nViewPos), 0.0, 1.0);
		float fresnel2 = fresnel * fresnel;
		float fresnel4 = fresnel2 * fresnel2;

		#if SKY_REF_FIX_1 == 1
			float skyRefFactor = lightmap.y * lightmap.y * 1.0;
		#elif SKY_REF_FIX_1 == 2
			float skyRefFactor = max(lightmap.y - 0.80, 0.0) * 5.0;
		#else
			float skyRefFactor = max(lightmap.y - 0.99, 0.0) * 100.0;
		#endif

		float difT = 0.0;
		if (water > 0.5) {	
			#if WATER_TYPE == 0
				vec3 customWaterColor = vec3(waterColor.rgb * waterColor.rgb * 3.0 * waterColor.a);

				#if MC_VERSION >= 11300
					vec3 vanillaWaterColor = pow(color.rgb, vec3(2.2)) * waterColor.a;
					vec3 combinedWaterColor = customWaterColor * (1 - WATER_V) + vanillaWaterColor * WATER_V;
					albedo.a = waterAlpha;
					if (isEyeInWater == 1) albedo.a = 1.0 - pow2(pow2(1.0 - albedo.a * min(fresnel2, 1.0)));
				#else
					vec3 combinedWaterColor = customWaterColor;
					albedo.a = 0.5;
				#endif

				albedo.rgb = combinedWaterColor;
			#endif
			
			#if WATER_TYPE == 1
				albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.7;
				albedo.a *= 1.0 - pow2(1.0 - WATER_OPACITY);
			#endif
			
			#if WATER_TYPE == 2
				albedo.a *= length(albedo.rgb) * WATER_OPACITY * 1.5;
				float albedoPRTX = pow2(albedoP.r * albedoP.r);
				albedo.rgb = waterColor.rgb * albedoPRTX + 0.5 * waterColor.rgb * albedoPRTX;
				albedo.rgb = mix(albedo.rgb, albedo.rgb * color.rgb, 0.5);
				if (WATER_OPACITY > 0.82) albedo.rgb = min(albedo.rgb * (1.0 + length(albedo.rgb) * pow(WATER_OPACITY, 32.0) * 50.0), vec3(2.0));
				if (isEyeInWater == 1) albedo.a = 0.5;
			#endif

			if (isEyeInWater == 0) {
				vec2 texCoordT = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
				float depthT = texture2D(depthtex1, texCoordT).r;
				vec3 screenPosT = vec3(texCoordT, depthT);
				#if AA > 1
					vec3 viewPosT = ToNDC(vec3(TAAJitter(screenPosT.xy, -0.5), screenPosT.z));
				#else
					vec3 viewPosT = ToNDC(screenPosT);
				#endif
				difT = (length(viewPosT) - dist);
				albedo.a = GetWaterOpacity(albedo.a, difT, fresnel);
			}
		}

		#ifdef WHITE_WORLD
			albedo.rgb = vec3(0.5);
		#endif

		if (water < 0.5 || isEyeInWater == 0) vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt1(albedo.a)) * (1.0 - pow(albedo.a, 64.0));

		float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float quarterNdotU = clamp(0.25 * dot(newNormal, upVec) + 0.75, 0.5, 1.0);
			  quarterNdotU*= quarterNdotU;

		float parallaxShadow = 1.0;
		float materialAO = 1.0;

		float subsurface = 0.0;
		#if SHADOW_SUBSURFACE == 2
			if (translucent > 0.5 && ice < 0.5) {
				subsurface = 1.0 - albedo.a;
			}
		#endif
		
		float shadow = 0.0;
		vec3 lightAlbedo = vec3(0.0);
		GetLighting(albedo.rgb, shadow, lightAlbedo, viewPos, dist, worldPos, lightmap, color.a, NdotL, quarterNdotU,
				    parallaxShadow, emissive, subsurface, 0.0, materialAO);
		
		float dither = Bayer64(gl_FragCoord.xy);

		#ifdef OVERWORLD
			//offset because consistency
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
		#endif
		#if defined SEVEN || defined SEVEN_2
			vec3 specularColor = vec3(0.005, 0.006, 0.018);
		#endif
	
		float fresnelRT = fresnel;

		if (water > 0.5 || moddedfluid > 0.5 || (translucent > 0.5 && albedo.a < 0.95)) {
			vec4 reflection = vec4(0.0);
			vec3 skyReflection = vec3(0.0);

			fresnel = fresnel4 * 0.95 + 0.05;
			fresnel *= max(1.0 - isEyeInWater * 0.5 * water, 0.5);
			fresnel *= 1.0 - translucent * (1.0 - albedo.a);

			#ifdef REFLECTION
				vec3 refNormal = mix(newNormal, normal, pow2(pow2(fresnel4)));
				reflection = SimpleReflection(viewPos, refNormal, dither, fresnelRT);
			#endif
			
			#ifdef WATER_TRANSLUCENT_SKY_REF
				if (reflection.a < 1.0) {
					vec3 skyReflectionPos = reflect(nViewPos, newNormal);
					float refNdotU = dot(skyReflectionPos, upVec);

					#ifdef OVERWORLD
						vec3 gotTheSkyColor = vec3(0.0);
						if (isEyeInWater == 0) gotTheSkyColor = GetSkyColor(lightCol, refNdotU, skyReflectionPos, true);
						if (isEyeInWater == 1) gotTheSkyColor = 0.6 * pow(underwaterColor.rgb * (1.0 - blindFactor), vec3(2.0));
						skyReflection = gotTheSkyColor;
					#endif
					skyReflectionPos *= 1000000.0;
					#ifdef OVERWORLD
						float specular = 0.0;
						if (water > 0.5) {
							#if WATER_TYPE == 2
								float smoothnessRTX = albedoP.r * 0.8;
								smoothnessRTX *= smoothnessRTX;
								specular = (0.15 + 0.85 * sunVisibility) * GGX(newNormal, nViewPos, lightVec, smoothnessRTX, 0.02, 0.025 * sunVisibility + 0.05);
								if (waterBump >= 0.275) specular += stylisedGGX(newNormal, normal, nViewPos, lightVec, 0.0);
							#else
								if (waterBump >= 0.275) specular = stylisedGGX(newNormal, normal, nViewPos, lightVec, 0.0);
							#endif
						}
						#ifdef COMPBR
							if (ice > 0.5) {
								float smoothnessIce = length(albedoP.rgb);
								smoothnessIce = pow2(pow2(smoothnessIce)) * 0.12;
								specular = GGX(newNormal, nViewPos, lightVec, smoothnessIce, 0.02, 0.025 * sunVisibility + 0.05);
							}
						#endif
						specular *= sqrt1inv(rainStrengthS);
						#ifdef SHADOWS
							specular *= shadowFade;
						#endif

						skyReflection *= skyRefFactor;
						#if defined CLOUDS || defined AURORA
							float cosT = dot(normalize(skyReflectionPos), upVec);
							#ifdef AURORA
								skyReflection += skyRefFactor * DrawAurora(skyReflectionPos, dither, 4, cosT);
							#endif
							float cloudFactor = 1.0;
							#ifdef CLOUDS
								if (isEyeInWater == 0) {
									vec4 cloud = DrawCloud(skyReflectionPos, dither, lightCol, ambientCol, cosT, 3);
									skyReflection = mix(skyReflection, cloud.rgb*skyRefFactor, cloud.a);
								}
							#endif
						#endif
						skyReflection += (specular / fresnel) * specularColor * shadow * lightmap.y * lightmap.y * lightmap.y;
					#endif

					#ifdef NETHER
						skyReflection = netherCol * 0.005;
					#endif

					#if defined END || defined SEVEN || defined SEVEN_2
						#if defined END
							skyReflection = endCol * 0.125;
							#if defined ENDER_NEBULA && !defined COMPATIBILITY_MODE
								vec4 enderNebula = DrawEnderNebula(skyReflectionPos * 100.0, dither, endCol, true);
								skyReflection = enderNebula.rgb * enderNebula.a * shadow * 0.5;
							#endif
						#endif
						#if (defined SEVEN || defined SEVEN_2) && !defined TWENTY
							vec3 twilightPurple = vec3(0.005, 0.006, 0.018);
							vec3 twilightGreen = vec3(0.015, 0.03, 0.02);
							skyReflection = 2 * (twilightPurple * 2 * clamp(pow(refNdotU, 0.7), 0.0, 1.0) + twilightGreen * (1-clamp(pow(refNdotU, 0.7), 0.0, 1.0)));
							skyReflection *= lmCoord.y * float(isEyeInWater == 0);
						#endif
						
						float specular = GGX(newNormal, nViewPos, lightVec, 0.4, 0.02, 0.025 * sunVisibility + 0.05);
					#endif

					#ifdef TWENTY
						vec3 twilightGreen = vec3(0.015, 0.03, 0.02);
						vec3 twilightPurple = twilightGreen * 0.1;
						skyReflection = 2 * (twilightPurple * 2 * clamp(pow(refNdotU, 0.7), 0.0, 1.0) + twilightGreen * (1-clamp(pow(refNdotU, 0.7), 0.0, 1.0)));
						if (isEyeInWater > 0.5) skyReflection = pow(underwaterColor.rgb * (1.0 - blindFactor), vec3(2.0)) * fresnel;
						skyReflection *= pow2(lightmap.y * lightmap.y);
					#endif
				}
			#endif

			reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
			
			albedo.rgb = mix(albedo.rgb, reflection.rgb, fresnel);
		}

		if (tintedGlass > 0.5) {
			albedo.a = sqrt2(albedo.a);
		}

		vec3 extra = viewPos.xyz;
		#if defined NETHER && defined NETHER_SMOKE
			extra = DrawNetherNebula(viewPos.xyz, dither, pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4);
		#endif

		albedo.rgb = startFog(albedo.rgb, nViewPos, dist, worldPos, extra, NdotU);

		#ifdef SHOW_LIGHT_LEVELS
			if (lmCoord.x < 0.5 && quarterNdotU > 0.99 && (mat < 0.95 || mat > 1.05) && translucent < 0.5) {
				float showLightLevelFactor = fract(frameTimeCounter);
				if (showLightLevelFactor > 0.5) showLightLevelFactor = 1 - showLightLevelFactor;
				albedo.rgb += vec3(0.5, 0.0, 0.0) * showLightLevelFactor;
			}
		#endif
	} else albedo.a = 0.0;

	//albedo.rgb = newNormal + 0.1;

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(85.0, 255.0, 255.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif

    /* DRAWBUFFERS:01 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);

	#ifdef WATER_REFRACT
	/* DRAWBUFFERS:014 */
	gl_FragData[2] = vec4(0.0, waterMask, 0.0, 1.0);
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
attribute vec4 at_tangent;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Common Functions//
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

	#if defined FOG1 && defined FOG1_CHECK
		float lWorldPos = length(position.xz) * 1;
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10.0));
		if (fog > 0.9) {
			gl_Position = vec4(0.0, 0.0, 1000.0, 0.0);
			return;
		}
	#endif

	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord.y = (lmCoord.y - 0.03125) * 1.06667;
	lmCoord.x = smoothstep(0.0, 1.0, pow((lmCoord.x - 0.03125) * 0.55, 0.35));
	lmCoord = clamp(lmCoord, vec2(0.0), vec2(1.0));

	normal   = normalize(gl_NormalMatrix * gl_Normal);
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	#if defined ADV_MAT && defined NORMAL_MAPPING && !defined COMPBR
		vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoord - midCoord;

		vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
		vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
		
		vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;
	
	mat = 0.0;
	
	if (mc_Entity.x == 79) mat = 2.0;   // Translucent
	if (mc_Entity.x == 7978) mat = 2.25;   // Tinted Glass
	if (mc_Entity.x == 7979) mat = 2.5; // Ice
	if (mc_Entity.x == 8) lmCoord.x *= 0.75;
	#if defined COMPBR && defined EMISSIVE_NETHER_PORTAL
		if (mc_Entity.x == 80) mat = 3.0;
	#endif

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	if (mc_Entity.x == 8) {   // Water
		#ifdef WATER_DISPLACEMENT
			position.y += WavingWater(position.xyz);
		#endif
		mat = 1.0;
	}
	if (mc_Entity.x == 888) { // Modded Fluid With Vanilla Texture
		mat = 4.0;
	}
	if (mc_Entity.x == 889) { // Modded Fluid With Water Waves And No Texture
		#ifdef WATER_DISPLACEMENT
			position.y += WavingWater(position.xyz);
		#endif
		mat = 5.0;
	}

    #ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	if (mat == 0.0) gl_Position.z -= 0.00001;
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif