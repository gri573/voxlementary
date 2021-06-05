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

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord.xy) * color;
	
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

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

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
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	color = gl_Color;

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	#ifdef WORLD_CURVATURE
		if (gl_ProjectionMatrix[2][2] < -0.5) position.y -= WorldCurvature(position.xz);
	#endif
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	if (gl_ProjectionMatrix[2][2] > -0.5) { // Hands
		if (HAND_SWAY > 0.001) {
			gl_Position.x += HAND_SWAY * (sin(frametime * 0.86)) / 256.0;
			gl_Position.y += HAND_SWAY * (cos(frametime * 1.5)) / 64.0;
		}
	}
}

#endif