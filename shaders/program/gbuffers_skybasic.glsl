/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float vanillaStars;

varying vec3 upVec, sunVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;
uniform int worldDay;
uniform int moonPhase;

uniform float blindFactor;
uniform float frameCounter;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float rainStrengthS;
uniform float shadowFade;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D noisetex;

#if defined WEATHER_PERBIOME || defined AURORA
uniform float isDry, isRainy, isSnowy;
#endif

//Optifine Constants//

//Common Variables//
#if WORLD_TIME_ANIMATION >= 1
float modifiedWorldDay = mod(worldDay, 100.0) + 5.0;
float frametime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

vec3 RoundSunMoon(vec3 nViewPos, vec3 sunColor, vec3 moonColor, float NdotU){
	float cosS = dot(nViewPos, sunVec);
	float isMoon = float(cosS < 0.0);
	float sun = pow(abs(cosS), 2600.0 * isMoon + 1800.0 * (1 - isMoon));

	if (isMoon > 0.0) {
		if (moonPhase >= 1) {
			float moonPhaseOffset = float(!(moonPhase == 4));
			if (moonPhase > 4) moonPhaseOffset *= -1.0;

			float ang = fract(timeAngle - (0.25 + 0.0037 * moonPhaseOffset));
			ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
			vec2 sunRotationData2 = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
			vec3 rawSunVec2 = (gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData2) * 2000.0, 1.0)).xyz;
		
			float moonPhaseCosS = dot(nViewPos, normalize(rawSunVec2.xyz));
			moonPhaseCosS = pow(abs(moonPhaseCosS), 750.0);
			sun = mix(sun, 0.0, min(moonPhaseCosS * 2.0, 1.0));
		}
		/*
		float moonPhaseOffsetX = -160.0;
		float moonPhaseCosS = dot(nViewPos, normalize(vec3(rawSunVec.x + moonPhaseOffsetX, rawSunVec.y, rawSunVec.z)));
		moonPhaseCosS = pow(abs(moonPhaseCosS), 100000.0);
		sun += moonPhaseCosS;
		*/
	}

	float horizonFactor = clamp((NdotU+0.0025)*20, 0.0, 1.0);
	sun *= horizonFactor;

	vec3 sunMoonCol = mix(moonColor * (1.0 - sunVisibility), sunColor * sunVisibility, float(cosS > 0.0));

	vec3 finalSunMoon = sun * sunMoonCol * 32.0;
	finalSunMoon = pow(finalSunMoon, vec3(2.0 - min(finalSunMoon.r + finalSunMoon.g + finalSunMoon.b, 1.0)));

	#ifdef COMPATIBILITY_MODE
		finalSunMoon = min(finalSunMoon, vec3(1.0));
	#else
		if (isMoon > 0.0) finalSunMoon = min(finalSunMoon, vec3(1.0));
	#endif

	//if (length(finalSunMoon) < 0.001) finalSunMoon *= 0.0;

	return finalSunMoon;
}

//Includes//
#include "/lib/color/lightColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/endColor.glsl"
#include "/lib/util/dither.glsl"

#ifdef AURORA
#include "/lib/color/auroraColor.glsl"
#endif

#if defined CLOUDS || defined AURORA
#include "/lib/atmospherics/clouds.glsl"
#endif
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/sunGlare.glsl"

//Program//
void main() {
	vec3 vanillaStarImage = vec3(0.0);
	
	vec3 albedo = vec3(0.0);

	vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec3 nViewPos = normalize(viewPos.xyz);

	float NdotU = dot(nViewPos, upVec);
	
	#ifdef OVERWORLD
		float cloudMask = 0.0;
		#if defined CLOUDS || defined AURORA
			float dither = Bayer64(gl_FragCoord.xy);
		#endif
		#ifdef CLOUDS
			vec4 cloud = DrawCloud(viewPos.xyz * 1000000.0, dither, lightCol, ambientCol, NdotU, 6);
			float cloudOpacity = CLOUD_OPACITY;
			if (cloudOpacity > 0.35) {
				cloudMask = min((cloud.a / (CLOUD_OPACITY * 2.0)), 0.25) + (cloud.a / (CLOUD_OPACITY * 2.0)) * 0.5; 
			}
		#endif
		
		if (vanillaStars < 0.5) albedo = GetSkyColor(lightCol, NdotU, nViewPos, false);
		
		/*#ifdef STARS
			vec3 stars = DrawStars(albedo.rgb, viewPos.xyz, max(NdotU, 0.0));
			#ifdef CLOUDS
				albedo.rgb += stars.rgb * (1 - cloudMask*1.99);
			#else
				albedo.rgb += stars.rgb;
			#endif
		#endif*/
		
		float starDeletionTime = min(timeBrightness * 7.15, 1.0) * 0.15 + sunVisibility * 0.85;
		float starNdotU = 1.0 - max(NdotU, 0.0);
		starNdotU = 1.0 - starNdotU * starNdotU;
		float vanillaStarFactor = (1.0 - cloudMask*1.99) * starNdotU * (1.0 - starDeletionTime) * pow2(pow2(1.0 - max(rainStrength, rainStrengthS)));
		vanillaStarFactor = vanillaStars * clamp(vanillaStarFactor, 0.0, 1.0);
		vanillaStarImage = lightNight * lightNight;
		vanillaStarImage *= vanillaStarFactor * 32.0;
		
		vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos.xyz, 1.0));
		vec3 planeCoord = 0.25 * wpos / (wpos.y + length(wpos.xz));
		vec2 wind = -8.0 * vec2(frametime, 0.0);
		vec2 coord = planeCoord.xz * 0.5 + wind * 0.00125;
		//float lStar = min(length(vanillaStarImage), 1.0);
		//vanillaStarImage *= 1.0 - min(1.0, 1.0 * lStar * lStar * texture2D(noisetex, coord.xy).x);
		
		#ifdef ROUND_SUN_MOON
			vec3 sunColor = vec3(0.9, 0.35, 0.05);
			vec3 moonColor = vec3(12.0, 13.8, 15.9) / 35.7;
			
			vec3 roundSunMoon = RoundSunMoon(nViewPos, sunColor, moonColor, NdotU);
			#ifdef CLOUDS
				float rainStrengthS2 = 1.0 - rainStrengthS;
				rainStrengthS2 = 1.0 - rainStrengthS2 * rainStrengthS2;
				roundSunMoon *= max(1.0 - cloudMask * (rainStrengthS2 * 30.0 + 1.0), 0.0) * (1.0 - rainStrengthS*rainStrengthS);
			#else
				roundSunMoon *= 1.0 - max(rainStrength, rainStrengthS);
			#endif
			albedo.rgb += roundSunMoon;
		#endif

		if (vanillaStars < 0.5) albedo = SunGlare(albedo, nViewPos, lightCol);
		
		#ifdef AURORA
			albedo.rgb += (1.0 - cloudMask*1.5) * DrawAurora(viewPos.xyz * 1000000.0, dither, 20, NdotU);
		#endif

		#ifdef CLOUDS
			if (vanillaStars < 0.5) albedo.rgb = mix(albedo.rgb, cloud.rgb, cloud.a);
		#endif

		//albedo.rgb *= (1.0 + nightVision);
		
		if (eyeAltitude < 2.0) albedo.rgb *= min(clamp((eyeAltitude-1.0), 0.0, 1.0) + pow(max(NdotU, 0.0), 32.0), 1.0);
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(0.0, 0.0, 0.0);
		vanillaStarImage = vec3(0.0);
	#endif

    /* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(albedo + vanillaStarImage, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float vanillaStars;

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
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	vec3 rawSunVec = (gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz;
	sunVec = normalize(rawSunVec);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();

	vec3 color = gl_Color.rgb;
	
	//Vanilla Star Dedection by Builderb0y
	vanillaStars = float(color.r == color.g && color.g == color.b && color.r > 0.0);
}

#endif