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
	
	#ifndef COMPATIBILITY_MODE
		albedo.rgb = pow(albedo.rgb,vec3(3.6));
		albedo *= pow(1+albedo.b, 3);
	#else
   		albedo.rgb = pow(albedo.rgb,vec3(2.2));
	#endif
	
    #ifdef WHITE_WORLD
		albedo.rgb = vec3(2.0);
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(170.0, 0.0, 0.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0361 */
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

//Includes//
#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	#ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
	#endif
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
}

#endif