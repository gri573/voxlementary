/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D colortex1;

#if AA > 1
uniform float far, near;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex2;
uniform sampler2D depthtex1;
#endif

//Optifine Constants//
#ifdef LIGHTSHAFT
const bool colortex1MipmapEnabled = true;
#endif

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color, vec3(0.299, 0.587, 0.114));
}

#if AA > 1
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}
#endif

//Includes//
#if AA == 1
#include "/lib/antialiasing/fxaa.glsl"
#endif

#if AA == 2
#include "/lib/antialiasing/liteTaa.glsl"
#endif

#if AA == 3
#include "/lib/antialiasing/liteTaa.glsl"
#include "/lib/antialiasing/plusFxaa.glsl"
#endif

#if AA == 4
#include "/lib/antialiasing/intenseTaa.glsl"
#endif

//Program//
void main() {
   	vec3 color = texture2DLod(colortex1, texCoord, 0.0).rgb;

    #if AA == 1
        FXAA311(color);
    #elif AA > 1
        #if AA == 3
            FXAA311(color);
        #endif
        vec4 temp = vec4(texture2DLod(colortex2, texCoord, 0.0).r, 0.0, 0.0, 0.0);
    	float depth = texture2DLod(depthtex1, texCoord, 0.0).r;
        TAA(color, temp, depth);
    #endif

    /*DRAWBUFFERS:1*/
	gl_FragData[0] = vec4(color, 1.0);
	#if AA > 1
    /*DRAWBUFFERS:12*/
	gl_FragData[1] = vec4(temp);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main(){
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif
