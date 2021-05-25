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
uniform sampler2D texture;

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord.xy);
	
	albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 2.25;
	
	#ifdef WHITE_WORLD
		albedo.a = 0.0;
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(170.0, 170.0, 170.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
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

#ifdef WORLD_CURVATURE
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
#endif

//Includes//
#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	#ifdef WORLD_CURVATURE
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	position.y -= WorldCurvature(position.xz);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
	gl_Position = ftransform();
	#endif
	
	#if AA > 1
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif