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
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D shadowcolor0;
uniform float viewWidth, viewHeight;
uniform float near, far;

//common functions//
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

#ifdef THE_FORBIDDEN_OPTION
	uniform float frameTimeCounter;
#endif

#ifdef GRAY_START
	uniform float starter;
#endif

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main
const int colortex1Format = RGB8; 			//raw albedo & raw translucent & bloom
const int colortex2Format = RGBA16;		    //temporal stuff
const int colortex3Format = RGB8; 			//specular & skymapMod
const int gaux1Format = RG8; 				//half-res ao & water mask
const int gaux2Format = RGB8;			    //reflection
const int gaux3Format = RGB16; 				//normals & material format
const int gaux4Format = R8; 				//
*/

const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;

const int noiseTextureResolution = 512;

const float drynessHalflife = 300.0;
const float wetnessHalflife = 300.0;

//Common Functions//
#if SHARPEN > 0
	vec2 sharpenOffsets[4] = vec2[4](
		vec2( 1.0,  0.0),
		vec2( 0.0,  1.0),
		vec2(-1.0,  0.0),
		vec2( 0.0, -1.0)
	);

	void SharpenFilter(inout vec3 color, vec2 texCoord2){
		float mult = SHARPEN * 0.025;
		vec2 view = 1.0 / vec2(viewWidth, viewHeight);

		color *= SHARPEN * 0.1 + 1.0;

		for(int i = 0; i < 4; i++){
			vec2 offset = sharpenOffsets[i] * view;
			color -= texture2D(colortex1, texCoord2 + offset).rgb * mult;
		}
	}
#endif

#ifdef GRAY_START
	float GetLuminance(vec3 color){
		return dot(color, vec3(0.299, 0.587, 0.114));
	}
#endif

//Program//
void main() {
	#ifndef OVERDRAW
		vec2 texCoord2 = texCoord;
	#else
		vec2 texCoord2 = (texCoord - vec2(0.5)) * (2.0 / 3.0) + vec2(0.5);
	#endif
	
	/*
	vec2 wh = vec2(viewWidth, viewHeight);
	wh /= 32.0;
	texCoord2 = floor(texCoord2 * wh) / wh;
	*/
	
	#ifdef ANAGLYPH
	float texOffset = 0.01 - clamp(0.0008 / (GetLinearDepth(texture2D(depthtex0, texCoord2).r) + 0.001), 0.0, 0.05);
	vec3 color = vec3(texture2D(colortex1, texCoord2 + vec2(texOffset, 0)).r,texture2D(colortex1, texCoord2 -  vec2(texOffset, 0)).gb);
	#else
	vec3 color = texture2D(colortex1, texCoord2).rgb;
	#endif

	#if SHARPEN > 0
		SharpenFilter(color, texCoord2);
	#endif
	
	#ifdef THE_FORBIDDEN_OPTION
		float fractTime = fract(frameTimeCounter*0.01);
		color = pow(vec3(1.0) - color, vec3(5.0));
		color = vec3(color.r + color.g + color.b)*0.5;
		color.g = 0.0;
		if (fractTime < 0.5)  color.b *= fractTime, color.r *= 0.5 - fractTime;
		if (fractTime >= 0.5) color.b *= 1 - fractTime, color.r *= fractTime - 0.5;
		color = pow(color, vec3(1.8))*8;
	#endif

	#ifdef GRAY_START
		float animation = min(starter, 0.1) * 10.0;
		vec3 grayStart = vec3(GetLuminance(color.rgb));
		color.rgb = mix(grayStart, color.rgb, animation);
	#endif
	
	//gl_FragColor = vec4(texture2D(shadowcolor0, texCoord).rgb, 1.0);
	gl_FragColor = vec4(color, 1.0);
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
