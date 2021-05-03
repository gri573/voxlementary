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
uniform int worldTime;

uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight, aspectRatio;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 fogColor;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef WATER_REFRACT
	uniform sampler2D colortex4;
#endif

#if defined WATERMARK && WATERMARK_DURATION < 900
	uniform float starter;
#endif

#ifdef WATERMARK
	uniform sampler2D depthtex2;
#endif

#if defined LIGHT_SHAFTS && defined SHADOWS
	uniform sampler2DShadow shadowtex0;
	uniform sampler2DShadow shadowtex1;
	uniform sampler2D shadowcolor0;
#endif

#if ((defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING && defined END && END_SKY == 2) || defined WATER_REFRACT || defined LIGHT_SHAFTS
	uniform float shadowFade;
	uniform sampler2D noisetex;
#endif

#if (defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING
	uniform vec3 skyColor;
#endif

#if NIGHT_VISION > 1 || ((defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING)
	uniform float nightVision;
#endif

#ifdef WEATHER_PERBIOME
	uniform float isDry, isRainy, isSnowy;
#endif

//Attributes//

//Optifine Constants//
const bool colortex2Clear = false;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

#if (defined LIGHT_SHAFTS && defined SHADOWS && defined SMOKEY_WATER_LIGHTSHAFTS) || ((defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING && defined END && END_SKY == 2) || defined WATER_REFRACT
		#if WORLD_TIME_ANIMATION >= 2
			float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
		#else
			float frametime = frameTimeCounter * ANIMATION_SPEED;
		#endif
#endif

#if (defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING
	vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
#endif

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"

#if defined LIGHT_SHAFTS && defined SHADOWS
	#ifdef SMOKEY_WATER_LIGHTSHAFTS
		#include "/lib/lighting/caustics.glsl"
	#endif
	#include "/lib/atmospherics/volumetricLight.glsl"
#endif

#if (defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING
	#ifdef OVERWORLD
		#include "/lib/color/skyColor.glsl"
		#include "/lib/atmospherics/sky.glsl"
	#endif
	#if defined END && END_SKY == 2
		#include "/lib/atmospherics/clouds.glsl"
	#endif

	#include "/lib/atmospherics/fog.glsl"
#endif

#if defined PROMO_OUTLINE && defined OUTLINE_ON_EVERYTHING
	#include "/lib/outline/promoOutline.glsl"
#endif

#if defined BLACK_OUTLINE && defined OUTLINE_ON_EVERYTHING
	#include "/lib/color/blocklightColor.glsl"
	#include "/lib/outline/blackOutline.glsl"
#endif

//Program//
void main() {
    vec4 color = texture2D(colortex0, texCoord.xy);
    vec3 translucent = texture2D(colortex1,texCoord.xy).rgb;
	float z0 = texture2D(depthtex0, texCoord.xy).r;
	float z1 = texture2D(depthtex1, texCoord.xy).r;

	#if (defined LIGHT_SHAFTS && defined SHADOWS) || defined WATER_REFRACT
		vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, z0, 1.0) * 2.0 - 1.0);
		viewPos /= viewPos.w;
	#endif

	#ifdef WATER_REFRACT
		float water = texture2D(colortex4, texCoord.xy).g;

		if (water > 0.5) {
			vec3 worldPos = ToWorld(viewPos.xyz);
			vec3 refractPos = worldPos.xyz + cameraPosition.xyz;
			refractPos *= 0.005;

			float refractSpeed = 0.0035 * WATER_SPEED;
			vec2 refractPos1 = refractPos.xz + refractSpeed * frametime;
			vec2 refractPos2 = refractPos.xy - refractSpeed * frametime;
			vec2 refractPos3 = refractPos.yz + refractSpeed * frametime;
			float refractNoise1 = texture2D(noisetex, refractPos1).r;
			float refractNoise2 = texture2D(noisetex, refractPos2 + vec2(1.7)).r;
			float refractNoise3 = texture2D(noisetex, refractPos3 + vec2(2.7)).r;

			vec2 refractNoise = refractNoise1 + refractNoise2 + refractNoise3 - vec2(1.5);

			float hand = 1.0 - float(z0 < 0.56);
			float d0 = GetLinearDepth(z0);
			//float d1 = GetLinearDepth(z1);
			float distScale0 = max((far - near) * d0 + near, 6.0);
			float fovScale = gbufferProjection[1][1] / 1.37;
			float refractScale = fovScale / distScale0;
			vec2 refractMult = vec2(0.04 * refractScale);
			
			vec2 refractCoord = texCoord.xy + refractMult * hand * refractNoise * REFRACT_STRENGTH;

			float waterCheck = texture2DLod(colortex4, refractCoord, 0.0).g;
			float depthCheck0 = texture2D(depthtex0, refractCoord).r;
			float depthCheck1 = texture2D(depthtex1, refractCoord).r;
			float depthDif = GetLinearDepth(depthCheck1) - GetLinearDepth(depthCheck0);
			refractMult *= clamp(depthDif * 150.0, 0.0, 1.0);
			refractCoord = texCoord.xy + refractMult * hand * refractNoise * REFRACT_STRENGTH;
			if (depthCheck0 >= 0.56) {
				if (waterCheck > 0.95) {
					color.rgb = texture2D(colortex0, refractCoord).rgb;
					if (isEyeInWater == 1) {
						translucent = texture2D(colortex1, refractCoord).rgb;
						z0 = texture2D(depthtex0, refractCoord).r;
						z1 = texture2D(depthtex1, refractCoord).r;
					}
				}
			}
		}
	#endif
    
	#if defined LIGHT_SHAFTS && defined SHADOWS
		float dither = Bayer64(gl_FragCoord.xy);
	#endif

	#if defined BLACK_OUTLINE && defined OUTLINE_ON_EVERYTHING
		float outlineMask = BlackOutlineMask(depthtex0, depthtex1);
		float wFogMult = 1.0 + eBS;
		if (outlineMask > 0.5 || isEyeInWater > 0.5)
			BlackOutline(color.rgb, depthtex0, wFogMult);
	#endif
	
	#if defined PROMO_OUTLINE && defined OUTLINE_ON_EVERYTHING
		if (z1 - z0 > 0.0) PromoOutline(color.rgb, depthtex0);
	#endif

	if (isEyeInWater == 1 && z0 == 1.0) {
		color.rgb *= pow(rawWaterColor.rgb, vec3(0.5)) * 3;
		color.rgb = 0.8 * pow(rawWaterColor.rgb * (1.0 - blindFactor), vec3(2.0));
	}

	if (isEyeInWater == 2) color.rgb *= vec3(1.0, 0.25, 0.01);
	
	#if defined LIGHT_SHAFTS && defined SHADOWS
		vec3 vl = getVolumetricRays(z0, z1, translucent, dither, viewPos);
	#else
		vec3 vl = vec3(0.0);
    #endif

	#if NIGHT_VISION > 1
		if (nightVision > 0.0) {
			float nightVisionGreen = length(color.rgb);
			nightVisionGreen = smoothstep(0.0, 1.0, nightVisionGreen) * 3.0 + 0.25 * sqrt(nightVisionGreen);
			float whiteFactor = 0.01;
			vec3 nightVisionFinal = vec3(nightVisionGreen * whiteFactor, nightVisionGreen, nightVisionGreen * whiteFactor);
			color.rgb = mix(color.rgb, nightVisionFinal, nightVision);
		}
	#endif

	#ifdef WATERMARK
		#if WATERMARK_DURATION < 900
			if (starter < 0.99) {
		#endif
				vec2 textCoord = vec2(texCoord.x, 1.0 - texCoord.y);
				vec4 compText = texture2D(depthtex2, textCoord);
				#if WATERMARK_DURATION < 900
					float starterFactor = 1.0 - 2.0 * abs(starter - 0.5);
					starterFactor = max(starterFactor - 0.333333, 0.0) * 3.0;
					starterFactor = smoothstep(0.0, 1.0, starterFactor);
				#else
					float starterFactor = 1.0;
				#endif
				color.rgb = mix(color.rgb, compText.rgb, compText.a * starterFactor);
		#if WATERMARK_DURATION < 900
			}
		#endif
	#endif
	
    /*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);
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
