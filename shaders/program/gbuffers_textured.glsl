/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#ifndef NO_PARTICLES

//Extensions//

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

#ifdef DYNAMIC_SHADER_LIGHT
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

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#ifdef ADVANCED_MATERIALS
uniform sampler2D specular;
uniform sampler2D normals;
#endif

uniform vec3 cameraPosition;

#if ((defined WATER_CAUSTICS || defined SNOW_MODE || defined CLOUD_SHADOW) && defined OVERWORLD) || defined COLORED_LIGHTING || defined END
uniform sampler2D noisetex;
#endif

#ifdef WEATHER_PERBIOME
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
#include "/lib/color/skyColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#if MC_VERSION >= 11500
#ifdef OVERWORLD
#include "/lib/atmospherics/sky.glsl"
#endif

#if defined END && END_SKY > 0
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/util/dither.glsl"
#endif

#include "/lib/atmospherics/fog.glsl"
#endif

#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

#endif

//Program//
void main() {
	vec4 albedo = vec4(0.0);
	vec3 vlAlbedo = vec3(1.0);

	#ifndef NO_PARTICLES
		albedo = texture2D(texture, texCoord) * color;
		
		#ifdef GREY
			albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
		#endif
		
		float skymapMod = 0.0;
		
		if (albedo.a > 0.0) {
			vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

			float particleReduction = 1.0;

			vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
			#if AA > 1
				vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
			#else
				vec3 viewPos = ToNDC(screenPos);
			#endif
			vec3 worldPos = ToWorld(viewPos);

			#if defined FOG1 && defined FOG1_CHECK
				float lWorldPos = length(worldPos.xz);
				float fog1 = lWorldPos / far * 1.5 * (1 + rainStrengthS*0.3) * (10/FOG1_DISTANCE);
				fog1 = 1.0 - exp(-0.1 * pow(fog1, 10 - rainStrengthS*5));
				if (fog1 > 0.95) discard;
			#endif

			vec3 nViewPos = normalize(viewPos.xyz);
			float NdotU = dot(nViewPos, upVec);
			float lViewPos = length(viewPos);

			float emissive = 0.0;
			float metalness = 0.0;
			#ifdef ADVANCED_MATERIALS
				vec3 normalMap = texture2D(normals, texCoord).xyz;

				if (normalMap == vec3(1.0)) {
					#ifdef MC_SPECULAR_MAP 
						metalness = texture2D(specular, texCoord).g;
					#endif
				}

				if (normalMap == vec3(0.0)) {
					#ifdef MC_SPECULAR_MAP 
						vec4 specularMap = texture2D(specular, texCoord);
					#else
						vec4 specularMap = vec4(0.0, 0.0, 0.0, 1.0);
					#endif

					float sweep          = float(specularMap.r > 0.01 && specularMap.r < 0.05);
					float endAndRedstone = float(specularMap.r > 0.05 && specularMap.r < 0.1 && albedo.r / albedo.g > 2.9);
					float underWater     = float(specularMap.r > 0.05 && specularMap.r < 0.1 && albedo.r < 0.45 && isEyeInWater == 1);
					float water          = float(specularMap.g > 0.01 && specularMap.g < 0.05);
					float waterDrip      = float(specularMap.b > 0.01 && specularMap.b < 0.05 && albedo.r < 0.35);
					float lavaDrip       = float(specularMap.b > 0.01 && specularMap.b < 0.05 && albedo.r > 0.35 && albedo.b < 0.5 && albedo.b / albedo.g > 0.2);
					float bigSmoke       = float(specularMap.g > 0.05 && specularMap.g < 0.1);
					float enchant        = float(specularMap.b > 0.05 && specularMap.b < 0.1);

					particleReduction = 0.0;
					if (sweep             > 0.5) lightmap.x = 0.0, albedo.rgb = vec3(0.75);
					if (endAndRedstone    > 0.5) lightmap = vec2(0.0), emissive = max(pow(albedo.r, 5.0), 0.1);
					if (underWater        > 0.5) discard;
					if (water + waterDrip > 0.5) albedo.rgb = sqrt(waterColorSqrt.rgb) * 0.55, lightmap.x *= 0.85;
					if (lavaDrip          > 0.5) emissive = 1.0 - albedo.g;
					if (bigSmoke          > 0.5) albedo.a *= 0.2;
					if (enchant           > 0.5) emissive = 0.125;
				}
			#endif

			albedo.rgb = pow(albedo.rgb, vec3(2.2));
			albedo.rgb *= (1.0 - metalness*0.75);

			#ifdef WHITE_WORLD
				albedo.rgb = vec3(0.5);
			#endif

			float NdotL = 1.0;
			NdotL = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

			float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75, 0.5, 1.0);
				quarterNdotU*= quarterNdotU;
			
			float shadow = 0.0;
			float fakeShadow = 0.0;
			GetLighting(albedo.rgb, shadow, fakeShadow, viewPos, lViewPos, worldPos, lightmap, 1.0, NdotL, 1.0,
							1.0, emissive, 0.0, 0.0, 0.0, 0.0, 1.0);

			#ifndef COMPATIBILITY_MODE
				albedo.rgb *= 2.0;
			#endif

			#if !defined COMPATIBILITY_MODE && defined PARTICLE_VISIBILITY
				if (particleReduction > 0.5) {
					if (lViewPos < 2) albedo.a *= smoothstep(0.7, 2.0, lViewPos) + 0.0002;
					//if (albedo.a < 0.00015) discard;
				}
			#endif

			#if MC_VERSION >= 11500
				albedo.rgb = startFog(albedo.rgb, nViewPos, lViewPos, worldPos, viewPos.xyz, NdotU);
			#endif

			#if MC_VERSION >= 11500
				vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt(albedo.a)) * (1.0 - pow(albedo.a, 64.0));
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
	
    /* DRAWBUFFERS:01 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR && MC_VERSION < 11500
	/* DRAWBUFFERS:0136 */
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

#ifndef NO_PARTICLES

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

//Uniforms//
uniform int worldTime;
uniform int renderStage;

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
#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

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
		if (renderStage == 22) lmCoord = vec2(1.0);

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
		
		#if AA > 1
			gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
		#endif
	#else
		gl_Position = vec4(0.0);
	#endif
}

#endif