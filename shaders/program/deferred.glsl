/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/ 

//Common//
#include "/lib/common.glsl"

//Varyings//
#ifdef AO
varying vec2 texCoord;
#endif

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
#ifdef AO
uniform float far, near;
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight, aspectRatio;

uniform mat4 gbufferProjection;

uniform sampler2D depthtex0;
#endif

//Common Functions//
#ifdef AO
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

vec2 OffsetDist(float x, int s) {
	float n = fract(x * 1.414) * 3.1415;
    return vec2(cos(n), sin(n)) * x / s;
}

float AmbientOcclusion(sampler2D depth, vec2 coord, float dither) {
	float ao = 0.0;

	#if AO_QUALITY == 1
		#if AA > 1
			int samples = 12;
		#else
			int samples = 4;
		#endif
	#endif

	#if AO_QUALITY == 2
		int samples = 4;
	#endif

	#if AO_QUALITY == 3
		int samples = 12;
	#endif

	#if AO_QUALITY == 4
		int samples = 24;
	#endif

	#if AO_QUALITY == 1 && AA > 1
		coord *= 2.0;
		coord += 0.5 / vec2(viewWidth, viewHeight);

		if (coord.x < 0.0 || coord.x > 1.0 || coord.y < 0.0 || coord.y > 1.0) return 1.0;
	#endif

	#if AA > 1
		dither = fract(frameTimeCounter * 4.0 + dither);
	#endif
	
	float d = texture2D(depth, coord).r;
	if(d >= 1.0) return 1.0;
	float hand = float(d < 0.56);
	d = GetLinearDepth(d);
	
	float sampleDepth = 0.0, angle = 0.0, dist = 0.0;
	float fovScale = gbufferProjection[1][1] / 1.37;
	float distScale = max((far - near) * d + near, 6.0);
	vec2 scale = 0.35 * vec2(1.0 / aspectRatio, 1.0) * fovScale / distScale;
	scale *= vec2(0.5, 1.0);

	for(int i = 1; i <= samples; i++) {
		vec2 offset = OffsetDist(i + dither, samples) * scale;

		sampleDepth = GetLinearDepth(texture2D(depth, coord + offset).r);
		float sample = (far - near) * (d - sampleDepth) * 2.0;
		if (hand > 0.5) sample *= 1024.0;
		angle = clamp(0.5 - sample, 0.0, 1.0);
		dist = clamp(0.5 * sample - 1.0, 0.0, 1.0);

		sampleDepth = GetLinearDepth(texture2D(depth, coord - offset).r);
		sample = (far - near) * (d - sampleDepth) * 2.0;
		if (hand > 0.5) sample *= 1024.0;
		angle += clamp(0.5 - sample, 0.0, 1.0);
		dist += clamp(0.5 * sample - 1.0, 0.0, 1.0);
		
		ao += clamp(angle + dist, 0.0, 1.0);
	}
	ao /= samples;
	
	return ao;
}
#endif

//Includes//
#ifdef AO
	#include "/lib/util/dither.glsl"
#endif

//Program//
void main() {
	#ifdef AO
    	float ao = AmbientOcclusion(depthtex0, texCoord, Bayer64(gl_FragCoord.xy));
	#else
		float ao = 1.0;
	#endif
    
    /* DRAWBUFFERS:4 */
    gl_FragData[0] = vec4(ao, 0.0, 0.0, 1.0);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
#ifdef AO
uniform float timeAngle;

uniform mat4 gbufferModelView;
#endif

//Common Variables//

//Program//
void main() {
	#ifdef AO
		texCoord = gl_MultiTexCoord0.xy;
		
		gl_Position = ftransform();
	#else
		gl_Position = vec4(0.0);
	#endif
}

#endif
