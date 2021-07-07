/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

#ifndef NO_PARTICLES

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

#ifdef DYNAMIC_SHADER_LIGHT
	uniform int heldItemId, heldItemId2;

	uniform int heldBlockLightValue;
	uniform int heldBlockLightValue2;
#endif

uniform float blindFactor;
uniform float far;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#if ((defined WATER_CAUSTICS || defined SNOW_MODE || defined CLOUD_SHADOW) && defined OVERWORLD) || defined RANDOM_BLOCKLIGHT || defined END
uniform sampler2D noisetex;
#endif

#ifdef COMPBR
uniform ivec2 atlasSize;
#endif

#if !defined COMPATIBILITY_MODE && MC_VERSION >= 11700
uniform ivec4 blendFunc;
#endif

#ifdef COLORED_LIGHT
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
#include "/lib/color/skyColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#if MC_VERSION >= 11500
#ifdef OVERWORLD
#include "/lib/atmospherics/sky.glsl"
#endif

#if defined END && defined ENDER_NEBULA
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/util/dither.glsl"
#endif

#include "/lib/atmospherics/fog.glsl"
#endif
#endif

//Program//
void main() {
	vec4 albedo = vec4(0.0);
	vec3 vlAlbedo = vec3(1.0);

	#ifndef SEVEN
		float textured = 1.0;
	#else
		float textured = 0.0;
	#endif

	#ifndef NO_PARTICLES
		vec4 albedoP = texture2D(texture, texCoord);
		albedo = albedoP * color;
		
		float skymapMod = 0.0;
		
		if (albedo.a > 0.0) {
			vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

			vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
			vec3 viewPos = ToNDC(screenPos);
			vec3 worldPos = ToWorld(viewPos);

			#if defined FOG1 && defined FOG1_CHECK
				float lWorldPos = length(worldPos.xz);
				float fog1 = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
				fog1 = 1.0 - exp(-0.1 * pow(fog1, 10.0));
				if (fog1 > 0.95) discard;
			#endif

			vec3 nViewPos = normalize(viewPos.xyz);
			float NdotU = dot(nViewPos, upVec);
			float lViewPos = length(viewPos);

			#ifdef SEVEN
				textured = float(lViewPos < 10.0); // Fixes the Twilight Forest skybox messing with TAA
			#endif

			float emissive = 0.0;
			#ifdef COMPBR
				if (atlasSize.x < 900.0) { // We don't want to detect particles from the block atlas
					float lAlbedo = length(albedo.rgb);
					vec3 gamePos = worldPos + cameraPosition;

					if (albedo.b > 1.15 * (albedo.r + albedo.g) && albedo.g > albedo.r * 1.25 && albedo.g < 0.425 && albedo.b > 0.75) // Water Particle
						albedo.rgb = waterColorSqrt.rgb * 1.1 * lAlbedo;

					else if (abs(albedo.r - albedo.g) == 0.0 && albedo.r - 0.5 * albedo.b < 0.06) { // Underwater Particle
						if (isEyeInWater == 1) {
							albedo.rgb = waterColorSqrt.rgb * 1.1 * lAlbedo;
							if (fract(gamePos.r + gamePos.g + gamePos.b) > 0.2) discard;
						}
					}

					else if (color.a < 0.99 && lAlbedo < 1.0) // Campfire Smoke, World Border
						albedo.a *= 0.2;

					else if (max(abs(albedoP.r - albedoP.b), abs(albedoP.b - albedoP.g)) < 0.001) { // Grayscale Particles
						if (lAlbedo > 0.5 && color.g < 0.5 && color.b > color.r * 1.1 && color.r > 0.3) // Ender Particle, Crying Obsidian Drop
							emissive = max(pow(albedo.r, 5.0), 0.1);
						if (lAlbedo > 0.5 && color.g < 0.5 && color.r > (color.g + color.b) * 3.0) // Redstone Particle
							lightmap = vec2(0.0), emissive = max(pow(albedo.r, 5.0), 0.1);
					}
						
					//albedo.rgb = vec3(1.0, 0.0, 1.0);
				}
			#endif

			#if !defined COMPATIBILITY_MODE && MC_VERSION >= 11700
				if (blendFunc == ivec4(770, 1, 1, 0)) { // World Border
					albedo.a = albedoP.a * color.a * 0.2;
					lightmap = vec2(1.0);
				}
			#endif

			albedo.rgb = pow(albedo.rgb, vec3(2.2));

			#ifdef WHITE_WORLD
				albedo.rgb = vec3(0.5);
			#endif

			float NdotL = 1.0;
			NdotL = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

			float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75, 0.5, 1.0);
				quarterNdotU*= quarterNdotU;
			
			vec3 shadow = vec3(0.0);
			vec3 lightAlbedo = vec3(0.0);
			GetLighting(albedo.rgb, shadow, lightAlbedo, viewPos, lViewPos, worldPos, lightmap, 1.0, NdotL, 1.0,
							1.0, emissive, 0.0, 0.0, 1.0);

			#ifndef COMPATIBILITY_MODE
				albedo.rgb *= 2.0;
			#endif

			#ifdef PARTICLE_VISIBILITY
				if (lViewPos < 2.0) albedo.a *= smoothstep(0.7, 2.0, lViewPos) + 0.0002;
			#endif

			#if MC_VERSION >= 11500
				albedo.rgb = startFog(albedo.rgb, nViewPos, lViewPos, worldPos, viewPos.xyz, NdotU);
			#endif

			#if MC_VERSION >= 11500
				vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt1(albedo.a)) * (1.0 - pow(albedo.a, 64.0));
			#endif
		} else discard;
	#endif

	#ifdef TWO
		albedo.a = 1.0;
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(255.0, 170.0, 0.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.2;
	#endif
	
    /* DRAWBUFFERS:017 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);
	gl_FragData[2] = vec4(textured, 1.0, 1.0, 1.0);

	#if defined ADV_MAT && defined REFLECTION_SPECULAR && MC_VERSION < 11500
	/* DRAWBUFFERS:01736 */
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[4] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

#ifndef NO_PARTICLES

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

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

//Common Functions//

//Includes//
#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

#endif

//Program//
void main() {
	#ifndef NO_PARTICLES
		texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		
		lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

		normal = normalize(gl_NormalMatrix * gl_Normal);
		
		color = gl_Color;

		const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
		float ang = fract(timeAngleM - 0.25);
		ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
		sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

		upVec = normalize(gbufferModelView[1].xyz);

		#ifdef WORLD_CURVATURE
			vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
			position.y -= WorldCurvature(position.xz);
			gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
		#else
			gl_Position = ftransform();
		#endif

		#ifdef FLICKERING_FIX
			gl_Position.z -= 0.000002;
		#endif

	#else
		gl_Position = vec4(0.0);
	#endif
}

#endif