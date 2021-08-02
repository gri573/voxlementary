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
uniform float viewWidth, viewHeight, aspectRatio;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D depthtex1;

#ifdef REFLECTION_CAPTURE
uniform float near, far;
uniform sampler2D colortex9;
uniform sampler2D depthtex0;
#endif

//Optifine Constants
#ifdef REFLECTION_CAPTURE
const bool colortex9Clear = false;
#endif

//Common Functions//
#ifdef REFLECTION_CAPTURE
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}
#endif

vec3 MotionBlur(vec3 color, float z, float dither) {
	
	float hand = float(z < 0.56);

	if (hand < 0.5) {
		float mbwg = 0.0;
		vec2 doublePixel = 2.0 / vec2(viewWidth, viewHeight);
		vec3 mblur = vec3(0.0);
		
		vec4 currentPosition = vec4(texCoord, z, 1.0) * 2.0 - 1.0;
		
		vec4 viewPos = gbufferProjectionInverse * currentPosition;
		viewPos = gbufferModelViewInverse * viewPos;
		viewPos /= viewPos.w;
		
		vec3 cameraOffset = cameraPosition - previousCameraPosition;
		
		vec4 previousPosition = viewPos + vec4(cameraOffset, 0.0);
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition /= previousPosition.w;

		vec2 velocity = (currentPosition - previousPosition).xy;
		velocity = velocity / (1.0 + length(velocity)) * MOTION_BLUR_STRENGTH * 0.02;
		
		vec2 coord = texCoord.st - velocity * (3.5 + dither);
		for(int i = 0; i < 9; i++, coord += velocity) {
			vec2 coordb = clamp(coord, doublePixel, 1.0 - doublePixel);
			mblur += texture2DLod(colortex0, coordb, 0.0).rgb;
			mbwg += 1.0;
		}
		mblur /= mbwg;

		return mblur;
	}
	else return color;
}


//Includes//
#include "/lib/util/dither.glsl"

//Program//
void main() {
    vec3 color = texture2D(colortex0,texCoord).rgb;
	
	#ifdef MOTION_BLUR
	float z = texture2D(depthtex1, texCoord.st).x;
	float dither = Bayer64(gl_FragCoord.xy);

	color = MotionBlur(color, z, dither);
	#endif
	#ifdef REFLECTION_CAPTURE
		vec3 aroundPos = vec3(sin(6.283 * texCoord.x), 3 * texCoord.y - 1.5 , cos(6.283 * texCoord.x));
		//aroundPos.y = aroundPos.y * aroundPos.y * aroundPos.y + aroundPos.y * 0.6;
		aroundPos = normalize(aroundPos);
		vec4 clipPosNew = gbufferProjection * gbufferModelView * vec4(aroundPos * 100.0, 1.0);
		clipPosNew.xyz /= clipPosNew.w;
		vec4 aroundProjection = texture2D(colortex9, texCoord);
/*		vec3 aroundWorldPos = cameraPosition + GetLinearDepth(aroundProjection.a) * aroundPos;
		vec3 aroundPosOld = aroundWorldPos - previousCameraPosition;
		aroundPosOld /= length(aroundPosOld.xz);
		vec2 texCoordOld = vec2(acos(aroundPosOld.z), (aroundPosOld.y + 1.5) / 3.0);
		if(aroundPosOld.x < 0.0) texCoordOld.x = 6.283 - texCoordOld.x;
		texCoordOld.x /= 6.283;
		aroundProjection = texture2D(colortex9, fract(texCoordOld));*/
		if (abs(clipPosNew.x) < 1.0 && abs(clipPosNew.y) < 1.0 && clipPosNew.w > 0.0) {
			vec3 newProjection = texture2D(colortex0, clipPosNew.xy * 0.5 + vec2(0.5)).rgb;
			float Depth = texture2D(depthtex0, clipPosNew.xy * 0.5 + vec2(0.5)).r;
			if (Depth > 0.8) aroundProjection = vec4(newProjection, 1.0);
		} else {
			aroundProjection.a *= exp(-0.2 * length(cameraPosition - previousCameraPosition));
		}
		aroundProjection.rgb *= min(aroundProjection.a * 10, 1.0);
	#endif
	
	/*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color,1.0);
	#ifdef REFLECTION_CAPTURE
		/*DRAWBUFFERS:09*/
		gl_FragData[1] = aroundProjection;
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
