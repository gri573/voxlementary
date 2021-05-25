/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
#if !defined CLOUDS && defined OVERWORLD
	varying vec2 texCoord;

	varying vec3 normal;
	varying vec3 sunVec, upVec;

	varying vec4 color;
#endif

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
#if !defined CLOUDS && defined OVERWORLD
	uniform int isEyeInWater;
	uniform int worldTime;

	uniform float rainStrengthS;
	uniform float screenBrightness; 
	uniform float timeAngle, timeBrightness, moonBrightness;
	uniform float viewWidth, viewHeight;
	uniform float far;

	uniform ivec2 eyeBrightnessSmooth;

	uniform vec3 skyColor;
	uniform vec3 cameraPosition;

	uniform mat4 gbufferProjectionInverse;
	uniform mat4 gbufferModelViewInverse;
	uniform mat4 shadowProjection;
	uniform mat4 shadowModelView;

	uniform sampler2D texture;

	#if AA > 1
		uniform int frameCounter;
	#endif
#endif

//Common Variables//
#if !defined CLOUDS && defined OVERWORLD
	float eBS = eyeBrightnessSmooth.y / 240.0;
	float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
	float vsBrightness = clamp(screenBrightness, 0.0, 1.0);
#endif

//Includes//
#if !defined CLOUDS && defined OVERWORLD
	#include "/lib/util/spaceConversion.glsl"
	#include "/lib/color/lightColor.glsl"
	#include "/lib/color/skyColor.glsl"

	#if AA == 2 || AA == 3
		#include "/lib/util/jitter.glsl"
	#endif
	#if AA == 4
		#include "/lib/util/jitter2.glsl"
	#endif
#endif

//Program//
void main(){
    #if !defined CLOUDS && defined OVERWORLD
		vec4 albedo = vec4(1.0, 1.0, 1.0, texture2D(texture, texCoord.xy).a);
		vec3 texture = texture2D(texture, texCoord.xy).rgb;
		albedo.rgb = pow(albedo.rgb * texture, vec3(2.2));
		
		float timeBrightnessS = 1.0 - timeBrightness;
		timeBrightnessS = 1.0 - timeBrightnessS * timeBrightnessS;
		if (rainStrengthS < 1.0) albedo.rgb *= lightCol * sky_ColorSqrt * (0.5 + 0.15 * timeBrightnessS);
		float sunVisibility2 = sunVisibility * sunVisibility;
		if (rainStrengthS > 0.0) {
			vec3 rainColor = weatherCol*weatherCol * (0.002 + 0.03 * timeBrightnessS + 0.02 * sunVisibility2);
			albedo.rgb = mix(albedo.rgb, rainColor * texture, rainStrengthS);
		}
		if (albedo.a > 0.1) {
			albedo.a = CLOUD_OPACITY;
			albedo.a *= albedo.a;
		}

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ToNDC(screenPos);
		#endif

		vec3 nViewPos = normalize(viewPos.xyz);

		float NdotU = dot(nViewPos, upVec);
		float cosS = dot(nViewPos, sunVec);

		float scattering = 0.5 * sunVisibility2 * pow(cosS * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 6.0);
		//scattering *= scattering;
		albedo.rgb *= 1.0 + scattering * (1.0 - rainStrengthS * 0.8);

		float meFactorP = min((1.0 - min(moonBrightness, 0.6) / 0.6) * 0.115, 0.075);
		vec3 meColor = vec3(0.0);
		if (cosS > 0.0) {
			float meNdotU = 1.0 - abs(NdotU);
			float meFactor = meFactorP * meNdotU * cosS * meNdotU * 12.0 * (1.0 - rainStrengthS);
			meColor = mix(lightMorning, lightEvening, mefade);
			meColor *= meColor * meColor;
			meColor *= meFactor * meFactor;
		}
		albedo.rgb += meColor * 0.25;
		
		vec3 worldPos = ToWorld(viewPos);
		float lWorldPos = length(worldPos.xz);
		float cloudDistance = 290.0;
		cloudDistance = clamp((cloudDistance - lWorldPos) / cloudDistance, 0.0, 1.0);
		albedo.a *= min(cloudDistance * 3.0, 1.0);

		float height = worldPos.y + cameraPosition.y;
		if (height < 134.0) {
			float cloudHeightFactor = clamp(height - 127.85, 0.0, 5.0) / 5.0;
			//cloudHeightFactor = 1.0 - cloudHeightFactor;
			//cloudHeightFactor *= cloudHeightFactor;

			vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
				
			float shadowTime = abs(sunVisibility - 0.5) * 2.0;
			shadowTime *= shadowTime;
			lightVec *= shadowTime * shadowTime;
			float NdotL = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0);
			albedo.rgb *= 1.0 + NdotL * 0.5;

			cloudHeightFactor = pow(cloudHeightFactor, 2.0 - NdotL);

			cloudHeightFactor *= 1.0 + 3.0 * sqrt1(moonBrightness) * (1.0 - rainStrengthS);

			float quarterNdotU = dot(normal, upVec);
			//quarterNdotU = mix(-1.0, quarterNdotU, cloudHeightFactor);
			if (quarterNdotU > 0.0) albedo.rgb *= 1.0 - 0.25 * quarterNdotU;
			else albedo.rgb *= 1.0 + 0.15 * quarterNdotU;

			albedo.rgb *= 0.5 + (0.25 + 0.75 * (1.0 - rainStrengthS) * sunVisibility2) * cloudHeightFactor;
		} else {
			float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75, 0.5, 1.0);
			albedo.rgb *= quarterNdotU;
		}

		vec3 vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt1(albedo.a)) * (1.0 - pow(albedo.a, 64.0));
	#else
		discard;
		vec4 albedo = vec4(1.0);
		vec3 vlAlbedo = vec3(1.0);
	#endif
	
	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(255.0, 255.0, 255.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 2.0;
	#endif

    /* DRAWBUFFERS:01 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
#if !defined CLOUDS && defined OVERWORLD
	#if AA == 2 || AA == 3
		uniform int frameCounter;

		uniform float viewWidth;
		uniform float viewHeight;
	#endif
	#if AA == 4
		uniform int frameCounter;

		uniform float viewWidth;
		uniform float viewHeight;
	#endif

	uniform float timeAngle;

	uniform mat4 gbufferModelView;
#endif

//Common Variables//
#if !defined CLOUDS && defined OVERWORLD
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

//Includes//
#if !defined CLOUDS && defined OVERWORLD
	#if AA == 2 || AA == 3
		#include "/lib/util/jitter.glsl"
	#endif
	#if AA == 4
		#include "/lib/util/jitter2.glsl"
	#endif
#endif

//Program//
void main(){
	#if !defined CLOUDS && defined OVERWORLD
		texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

		color = gl_Color;

		normal = normalize(gl_NormalMatrix * gl_Normal);
		
		const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
		float ang = fract(timeAngleM - 0.25);
		ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
		sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

		upVec = normalize(gbufferModelView[1].xyz);
		gl_Position = ftransform();

		#if AA > 1
			gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
		#endif
	#else
		gl_Position = vec4(0.0);
		return;
	#endif
	
}

#endif