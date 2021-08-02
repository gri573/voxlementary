/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness, moonBrightness;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex1;

uniform sampler2D colortex3;

#if LIGHT_SHAFT_MODE > 1
uniform float viewWidth, viewHeight;

uniform mat4 gbufferProjectionInverse;
#endif

#if NIGHT_VISION > 1
uniform float nightVision;
#endif

//Optifine Constants//
const bool colortex1MipmapEnabled = true;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);
float rainStrengthSp2 = rainStrengthS * rainStrengthS;
float lightShaftTime = pow(abs(sunVisibility - 0.5) * 2.0, 10.0);

//Includes//
#include "/lib/color/dimensionColor.glsl"

//Program//
void main() {
    vec4 color = texture2D(colortex0,texCoord.xy);
	vec3 vlBlock = texture2D(colortex3, texCoord.xy).rgb;

	#if LIGHT_SHAFT_MODE == 1 || defined END
		vec3 vl = texture2DLod(colortex1, texCoord.xy, 1.5).rgb;
		vl *= vl;
	#else
		#if LIGHT_SHAFT_MODE == 2
			float lod = 1.0;
			float offset = 1.0;
			vec3 vl = vec3(0.0);
			vl += texture2DLod(colortex1, texCoord.xy + vec2( 0.0,  offset / viewHeight), lod).rgb;
			vl += texture2DLod(colortex1, texCoord.xy + vec2( 0.0, -offset / viewHeight), lod).rgb;
			vl += texture2DLod(colortex1, texCoord.xy + vec2( offset / viewWidth,   0.0), lod).rgb;
			vl += texture2DLod(colortex1, texCoord.xy + vec2(-offset / viewWidth,   0.0), lod).rgb;
			vl *= 0.25;
		#else
			float lod = 1.5;
			float offset = 2.0;
			vec3 vl = texture2DLod(colortex1, texCoord.xy, lod).rgb;
			vl += texture2DLod(colortex1, texCoord.xy + vec2( 0.0,  offset / viewHeight), lod).rgb;
			vl += texture2DLod(colortex1, texCoord.xy + vec2( 0.0, -offset / viewHeight), lod).rgb;
			vl += texture2DLod(colortex1, texCoord.xy + vec2( offset / viewWidth,   0.0), lod).rgb;
			vl += texture2DLod(colortex1, texCoord.xy + vec2(-offset / viewWidth,   0.0), lod).rgb;
			vl *= 0.2;
		#endif

		vl *= vl;
	#endif

	#ifdef OVERWORLD
		#if LIGHT_SHAFT_MODE == 1
			if (isEyeInWater == 0) {
				vl *= lightCol * lightCol * 0.5;

				vl *= mix(1.0, LIGHT_SHAFT_NOON_MULTIPLIER * 0.5, timeBrightness*timeBrightness);
				vl *= mix(LIGHT_SHAFT_NIGHT_MULTIPLIER * 10.0, 2.0, sunVisibility);
				vl *= mix(1.0, LIGHT_SHAFT_RAIN_MULTIPLIER * 0.25, rainStrengthSp2);
			}
			else vl *= length(lightCol) * 0.2 * LIGHT_SHAFT_UNDERWATER_MULTIPLIER  * (1.0 - rainStrengthS * 0.85);
		#else
			if (isEyeInWater == 0) {
				#if LIGHT_SHAFT_MODE == 2
					vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
					vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
					viewPos /= viewPos.w;
					vec3 nViewPos = normalize(viewPos.xyz);

					float NdotU = dot(nViewPos, upVec);
					NdotU = max(NdotU, 0.0);
					NdotU = 1.0 - NdotU;
					if (NdotU > 0.5) NdotU = smoothstep(0.0, 1.0, NdotU);
					NdotU *= NdotU;
					NdotU *= NdotU;
					NdotU = mix(NdotU, 1.0, rainStrengthSp2);
					vl *= NdotU * NdotU;
				#else
					vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
					vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
					viewPos /= viewPos.w;
					vec3 nViewPos = normalize(viewPos.xyz);

					float NdotU = dot(nViewPos, upVec);
					NdotU = max(NdotU, 0.0);
					NdotU = 1.0 - NdotU;
					if (NdotU > 0.5) NdotU = smoothstep(0.0, 1.0, NdotU);
					NdotU = mix(NdotU, 1.0, rainStrengthSp2);
					NdotU = pow(NdotU, 8.0 * smoothstep(0.0, 1.0, pow2(1.0 - max(timeBrightness, moonBrightness))));
					vl *= max(NdotU, 0.0); // Using max() here fixes a bug that affects auto exposure
				#endif

				vec3 dayLightCol = lightCol*lightCol*lightCol;
				vec3 nightLightCol = lightCol * lightCol * 20.0;
				vl *= mix(nightLightCol, dayLightCol, sunVisibility);

				#if LIGHT_SHAFT_MODE == 2
					vl *= mix(1.0, LIGHT_SHAFT_NOON_MULTIPLIER * 0.4, timeBrightness * (1.0 - rainStrengthS * 0.8));
					vl *= mix(LIGHT_SHAFT_NIGHT_MULTIPLIER * 0.25, 2.0, sunVisibility);
					vl *= mix(1.0, LIGHT_SHAFT_RAIN_MULTIPLIER * 0.25, rainStrengthSp2);
				#else
					float timeBrightnessSqrt = sqrt1(timeBrightness);
					
					vl *= mix(1.0, LIGHT_SHAFT_NOON_MULTIPLIER * 0.75, timeBrightnessSqrt * (1.0 - rainStrengthS * 0.8));
					vl *= mix(LIGHT_SHAFT_NIGHT_MULTIPLIER * (0.35 - moonBrightness * 0.15), 2.0, sunVisibility);
					vl *= mix(1.0, LIGHT_SHAFT_RAIN_MULTIPLIER * 0.25, rainStrengthSp2);
				#endif
			} else vl *= length(lightCol) * 0.175 * LIGHT_SHAFT_UNDERWATER_MULTIPLIER  * (1.0 - rainStrengthS * 0.85);
		#endif
	#endif

	#ifdef END
   		vl *= endCol * 0.1 * LIGHT_SHAFT_THE_END_MULTIPLIER;
	#endif

	#if LIGHT_SHAFT_MODE == 1 || defined END
    	vl *= LIGHT_SHAFT_STRENGTH * (1.0 - rainStrengthS * eBS * 0.875) * shadowFade * (1 + isEyeInWater*1.5) * (1.0 - blindFactor);
	#else
		vl *= LIGHT_SHAFT_STRENGTH * shadowFade * (1.0 - blindFactor);

		float vlFactor = (1.0 - min((timeBrightness)*2.0, 0.75));
		vlFactor = mix(vlFactor, 0.05, rainStrengthS);
		if (isEyeInWater == 1) vlFactor = 3.0;
		vl *= vlFactor * 1.15;
	#endif

	#if NIGHT_VISION > 1
		if (nightVision > 0.0) {
			vl = vec3(0.0, length(vl), 0.0);
		}
	#endif

	color.rgb += vl * lightShaftTime;
	color.rgb += vlBlock * vlBlock;
	
	/*DRAWBUFFERS:0*/
	gl_FragData[0] = color;
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
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif