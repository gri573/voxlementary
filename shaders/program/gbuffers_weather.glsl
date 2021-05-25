/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 upVec, sunVec;

varying vec4 color;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

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

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

//Includes//
#include "/lib/color/lightColor.glsl"
#include "/lib/color/blocklightColor.glsl"

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord.xy);

	#ifdef OVERLAY_FIX
	if (color.r + color.g + color.b > 2.99999) {
	#endif
		if (albedo.a > 0.0) {
			#ifndef COMPATIBILITY_MODE
				if (albedo.r <= 0.75) { // Rain
					albedo.a *= 0.15;
					albedo.rgb = sqrt(albedo.rgb);
					albedo.rgb *= (ambientCol + lmCoord.x * lmCoord.x * blocklightCol) * 0.75;
				} else { 				// Snow
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
		
		#ifdef GBUFFER_CODING
			albedo.rgb = vec3(85.0, 85.0, 85.0) / 255.0;
			albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
		#endif
	#ifdef OVERLAY_FIX
	} else {
		albedo.rgb = pow(color.rgb, vec3(2.2)) * 2.0;
		albedo.rgb *= 0.25 + lmCoord.x + lmCoord.y * (1.0 + sunVisibility);
		if (texCoord.x == 0.0) albedo.a = pow2(color.a * color.a);
	}
	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

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
void main() {
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