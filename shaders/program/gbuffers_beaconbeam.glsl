/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

varying vec4 color;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform sampler2D texture;

//Includes//
#include "/lib/color/blocklightColor.glsl"

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord.xy) * color * 0.8229;
    
	albedo.rgb = pow(albedo.rgb,vec3(5.0)) * 10.0;
	
	#ifdef WHITE_WORLD
		albedo.rgb = vec3(2.0);
	#endif
    
	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(0.0, 170.0, 170.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 0.5;
	#endif

    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;

	#if defined ADV_MAT && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0361 */
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
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

	color = gl_Color;

	#ifdef WORLD_CURVATURE
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	if (gl_ProjectionMatrix[2][2] < -0.5) position.y -= WorldCurvature(position.xz);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
	gl_Position = ftransform();
	#endif
	
	#if AA > 1
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif