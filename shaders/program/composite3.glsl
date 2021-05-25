/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/ 

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;

uniform sampler2D colortex0;

#if defined DOF_IS_ON || (defined NETHER_BLUR && defined NETHER)

uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D depthtex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;

#if DOF == 2 || (defined NETHER_BLUR && defined NETHER)
uniform mat4 gbufferProjectionInverse;

uniform float rainStrengthS;
uniform ivec2 eyeBrightnessSmooth;
#endif

#if DOF == 1 && !(defined NETHER_BLUR && defined NETHER)
uniform float centerDepthSmooth;
#endif

//Optifine Constants//
const bool colortex0MipmapEnabled = true;

//Common Variables//
vec2 dofOffsets[18] = vec2[18](
	vec2( 0.0    ,  0.25  ),
	vec2(-0.2165 ,  0.125 ),
	vec2(-0.2165 , -0.125 ),
	vec2( 0      , -0.25  ),
	vec2( 0.2165 , -0.125 ),
	vec2( 0.2165 ,  0.125 ),
	vec2( 0      ,  0.5   ),
	vec2(-0.25   ,  0.433 ),
	vec2(-0.433  ,  0.25  ),
	vec2(-0.5    ,  0     ),
	vec2(-0.433  , -0.25  ),
	vec2(-0.25   , -0.433 ),
	vec2( 0      , -0.5   ),
	vec2( 0.25   , -0.433 ),
	vec2( 0.433  , -0.2   ),
	vec2( 0.5    ,  0     ),
	vec2( 0.433  ,  0.25  ),
	vec2( 0.25   ,  0.433 )
);

#if DOF == 2 || (defined NETHER_BLUR && defined NETHER)
float eBS = eyeBrightnessSmooth.y / 240.0;
#endif

//Common Functions//
#if DOF == 2 && !(defined NETHER_BLUR && defined NETHER)
vec3 DepthOfField(vec3 color, float z) { // Distance Blur
	vec3 dof = vec3(0.0);
	float hand = float(z < 0.56);

	float z0 = texture2D(depthtex0, texCoord.xy).r;
	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	float coc = min(length(viewPos) * 0.001, 0.1) * DOF_STRENGTH * (1.0 + max(rainStrengthS * eBS * RAIN_BLUR_MULT, isEyeInWater * UNDERWATER_BLUR_MULT)) / 256;
	coc = max(coc, 0.0);
	coc = coc / sqrt(coc * coc + 0.1);
	coc *= gbufferProjection[1][1] / 1.37;
	
	if (coc * 0.5 > 1.0 / max(viewWidth, viewHeight) && hand < 0.5) {
		for(int i = 0; i < 18; i++) {
			vec2 offset = dofOffsets[i] * coc * 0.0085 * vec2(1.0, aspectRatio);
			#ifdef ANAMORPHIC_BLUR
				offset *= vec2(0.5, 1.5);
			#endif
			float lod = log2(viewHeight * aspectRatio * coc * 0.75 / 320.0);
			dof += texture2DLod(colortex0, texCoord + offset, lod).rgb;
		}
		dof /= 18.0;
	}
	else dof = color;
	return dof;
}
#endif

#if DOF == 1 && !(defined NETHER_BLUR && defined NETHER)
vec3 DepthOfField(vec3 color, float z) { // DOF
	vec3 dof = vec3(0.0);
	float hand = float(z < 0.56);
	
	float coc = max(abs(z - centerDepthSmooth) * 0.125 * DOF_STRENGTH - 0.0001, 0.0);
	coc = coc / sqrt(coc * coc + 0.1);
	coc *= gbufferProjection[1][1] / 1.37;
	
	if (coc * 0.5 > 1.0 / max(viewWidth, viewHeight) && hand < 0.5) {
		for(int i = 0; i < 18; i++) {
			vec2 offset = dofOffsets[i] * coc * 0.0085 * vec2(1.0, aspectRatio);
			#ifdef ANAMORPHIC_BLUR
				offset *= vec2(0.5, 1.5);
			#endif
			float lod = log2(viewHeight * aspectRatio * coc * 0.75 / 320.0);
			dof += texture2DLod(colortex0, texCoord + offset, lod).rgb;
		}
		dof /= 18.0;
	}
	else dof = color;
	return dof;
}
#endif

#if defined NETHER_BLUR && defined NETHER
vec3 DepthOfField(vec3 color, float z) { // Nether Blur
	vec3 dof = vec3(0.0);
	float hand = float(z < 0.56);

	float z0 = texture2D(depthtex0, texCoord.xy).r;
	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;
	
	float coc = max(min(length(viewPos) * 0.001, 0.1) * NETHER_BLUR_STRENGTH / 256, 0.0);
	coc = coc / sqrt(coc * coc + 0.1);
	coc *= gbufferProjection[1][1] / 1.37;
	
	if (coc * 0.5 > 1.0 / max(viewWidth, viewHeight) && hand < 0.5) {
		for(int i = 0; i < 18; i++) {
			vec2 offset = dofOffsets[i] * coc * 0.0085 * vec2(1.0, aspectRatio);
			#ifdef ANAMORPHIC_BLUR
				offset *= vec2(0.5, 1.5);
			#endif
			float lod = log2(viewHeight * aspectRatio * coc * 0.75 / 320.0);
			dof += texture2DLod(colortex0, texCoord + offset, lod).rgb;
		}
		dof /= 18.0;
	}
	else dof = color;
	return dof;
}
#endif

//Includes//

#endif

//Program//
void main() {
	vec3 color = texture2DLod(colortex0, texCoord, 0.0).rgb;
	
	#if defined DOF_IS_ON || (defined NETHER && defined NETHER_BLUR)
	float z = texture2D(depthtex1, texCoord.st).x;

	color = DepthOfField(color, z);
	#endif
	
    /*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color,1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif