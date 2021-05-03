/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#if defined ENTITY_NORMAL_FIX && MC_VERSION >= 11500
#undef PARALLAX
#undef SELF_SHADOW
#endif

//Extensions//

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

#if !defined ENTITY_NORMAL_FIX || MC_VERSION < 11500
varying vec3 binormal, tangent;
#endif

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int entityId;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int moonPhase;

#ifdef DYNAMIC_SHADER_LIGHT
	uniform int heldBlockLightValue;
	uniform int heldBlockLightValue2;
#endif

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 fogColor;

uniform vec4 entityColor;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#if defined FOG1 && defined FOG1_CHECK
uniform float far;
#endif

uniform vec3 cameraPosition;

#if ((defined WATER_CAUSTICS || defined SNOW_MODE || defined CLOUD_SHADOW) && defined OVERWORLD) || defined COLORED_LIGHTING
uniform sampler2D noisetex;
#endif

#ifdef ADVANCED_MATERIALS
uniform sampler2D specular;
uniform sampler2D normals;
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

#if defined ADVANCED_MATERIALS && (defined NORMAL_MAPPING || defined PARALLAX)
vec2 dcdx = dFdx(texCoord.xy);
vec2 dcdy = dFdy(texCoord.xy);
#else
vec2 dcdx = texCoord.xy;
vec2 dcdy = texCoord.xy;
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
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"

#ifdef WATER_CAUSTICS
#ifdef OVERWORLD
#include "/lib/color/waterColor.glsl"
#endif
#endif

#include "/lib/lighting/forwardLighting.glsl"

#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/util/encode.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/materialGbuffers.glsl"

#if defined PARALLAX || defined SELF_SHADOW
#include "/lib/surface/parallax.glsl"
#endif
#endif

//Program//
void main(){
    vec4 albedo = texture2D(texture, texCoord) * color;

	float materialFormatFlag = 1.0;
	
	vec3 newNormal = normal;
	
	float skymapMod = 0.0;
	float smoothness = 0.0;
	float metalData = 0.0;

	float itemFrameOrPainting = float(entityId == 18);

	#ifdef ADVANCED_MATERIALS
		vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
		
		#if defined PARALLAX || defined SELF_SHADOW
			float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
			float skipParallax = itemFrameOrPainting;
		#endif
		
		#ifdef PARALLAX
			if (skipParallax < 0.5){
				float materialFormatParallax = 0.0;
				GetParallaxCoord(parallaxFade, newCoord, materialFormatParallax);
				if (materialFormatParallax < 0.5) albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * color;
			}
		#endif

		vec3 rawAlbedo = vec3(0.0);
	#endif

	#ifdef ENTITY_EFFECT
		if (entityColor.a > 0.001) {
			albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
		}
	#endif
	
	#ifdef GREY
		albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
	#endif
	
	float lightningBolt = 0.0;
	#ifdef LIGHTNING_BOLTS_FIX
		lightningBolt = float(entityId == 10101);
		if (lightningBolt > 0.5) albedo = vec4(1.0, 1.25, 1.5, 1.0);
	#endif

	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = 1.0; //needed for "Joy of Painting" mod support
	#endif

	if (albedocheck > 0.00001 && lightningBolt < 0.5){
		if (albedo.a > 0.99) albedo.a = 1.0;

		vec2 lightmap = vec2(0.0);
			  
		#ifdef ENTITY_EFFECT
			float emissive = float(entityColor.a > 0.05) * 0.025;
		#else
			float emissive = 0.0;
		#endif

		float endCrystal = float(entityId == 1870);
		if (endCrystal > 0.5) lightmap.x *= 0.85;

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA > 1
			vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
			vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);
		float lViewPos = length(viewPos.xyz);

		float lViewPosToLight = lViewPos;
		if (itemFrameOrPainting > 0.5) {
			skymapMod = 0.51;
			lightmap = clamp(lmCoord, vec2(0.0), vec2(0.875, 1.0));
			lViewPosToLight += DYNAMIC_LIGHT_DISTANCE / 14.0;
		} else {
			lightmap = clamp(lmCoord, vec2(0.0), vec2(0.825, 1.0));
		}

		#if defined FOG1 && defined FOG1_CHECK
			float lWorldPos = length(worldPos.xz);
			float fog1 = lWorldPos / far * 1.5 * (1 + rainStrengthS*0.3) * (10/FOG1_DISTANCE);
			fog1 = 1.0 - exp(-0.1 * pow(fog1, 10 - rainStrengthS*5));
			if (fog1 > 0.95) discard;
		#endif

		float scattering = 0.0;
		float ao = 1.0;
		#ifdef ADVANCED_MATERIALS
			float metalness = 0.0, f0 = 0.0;
			vec3 normalMap = vec3(0.0);
			float materialFormat = 0.0;
			GetMaterials(materialFormat, smoothness, metalness, f0, metalData, emissive, ao, scattering, normalMap, newCoord, dcdx, dcdy);
			if (materialFormat > 0.5) {
				if (entityId == 1001) { //Ender Dragon
					emissive = 0.0;
				}
				if (entityId == 8008 && smoothness == 1.0) { //Charged Creeper
					float lAlbedo = length(albedo.rgb);
					albedo.rgb = lAlbedo * vec3(1.0, 1.25, 1.5);
					emissive = 0.05;
					lightmap = vec2(0.0);
				}
			} else {
				materialFormatFlag = 0.0;
			}

			#ifndef ENTITY_EMISSIVES
				emissive *= 0.0;
				if (materialFormat > 0.5) ao = 1.0;
			#endif
			
			#if (!defined ENTITY_NORMAL_FIX || MC_VERSION < 11500) && defined NORMAL_MAPPING
				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									tangent.y, binormal.y, normal.y,
									tangent.z, binormal.z, normal.z);

				if (normalMap.x > -0.999 && normalMap.y > -0.999)
					newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
			#endif
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef WHITE_WORLD
			albedo.rgb = vec3(0.5);
		#endif
		
		float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float quarterNdotU = clamp(0.25 * dot(newNormal, upVec) + 0.75, 0.5, 1.0);
			  quarterNdotU*= quarterNdotU;
			  quarterNdotU = 1.0;

		float parallaxShadow = 1.0;
		float materialAO = 1.0;
		#ifdef ADVANCED_MATERIALS
			rawAlbedo = albedo.rgb * 0.999 + 0.001;
			if (materialFormat > 0.5) {
				albedo.rgb *= ao;
				if (metalness > 0.80) {
					albedo.rgb *= (1.0 - metalness*0.65);
				}
			} else {
				materialAO = ao;
				albedo.rgb *= (1.0 - metalness*0.65);
			}

			float doParallax = 0.0;
			#ifdef SELF_SHADOW
				#ifdef OVERWORLD
					doParallax = float(lightmap.y > 0.0 && NdotL > 0.0);
				#endif
				#ifdef END
					doParallax = float(NdotL > 0.0);
				#endif
				if (materialFormat > 0.5) doParallax = 0.0;
				
				if (doParallax > 0.5){
					parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix);
					NdotL *= parallaxShadow;
				}
			#endif
		#endif
		
		float shadow = 0.0;
		float fakeShadow = 0.0;
		GetLighting(albedo.rgb, shadow, fakeShadow, viewPos, lViewPosToLight, worldPos, lightmap, 1.0, NdotL, quarterNdotU,
				    parallaxShadow, emissive, 0.0, 0.0, 0.0, scattering, materialAO);

		#ifdef ADVANCED_MATERIALS
			#if defined OVERWORLD || defined END
				#ifdef OVERWORLD
					vec3 lightME = mix(lightMorning, lightEvening, mefade);
					vec3 lightDayTint = lightDay * lightME * LIGHT_DI;
					vec3 lightDaySpec = mix(lightME, sqrt(lightDayTint), timeBrightness);
					vec3 specularColor = mix(sqrt(lightNight*0.3),
												lightDaySpec,
												sunVisibility);
					#ifdef WATER_CAUSTICS
						if (isEyeInWater == 1) specularColor *= rawWaterColor.rgb * 8.0;
					#endif
					specularColor *= specularColor;

					#ifdef SPECULAR_SKY_REF
						float skymapModM = lmCoord.y;
						#if SKY_REF_FIX_1 == 1
							skymapModM = skymapModM * skymapModM;
						#elif SKY_REF_FIX_1 == 2
							skymapModM = max(skymapModM - 0.80, 0.0) * 5.0;
						#else
							skymapModM = max(skymapModM - 0.99, 0.0) * 100.0;
						#endif
						if (!(metalness <= 0.004 && metalness > 0.0)) skymapMod = max(skymapMod, skymapModM * 0.1);
					#endif
				#endif
				#ifdef END
					vec3 specularColor = endCol;
				#endif
				
				vec3 specularHighlight = GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo,
												shadow, newNormal, viewPos, materialFormat);
				#ifdef LIGHT_LEAK_FIX
					if (isEyeInWater == 0) specularHighlight *= pow(lightmap.y, 2.5);
					else specularHighlight *= 0.15 + 0.85 * pow(lightmap.y, 2.5);
				#endif
				albedo.rgb += specularHighlight;
			#endif
		#endif
	} else {
	
	}

	#ifdef GBUFFERS_ENTITIES_GLOWING
		skymapMod = 1.0;
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(255.0, 85.0, 85.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif

    /* DRAWBUFFERS:03 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(smoothness, metalData, skymapMod, 1.0);

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0361 */
    gl_FragData[2] = vec4(EncodeNormal(newNormal), materialFormatFlag, 1.0);
	gl_FragData[3] = vec4(rawAlbedo, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

#if !defined ENTITY_NORMAL_FIX || MC_VERSION < 11500
varying vec3 binormal, tangent;
#endif

varying vec4 vTexCoord, vTexCoordAM;
#endif

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

//Attributes//
#ifdef ADVANCED_MATERIALS
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
#endif

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

//Program//
void main(){
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord.x = clamp(lmCoord.x, 0.0, 1.0);

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADVANCED_MATERIALS
		#if !defined ENTITY_NORMAL_FIX || MC_VERSION < 11500
			binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
			tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
			
			#if defined PARALLAX || defined SELF_SHADOW
				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									tangent.y, binormal.y, normal.y,
									tangent.z, binormal.z, normal.z);
											
				viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
				dist = length(gl_ModelViewMatrix * gl_Vertex);
			#endif
		#endif

		vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoord - midCoord;

		vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
		vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);

		vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
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

	#ifdef GBUFFERS_ENTITIES_GLOWING
		gl_Position.z *= 0.01;
	#endif
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif