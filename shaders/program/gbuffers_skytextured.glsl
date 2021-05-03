/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec2 texCoord;

varying vec4 color;
#endif

#if (defined END && END_SKY > 0) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec3 upVec, sunVec;
#endif

//Uniforms//
uniform float screenBrightness;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform sampler2D texture;

#if (defined END && END_SKY > 0) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
uniform int worldTime;
uniform int worldDay;

uniform float nightVision;
uniform float rainStrengthS;
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;
#endif

#ifdef END
uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;

uniform sampler2D noisetex;
#endif

#ifdef WEATHER_PERBIOME
uniform float isDry, isRainy, isSnowy;
#endif

//Common Variables//
#if defined END && END_SKY > 0
#if WORLD_TIME_ANIMATION >= 1
float modifiedWorldDay = mod(worldDay, 100.0) + 5.0;
float frametime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif
#endif

#if (defined END && END_SKY > 0) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);
#endif

//Common Functions//
#if defined END && END_SKY > 0
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}
#endif

//Includes//
#if defined OVERWORLD && !defined ROUND_SUN_MOON
#include "/lib/color/lightColor.glsl"
#endif
#ifdef END
#include "/lib/color/endColor.glsl"
#endif
#if defined END && END_SKY > 0
#include "/lib/color/lightColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/clouds.glsl"
#endif

//Program//
void main(){
	#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		vec4 albedo = texture2D(texture, texCoord.xy);
	#else
		vec4 albedo = vec4(0.0);
	#endif
	
	#if (defined END && END_SKY > 0) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
	#endif
	
	#if defined OVERWORLD && !defined ROUND_SUN_MOON
		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);
		albedo.a *= clamp((NdotU+0.02)*10, 0.0, 1.0);
		albedo *= color;
		albedo.rgb = pow(albedo.rgb, vec3(2.2 + sunVisibility * 2.2)) * (1.0 + sunVisibility * 4.0) * SKYBOX_BRIGHTNESS * albedo.a;
		
		/*
		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);
		albedo.a *= clamp((NdotU+0.02)*10, 0.0, 1.0);
		albedo *= color;
		float lAlbedo = length(albedo.rgb);
		float cosS = dot(nViewPos, sunVec);
		if (cosS > 0.0) {
			albedo.a *= float(lAlbedo > 1.5);
			albedo.rgb = pow(lightCol.rgb, vec3(2.2)) * 3.0;
		} else {
			albedo.a *= float(albedo.r / albedo.b > 0.6);
			albedo.rgb = pow(albedo.rgb, vec3(2.75));
		}
		albedo.rgb = albedo.rgb * (1.0 + sunVisibility * 3.0) * SKYBOX_BRIGHTNESS * albedo.a;
		*/
    #endif

	#ifdef END
		if (1.0362 < length(color) && length(color) < 1.0363) { // The End
			albedo.rgb = albedo.rgb * SKYBOX_BRIGHTNESS * 0.1;
			#if END_SKY > 0
				float dither = Bayer64(gl_FragCoord.xy);
				vec4 cloud = DrawEndCloud(viewPos.xyz, dither, endCol);
				cloud = pow(cloud, vec4(1.0 / 2.2));
				albedo.rgb = mix(albedo.rgb, cloud.rgb, cloud.a);
				albedo.a = 1.0;
			#endif
			#ifndef COMPATIBILITY_MODE
				albedo.rgb *= pow(albedo.rgb, vec3(2.2));
				albedo.rgb += endCol * 0.055;
			#endif
		} else {												// BetterEnd
			#if END_SKY > 0
				if (albedo.a < 0.003929 && !(albedo.a == 0.0) && length(albedo.rgb) < 0.32) albedo.rgb *= 4.0, albedo.a = 1.0;
				albedo *= color;
				albedo.rgb *= sqrt(albedo.a) * 3.25 * SKYBOX_BRIGHTNESS;
				albedo.a = clamp(length(albedo.rgb) * 0.025, 0.0, 1.0);
			#else
				albedo.a = 0.0;
			#endif
		}
	#endif

	#ifdef TWO
		albedo = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(255.0, 255.0, 85.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec2 texCoord;

varying vec4 color;
#endif

#if (defined END && END_SKY > 0) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec3 upVec, sunVec;
#endif

//Uniforms//
#if (defined END && END_SKY > 0) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
	uniform float timeAngle;

	uniform mat4 gbufferModelView;

	#if AA == 2 || AA == 3
		uniform int frameCounter;

		uniform float viewWidth;
		uniform float viewHeight;
		#include "/lib/util/jitter.glsl"
	#endif
	#if AA == 4
		uniform int frameCounter;

		uniform float viewWidth;
		uniform float viewHeight;
		#include "/lib/util/jitter2.glsl"
	#endif
#endif

//Common Variables//
#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
	#ifdef OVERWORLD
		#ifdef OVERWORLD
	float timeAngleM = timeAngle;
#else
	#if !defined SEVEN && !defined SEVEN_2
		float timeAngleM = 0.25;
	#else
		float timeAngleM = 0.5;
	#endif
#endif
	#else
		float timeAngleM = 0.25;
	#endif
#endif

//Program//
void main(){
	#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		color = gl_Color;
		
		gl_Position = ftransform();
	#endif
	
	#if (defined END && END_SKY > 0) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
		float ang = fract(timeAngleM - 0.25);
		ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
		sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

		upVec = normalize(gbufferModelView[1].xyz);
		
		#if AA > 1
			gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
		#endif
	#else	
		#if !defined END
			vec4 color = vec4(0.0);
			gl_Position = color;
		#endif	
	#endif
}

#endif