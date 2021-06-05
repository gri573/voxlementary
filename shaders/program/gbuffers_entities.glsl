/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Varyings//
varying float water;
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef INTERACTIVE_WATER
varying vec3 velocity;
#endif

#ifdef ADV_MAT
	#if defined PARALLAX || defined SELF_SHADOW
		varying float dist;
		varying vec3 viewVector;
	#endif

	varying vec4 vTexCoord;

	#if !defined COMPBR || defined NORMAL_MAPPING
		varying vec4 vTexCoordAM;
	#endif

	#ifdef NORMAL_MAPPING
		varying vec3 binormal, tangent;
	#endif
#endif

//Uniforms//
uniform int entityId;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int moonPhase;

#ifdef DYNAMIC_SHADER_LIGHT
	uniform int heldItemId, heldItemId2;

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

#if defined ADV_MAT && !defined COMPBR
uniform sampler2D specular;
uniform sampler2D normals;
#endif

#ifdef COMPBR
uniform ivec2 atlasSize;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#if defined ADV_MAT && RP_SUPPORT > 2
vec2 dcdx = dFdx(texCoord.xy);
vec2 dcdy = dFdy(texCoord.xy);
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
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"

#ifdef WATER_CAUSTICS
#ifdef OVERWORLD
#include "/lib/color/waterColor.glsl"
#endif
#endif

#include "/lib/lighting/forwardLighting.glsl"

#ifdef ADV_MAT
#include "/lib/util/encode.glsl"
#include "/lib/surface/ggx.glsl"

#ifndef COMPBR
#include "/lib/surface/materialGbuffers.glsl"
#endif

#if defined PARALLAX || defined SELF_SHADOW
#include "/lib/surface/parallax.glsl"
#endif
#endif

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * color;
	vec2 screentexcoord = 0.5 * gl_FragCoord.xy / vec2(viewWidth, viewHeight) + vec2(0.5);
	vec4 wdata = vec4(0);
	vec3 newNormal = normal;
	
	float smoothness = 0.0, metalData = 0.0, metalness = 0.0, f0 = 0.0, skymapMod = 0.0;
	vec4 rawAlbedo = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 normalMap = vec3(0.0, 0.0, 1.0);

	#ifdef INTERACTIVE_WATER
	if (water > 1000) {
	#endif
		float itemFrameOrPainting = float(entityId == 18);

		#ifdef ADV_MAT
			#if !defined COMPBR || defined NORMAL_MAPPING
				vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
			#endif
			
			#if defined PARALLAX || defined SELF_SHADOW
				float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
				float skipParallax = itemFrameOrPainting;
			#endif
			
			#ifdef PARALLAX
				if (skipParallax < 0.5) {
					GetParallaxCoord(parallaxFade, newCoord);
					albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * color;
				}
			#endif
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

		if (albedocheck > 0.00001 && lightningBolt < 0.5) {
			if (albedo.a > 0.99) albedo.a = 1.0;

			vec2 lightmap = lmCoord;
				
			#ifdef ENTITY_EFFECT
				float emissive = float(entityColor.a > 0.05) * 0.01;
			#else
				float emissive = 0.0;
			#endif

			vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
			vec3 viewPos = ToNDC(screenPos);
			vec3 worldPos = ToWorld(viewPos);
			float lViewPos = length(viewPos.xyz);
			float lViewPosToLight = lViewPos;

			#if defined FOG1 && defined FOG1_CHECK
				float lWorldPos = length(worldPos.xz);
				float fog1 = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
				fog1 = 1.0 - exp(-0.1 * pow(fog1, 10.0));
				if (fog1 > 0.95) discard;
			#endif

			float ao = 1.0;
			#ifdef ADV_MAT
				#ifndef COMPBR
					GetMaterials(smoothness, metalness, f0, metalData, emissive, ao, normalMap, newCoord, dcdx, dcdy);
				#else
				if (entityId > 10200.5) {
					float lAlbedo = length(albedo.rgb);
				if (entityId < 10206.5) {
				if (entityId < 10203.5) {
					if (entityId == 10201) { // End Crystal
						lightmap.x *= 0.85;
						metalness = 1.0;
						metalData = 1.0;
						emissive = 10.0 * float(albedo.r * 2.0 > albedo.b + albedo.g);
					}
					else if (entityId == 10202) { // Endermite
						emissive = float(albedo.r > albedo.b);
					}
					else if (entityId == 10203 && atlasSize.x < 900.0) { // Witch
						emissive = 0.35 * albedo.g * albedo.g * float(albedo.g * 1.5 > albedo.b + albedo.r);
					}
				} else {
					if (entityId == 10204) { // Blaze
						emissive = float(lAlbedo > 1.7);
					}
					else if (entityId == 10205) { // Wither, Wither Skull
						emissive = float(lAlbedo > 1.0);
					}
					else if (entityId == 10206) { // Magma Cube
						emissive = float(lAlbedo > 0.7);
					}
				}
				} else {
				if (entityId < 10209.5) {
					if (entityId == 10207 && atlasSize.x < 900.0) { // Vex
						emissive = 0.5 * float(lAlbedo > 1.3);
					}
					else if (entityId == 10208) { // Charged Creeper
						if (albedo.b > albedo.g + 0.01) {
							albedo.rgb = lAlbedo * vec3(1.0, 1.25, 1.5);
							emissive = 0.05;
							lightmap = vec2(0.0);
						}
					}
					else if (entityId == 10209 && atlasSize.x < 900.0) { // Drowned
						emissive = float(lAlbedo > 1.0);
					}
				} else {
					if (entityId == 10210 && atlasSize.x < 900.0) { // Stray
						emissive = float(lAlbedo > 1.6 && vTexCoord.y > 0.45);
					}
					else if (entityId == 10211) { // Ghast
						emissive = float(albedo.r > albedo.g + albedo.b + 0.1);
					}
					else if (entityId == 10212) { // Fireball, Dragon Fireball
						emissive = lAlbedo * lAlbedo * 0.25;
					}
					else if (entityId == 10213) { // Glow Squid
						lightmap.x *= 0.5;
						emissive = lAlbedo * lAlbedo * 0.25;
						emissive *= emissive;
						emissive *= emissive;
					}
				}
				}
				}
				#endif

				#ifndef COMPATIBILITY_MODE
					if (entityId == 10001) { // Experience Orb
						emissive = 1.0;
					}
				#endif
				
				#ifdef NORMAL_MAPPING
					mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
										tangent.y, binormal.y, normal.y,
										tangent.z, binormal.z, normal.z);

					if (normalMap.x > -0.999 && normalMap.y > -0.999)
						newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
				#endif
			#endif

			#ifdef ENTITY_EFFECT
				if (entityColor.a > 0.001) {
					albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
				}
			#endif

			albedo.rgb = pow(albedo.rgb, vec3(2.2));

			#ifdef WHITE_WORLD
				albedo.rgb = vec3(0.5);
			#endif

			float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

			if (itemFrameOrPainting > 0.5) {
				skymapMod = 0.51;
				lightmap = clamp(lightmap, vec2(0.0), vec2(0.875, 1.0));
				lViewPosToLight += DYNAMIC_LIGHT_DISTANCE / 14.0;
				NdotL = 0.5;
			}

			float quarterNdotU = clamp(0.25 * dot(newNormal, upVec) + 0.75, 0.5, 1.0);
				quarterNdotU*= quarterNdotU;

			float parallaxShadow = 1.0;
			float materialAO = 1.0;
			#ifdef ADV_MAT
				rawAlbedo.rgb = albedo.rgb * 0.999 + 0.001;
				#ifdef COMPBR
					albedo.rgb *= ao;
					if (metalness > 0.80) {
						albedo.rgb *= (1.0 - metalness*0.65);
					}
				#else
					materialAO = ao;
					albedo.rgb *= (1.0 - metalness*0.65);
				#endif

				float doParallax = 0.0;
				#ifdef SELF_SHADOW
					#ifdef OVERWORLD
						doParallax = float(lightmap.y > 0.0 && NdotL > 0.0);
					#endif
					#ifdef END
						doParallax = float(NdotL > 0.0);
					#endif
					
					if (doParallax > 0.5) {
						parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix);
						NdotL *= parallaxShadow;
					}
				#endif
			#endif
			
			float shadow = 0.0;
			vec3 lightAlbedo = vec3(0.0);
			GetLighting(albedo.rgb, shadow, lightAlbedo, viewPos, lViewPosToLight, worldPos, lightmap, 1.0, NdotL, quarterNdotU,
						parallaxShadow, emissive, 0.0, 0.0, materialAO);

			#ifdef ADV_MAT
				#if defined OVERWORLD || defined END
					#ifdef OVERWORLD
						vec3 lightME = mix(lightMorning, lightEvening, mefade);
						vec3 lightDayTint = lightDay * lightME * LIGHT_DI;
						vec3 lightDaySpec = mix(lightME, sqrt(lightDayTint), timeBrightness);
						vec3 specularColor = mix(sqrt(lightNight*0.3),
													lightDaySpec,
													sunVisibility);
						#ifdef WATER_CAUSTICS
							if (isEyeInWater == 1) specularColor *= underwaterColor.rgb * 8.0;
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
					
					vec3 specularHighlight = GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo.rgb,
													shadow, newNormal, viewPos);
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
	#ifdef INTERACTIVE_WATER
	} else {
		if (abs(water) > 20 * VXHEIGHT * VXHEIGHT) discard;
		wdata = vec4(velocity.y * 20 + 0.5, water / 64.0 + 0.5, 0, 1);
		albedo = vec4(0.0, 0.0, 0.0, 1.0);
	}
	#endif
    /* DRAWBUFFERS:037 */
		gl_FragData[0] = albedo;
		gl_FragData[1] = vec4(smoothness, metalData, skymapMod, float(water < -999.5));
		gl_FragData[2] = vec4(1.0);

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:03761 */
	    gl_FragData[3] = vec4(EncodeNormal(newNormal), 0.0, 1.0);
		gl_FragData[4] = rawAlbedo;
		#ifdef INTERACTIVE_WATER
		/* DRAWBUFFERS:037619 */
			gl_FragData[5] = wdata;
		#endif
	#else
		#ifdef INTERACTIVE_WATER
		/* DRAWBUFFERS:0379 */
			gl_FragData[3] = wdata;
		#endif
	#endif
}

#endif

/////////Geometry Shader////////Geometry Shader////////Geometry Shader/////////
#ifdef GSH
//Varyings//
varying in vec2[3] texCoordV, lmCoordV;

varying in vec3[3] normalV;
varying in vec3[3] sunVecV, upVecV;

varying in vec4[3] colorV;
varying in vec4[3] waterPos;

#ifdef INTERACTIVE_WATER
varying in vec3[3] velocityV;
#endif

#ifdef ADV_MAT
	#if defined PARALLAX || defined SELF_SHADOW
		varying in float[3] distV;
		varying in vec3[3] viewVectorV;
	#endif

	varying in vec4[3] vTexCoordV;

	#if !defined COMPBR || defined NORMAL_MAPPING
		varying in vec4[3] vTexCoordAMV;
	#endif

	#ifdef NORMAL_MAPPING
		varying in vec3[3] binormalV, tangentV;
	#endif
#endif


varying out float water;
varying out vec2 texCoord, lmCoord;

varying out vec3 normal;
varying out vec3 sunVec, upVec;

varying out vec4 color;

#ifdef INTERACTIVE_WATER
varying out vec3 velocity;
#endif

#ifdef ADV_MAT
	#if defined PARALLAX || defined SELF_SHADOW
		varying out float dist;
		varying out vec3 viewVector;
	#endif

	varying out vec4 vTexCoord;

	#if !defined COMPBR || defined NORMAL_MAPPING
		varying out vec4 vTexCoordAM;
	#endif

	#ifdef NORMAL_MAPPING
		varying out vec3 binormal, tangent;
	#endif
#endif

//Optifine Constants//
#ifdef INTERACTIVE_WATER
const int maxVerticesOut = 6;
#else
const int maxVerticesOut = 3;
#endif

//Program//
void main() {
	for (int i = 0; i < 3; i++) {
		texCoord = texCoordV[i];
		lmCoord = lmCoordV[i];
		normal = normalV[i];
		sunVec = sunVecV[i];
		upVec = upVecV[i];
		color = colorV[i];
		water = 10000.0;
		#ifdef INTERACTIVE_WATER
			velocity = velocityV[i];
		#endif
		#ifdef ADV_MAT
			#if defined PARALLAX || defined SELF_SHADOW
				dist = distV[i];
				viewVector = viewVectorV[i];
			#endif

			vTexCoord = vTexCoordV[i];

			#if !defined COMPBR || defined NORMAL_MAPPING
				vTexCoordAM = vTexCoordAMV[i];
			#endif

			#ifdef NORMAL_MAPPING
				binormal = binormalV[i];
				tangent = tangentV[i];
			#endif
		#endif
		gl_Position = gl_PositionIn[i];
		EmitVertex();
	}
	EndPrimitive();
	#ifdef INTERACTIVE_WATER
		for (int i = 0; i < 3; i++) {
			texCoord = texCoordV[i];
			lmCoord = lmCoordV[i];
			normal = normalV[i];
			sunVec = sunVecV[i];
			upVec = upVecV[i];
			color = colorV[i];
			water = waterPos[i].y;
			#ifdef INTERACTIVE_WATER
				velocity = velocityV[i];
			#endif
			#ifdef ADV_MAT
				#if defined PARALLAX || defined SELF_SHADOW
					dist = distV[i];
					viewVector = viewVectorV[i];
				#endif

				vTexCoord = vTexCoordV[i];

				#if !defined COMPBR || defined NORMAL_MAPPING
					vTexCoordAM = vTexCoordAMV[i];
				#endif

				#ifdef NORMAL_MAPPING
					binormal = binormalV[i];
					tangent = tangentV[i];
				#endif
			#endif
			gl_Position = vec4(waterPos[i].xz * 2, 0.0, 1.0);
			EmitVertex();
		}
		EndPrimitive();
	#endif
}
#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH
//Varyings//
varying vec2 texCoordV, lmCoordV;

varying vec3 normalV;
varying vec3 sunVecV, upVecV;

varying vec4 colorV;
varying vec4 waterPos;
#ifdef INTERACTIVE_WATER
varying vec3 velocityV;
#endif

#ifdef ADV_MAT
	#if defined PARALLAX || defined SELF_SHADOW
		varying float distV;
		varying vec3 viewVectorV;
	#endif

	varying vec4 vTexCoordV;

	#if !defined COMPBR || defined NORMAL_MAPPING
		varying vec4 vTexCoordAMV;
	#endif

	#ifdef NORMAL_MAPPING
		varying vec3 binormalV, tangentV;
	#endif
#endif

//Uniforms//
uniform int worldTime;
uniform int entityId;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform float viewWidth, viewHeight;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

//Attributes//
#ifdef ADV_MAT
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
#endif
attribute vec3 at_velocity;

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
#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoordV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoordV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoordV = clamp(lmCoordV, vec2(0.0), vec2(1.0));
	lmCoordV.x -= max(lmCoordV.x - 0.825, 0.0) * 0.75;

	normalV = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADV_MAT
		#if defined NORMAL_MAPPING
			binormalV = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
			tangentV  = normalize(gl_NormalMatrix * at_tangent.xyz);
			
			#if defined PARALLAX || defined SELF_SHADOW
				mat3 tbnMatrix = mat3(tangentV.x, binormalV.x, normalV.x,
									  tangentV.y, binormalV.y, normalV.y,
									  tangentV.z, binormalV.z, normalV.z);
			
				viewVectorV = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
				distV = length(gl_ModelViewMatrix * gl_Vertex);
			#endif
		#endif

		vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoordV - midCoord;
		vTexCoordV.xy    = sign(texMinMidCoord) * 0.5 + 0.5;

		#if !defined COMPBR || defined NORMAL_MAPPING
			vTexCoordAMV.pq  = abs(texMinMidCoord) * 2;
			vTexCoordAMV.st  = min(texCoordV, midCoord - texMinMidCoord);
		#endif
	#endif
    
	colorV = gl_Color;

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVecV = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVecV = normalize(gbufferModelView[1].xyz);

    
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	#ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
	#endif
	#ifdef FLICKERING_FIX
		if (entityId == 18) position.y -= 0.001;
	#endif
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	waterPos = position;
	waterPos.xyz += cameraPosition - floor(previousCameraPosition) - vec3(0.5);
	waterPos.xz *= INTERACTIVE_WATER_RES / vec2(viewWidth, viewHeight);
	#ifdef INTERACTIVE_WATER
	velocityV = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(at_velocity, 1.0)).xyz;
	#endif

	#ifdef GBUFFERS_ENTITIES_GLOWING
		gl_Position.z *= 0.01;
	#endif
}

#endif