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
uniform float far, near;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex7;
uniform sampler2D depthtex1;

//Optifine Constants//
const bool colortex1MipmapEnabled = true;

//Common Functions//
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#if AA > 1
#include "/lib/antialiasing/taa.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2DLod(colortex1, texCoord, 0.0).rgb;

    #if AA > 1
        vec4 temp = vec4(texture2D(colortex2, texCoord).r, 0.0, 0.0, 0.0);
        TAA(color, temp);
    #endif

    /*DRAWBUFFERS:1*/
	gl_FragData[0] = vec4(color, 1.0);
	#if AA > 1
    /*DRAWBUFFERS:12*/
	gl_FragData[1] = vec4(temp);
	#endif
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