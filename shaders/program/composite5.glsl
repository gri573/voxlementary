/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

//Common//
#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FSH

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float frameTimeCounter;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D noisetex;
uniform sampler2D depthtex1;

#ifdef LENS_FLARE
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
#endif

#ifdef BLURRY_START
	uniform float starter;
#endif

//Optifine Constants//
#if AUTO_EXPOSURE > 0
const bool colortex0MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);
float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void UnderwaterDistort(inout vec2 texCoord) {
	vec2 originalTexCoord = texCoord;

	float wind = frameTimeCounter * ANIMATION_SPEED;
	texCoord +=vec2(cos(texCoord.y * 32.0 + wind * 3.0),
	                sin(texCoord.x * 32.0 + wind * 1.7)) * 0.001 * UNDERWATER_DISTORT;

	float mask = float(texCoord.x > 0.0 && texCoord.x < 1.0 &&
	                   texCoord.y > 0.0 && texCoord.y < 1.0);
	if (mask < 0.5) texCoord = originalTexCoord;
}

vec3 GetBloomTile(float lod, vec2 coord, vec2 offset) {
	vec3 bloom = texture2D(colortex1, coord / pow(2.0, lod) + offset).rgb;
	bloom *= bloom;
	bloom *= bloom;
	return bloom * 128.0;
}

void Bloom(inout vec3 color, vec2 coord) {
	vec3 blur1 = GetBloomTile(2.0, coord, vec2(0.0      , 0.0   ));
	vec3 blur2 = GetBloomTile(3.0, coord, vec2(0.0      , 0.26  ));
	vec3 blur3 = GetBloomTile(4.0, coord, vec2(0.135    , 0.26  ));
	vec3 blur4 = GetBloomTile(5.0, coord, vec2(0.2075   , 0.26  ));
	vec3 blur5 = GetBloomTile(6.0, coord, vec2(0.135    , 0.3325));
	vec3 blur6 = GetBloomTile(7.0, coord, vec2(0.160625 , 0.3325));
	vec3 blur7 = GetBloomTile(8.0, coord, vec2(0.1784375, 0.3325));

	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7) * 0.14;
	
	float bloomStrength = BLOOM_STRENGTH;
	#ifdef NETHER
		bloomStrength *= NETHER_BLOOM_MULTIPLIER;
	#endif

	bloomStrength *= 0.18;
	
	#ifdef BLURRY_START
		float animation = min(starter, 0.1) * 10.0;
		bloomStrength = mix(1.0, bloomStrength, animation);
	#endif

	color = mix(color, blur, bloomStrength);
}

void AutoExposure(inout vec3 color, inout float exposure, float tempExposure) {
	float exposureLod = log2(viewWidth * 0.3);
	
	exposure = length(texture2DLod(colortex0, vec2(0.5), exposureLod).rgb);
	exposure = clamp(exposure, 0.0001, 10.0);
	
	#if AUTO_EXPOSURE == 1
		color /= 2.5 * clamp(tempExposure, 0.001, 0.5) + 0.125;
	#else
		color /= 3 * tempExposure;
	#endif
}

void ColorGrading(inout vec3 color) {
	vec3 cgColor = pow(color.r, CG_RC) * pow(vec3(CG_RR, CG_RG, CG_RB) / 255.0, vec3(2.2)) +
				   pow(color.g, CG_GC) * pow(vec3(CG_GR, CG_GG, CG_GB) / 255.0, vec3(2.2)) +
				   pow(color.b, CG_BC) * pow(vec3(CG_BR, CG_BG, CG_BB) / 255.0, vec3(2.2));
	vec3 cgMin = pow(vec3(CG_RM, CG_GM, CG_BM) / 255.0, vec3(2.2));
	color = (cgColor * (1.0 - cgMin) + cgMin) * vec3(CG_RI, CG_GI, CG_BI);
	
	vec3 cgTint = pow(vec3(CG_TR, CG_TG, CG_TB) / 255.0, vec3(2.2)) * GetLuminance(color) * CG_TI;
	color = mix(color, cgTint, CG_TM);
}

void BSLTonemap(inout vec3 color) {
	float tonemapExposure = TONEMAP_EXPOSURE;
	#ifdef TWO
		tonemapExposure *= 2.0 + vsBrightness;
	#endif
	color = tonemapExposure * color;
	color = color / pow(pow(color, vec3(TONEMAP_WHITE_CURVE)) + 1.0, vec3(1.0 / TONEMAP_WHITE_CURVE));
	color = pow(color, mix(vec3(TONEMAP_LOWER_CURVE), vec3(TONEMAP_UPPER_CURVE), sqrt(color)));
}

void ColorSaturation(inout vec3 color) {
	float grayVibrance = (color.r + color.g + color.b) / 3.0;
	float graySaturation = grayVibrance;
	if (SATURATION < 1.00) graySaturation = dot(color, vec3(0.299, 0.587, 0.114));

	float mn = min(color.r, min(color.g, color.b));
	float mx = max(color.r, max(color.g, color.b));
	float sat = (1.0 - (mx - mn)) * (1.0 - mx) * grayVibrance * 5.0;
	vec3 lightness = vec3((mn + mx) * 0.5);

	color = mix(color, mix(color, lightness, 1.0 - VIBRANCE), sat);
	color = mix(color, lightness, (1.0 - lightness) * (2.0 - VIBRANCE) / 2.0 * abs(VIBRANCE - 1.0));
	color = color * SATURATION - graySaturation * (SATURATION - 1.0);
}

#ifdef LENS_FLARE
vec2 GetLightPos() {
	vec4 tpos = gbufferProjection * vec4(sunPosition, 1.0);
	tpos.xyz /= tpos.w;
	return tpos.xy / tpos.z * 0.5;
}
#endif

//Includes//
#include "/lib/color/lightColor.glsl"

#ifdef LENS_FLARE
#include "/lib/post/lensFlare.glsl"
#endif

//Program//
void main() {
    vec2 newTexCoord = texCoord;
	if (isEyeInWater == 1.0) UnderwaterDistort(newTexCoord);
	
	vec3 color = texture2D(colortex0, newTexCoord).rgb;
	
	#if AUTO_EXPOSURE > 0
		float tempExposure = texture2D(colortex2, vec2(pw, ph)).r;
	#endif

	#ifdef LENS_FLARE
		float tempVisibleSun = texture2D(colortex2, vec2(3.0 * pw, ph)).r;
	#endif

	vec3 temporalColor = vec3(0.0);
	#if AA > 1
		temporalColor = texture2D(colortex2, texCoord).gba;
	#endif
	
	#ifdef BLOOM
		Bloom(color, newTexCoord);
	#endif
	
	#if AUTO_EXPOSURE > 0
		float exposure = 1.0;
		AutoExposure(color, exposure, tempExposure);
	#endif
	
	#ifdef COLOR_GRADING
		ColorGrading(color);
	#endif
	
	BSLTonemap(color);
	
	#ifdef LENS_FLARE
		vec2 lightPos = GetLightPos();
		float truePos = sign(sunVec.z);
			
		float visibleSun = float(texture2D(depthtex1, lightPos + 0.5).r >= 1.0);
		visibleSun *= max(1.0 - isEyeInWater, eBS) * (1.0 - blindFactor) * (1.0 - rainStrengthS);
		
		float multiplier = tempVisibleSun * LENS_FLARE_STRENGTH * 0.5;

		if (multiplier > 0.001) LensFlare(color, lightPos, truePos, multiplier);
	#endif
	
	float temporalData = 0.0;
	
	#if AUTO_EXPOSURE > 0
		if (texCoord.x < 2.0 * pw && texCoord.y < 2.0 * ph)
			temporalData = mix(tempExposure, sqrt(exposure), 0.016);
	#endif

	#ifdef LENS_FLARE
		if (texCoord.x > 2.0 * pw && texCoord.x < 4.0 * pw && texCoord.y < 2.0 * ph)
			temporalData = mix(tempVisibleSun, visibleSun, 0.1);
	#endif
	
    #ifdef VIGNETTE
   		color *= 1.0 - length(texCoord.xy - 0.5) * VIGNETTE_STRENGTH * (1.0 - GetLuminance(color));
	#endif
	
	color = pow(color, vec3(1.0 / 2.2));
	
	ColorSaturation(color);
	
	vec2 filmGrainCoord = texCoord * vec2(viewWidth, viewHeight) / 512.0;
	vec3 filmGrain = texture2D(noisetex, filmGrainCoord).rgb;
	color += (filmGrain - 0.25) / 128.0;
	
	/*DRAWBUFFERS:12*/
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(temporalData, temporalColor);
}

#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VSH

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Common Variables//
#ifdef OVERWORLD
	float timeAngleM = timeAngle;
#else
	#if !defined SEVEN && !defined SEVEN_2
		float timeAngleM = 0.25;
	#else
		float timeAngleM = 0.5;
	#endif
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif