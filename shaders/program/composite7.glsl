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
uniform float viewWidth, viewHeight;

uniform sampler2D colortex1;

//Optifine Constants//

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

//Includes//
#if AA == 1 || AA == 3
#include "/lib/antialiasing/fxaa.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex1, texCoord).rgb;

    #if AA == 1 || AA == 3
        FXAA311(color);
    #endif

    /*DRAWBUFFERS:1*/
	gl_FragData[0] = vec4(color, 1.0);
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