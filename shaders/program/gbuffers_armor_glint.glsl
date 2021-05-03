/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec4 color;

//Uniforms//
uniform sampler2D texture;

//Program//
void main(){
	vec4 albedo = texture2D(texture, texCoord.xy) * color;
	
	#ifdef GREY
		albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
	#endif
	
	#if MC_VERSION >= 11500
		albedo.rgb = pow(albedo.rgb,vec3(1.6));
		albedo.rgb *= 0.25;
	#else
		albedo.rgb = pow(albedo.rgb,vec3(2.2));
	#endif

	#ifdef GBUFFER_CODING
		albedo.rgb = vec3(255.0, 85.0, 255.0) / 255.0;
		albedo.rgb = pow(albedo.rgb, vec3(2.2)) * 1.0;
	#endif

	albedo.rgb *= GLINT_BRIGHTNESS;
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec4 color;

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;

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

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main(){
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	color = gl_Color;

	#ifdef WORLD_CURVATURE
		vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
		if (gl_ProjectionMatrix[2][2] < -0.5) position.y -= WorldCurvature(position.xz);
		gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
		gl_Position = ftransform();
	#endif

	if (HAND_SWAY > 0.001) {
		if (gl_ProjectionMatrix[2][2] > -0.5) {
		gl_Position.x += HAND_SWAY * (sin(frametime * 0.86)) / 256.0;
		gl_Position.y += HAND_SWAY * (cos(frametime * 1.5)) / 64.0;
		}
	}
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif