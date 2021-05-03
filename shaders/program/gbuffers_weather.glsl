/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 upVec, sunVec;

varying vec4 color;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

uniform float nightVision;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;

uniform sampler2D texture;

#ifdef WEATHER_PERBIOME
uniform float isDry, isRainy, isSnowy;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

//Includes//
#include "/lib/color/lightColor.glsl"
#include "/lib/color/blocklightColor.glsl"

//Program//
void main(){
    vec4 albedo = vec4(0.0);
	
	#ifdef GREY
	albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
	#endif
	
	albedo.a = texture2D(texture, texCoord.xy).a;
	albedo.rgb = texture2D(texture, texCoord.xy).rgb;
	
	if (albedo.a > 0.0){
		#ifndef COMPATIBILITY_MODE
			if (albedo.r <= 0.75) { 
				albedo.a *= 0.15;
				albedo.rgb = sqrt(albedo.rgb);
				albedo.rgb *= (ambientCol + lmCoord.x * lmCoord.x * blocklightCol) * 0.75;
			} else {
				albedo.a *= 0.15;
				albedo.rgb = sqrt(albedo.rgb);
				albedo.rgb *= (ambientCol + lmCoord.x * lmCoord.x * blocklightCol) * 2.0;
			}
		#else
			albedo.a *= 0.15;
			albedo.rgb = sqrt(albedo.rgb);
			albedo.rgb *= (ambientCol + lmCoord.x * lmCoord.x * blocklightCol) * 0.75;
		#endif
	}
	
	#ifdef TWEAKEROO_OVERLAY_FIX
		if (albedo.a < 0.001 && color.b < 0.95 && color.b > 0.9 && color.r < 0.2 && color.r > 0.1 && color.g < 0.2 && color.g > 0.1) 
		albedo = color * vec4(1.0, 1.0, 10.0, 0.8);
	#endif
	
	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(85.0, 85.0, 85.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 sunVec, upVec;

varying vec4 color;

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
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp(lmCoord * 2.0 - 1.0, 0.0, 1.0);

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();

	color = gl_Color;
}

#endif