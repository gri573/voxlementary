#include "/lib/common.glsl"

#ifdef FSH
//Local Varyings
varying vec2 screentexcoord;
varying vec2 lmCoordF;
varying vec2 texCoordF;
varying vec4 glcolorF;
varying vec3 glnormalF;
varying float matF;
varying float heightF;
varying vec4 positionF;

//Uniforms//

uniform int isEyeInWater;
uniform vec3 cameraPosition;
uniform ivec2 atlasSize;
uniform sampler2D tex;
uniform sampler2D lightmap;
uniform sampler2D shadowcolor1;
#ifdef SHADOWS
uniform sampler2D shadowtex0;
uniform sampler2D noisetex;
#endif

//Optifine Constants//
const float shadowDistanceRenderMul = 1.0;

//Other Random Things//
vec2[4] offsets = vec2[4](
	vec2(-1, -1),
	vec2(-1, 1),
	vec2(1, -1),
	vec2(1, 1)
);
#ifdef SHADOWS
//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
uniform int worldTime;
#else
uniform float frameTimeCounter;
#endif

#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/util/dither.glsl"

//Common Functions//
void doWaterShadowCaustics(inout vec4 albedo, float dither) {
	#if defined WATER_CAUSTICS && defined OVERWORLD && defined LIGHTSHAFT_WATER_CAUSTICS
		vec3 worldPos = positionF.xyz + cameraPosition.xyz;
		#if LIGHT_SHAFT_MODE > 1
			worldPos *= 0.5;
		#else
			worldPos *= 2.0;
		#endif
		float noise = 0.0;
		float mult = 0.5;
		
		vec2 wind = vec2(frametime) * 0.3; //speed
		float verticalOffset = worldPos.y * 0.2;

		if (mult > 0.01) {
			float lacunarity = 1.0 / 750.0, persistance = 1.0, weight = 0.0;

			mult *= (lmCoordF.y*0.9 + 0.1);

			for(int i = 0; i < 8; i++){
				float windSign = mod(i,2) * 2.0 - 1.0;
				vec2 noiseCoord = worldPos.xz + wind * windSign - verticalOffset;
				if (i < 7) noise += texture2D(noisetex, noiseCoord * lacunarity).r * persistance;
				else {
					noise += texture2D(noisetex, noiseCoord * lacunarity * 0.125).r * persistance * 10.0;
					noise = -noise;
					float noisePlus = 1.0 + 0.125 * -noise;
					noisePlus *= noisePlus;
					noisePlus *= noisePlus;
					noise *= noisePlus;
				}

				if (i == 0) noise = -noise;

				weight += persistance;
				lacunarity *= 1.50;
				persistance *= 0.60;
			}
			noise *= mult / weight;
		}
		#ifdef SHADOW_COLOR
			float discardFactor = 0.025; //0.025
			if (noise > discardFactor || noise < -discardFactor) discard;
		#else
			//albedo.rgb = sqrt(albedo.rgb);
			float noiseFactor = 1.1 + noise;
			noiseFactor = pow(noiseFactor, 10.0);
			if (noiseFactor > 1.0 - dither * 0.5) discard;
		#endif
	#else
		discard;
	#endif
}
#endif

//Program//
void main() {
	vec4 light = vec4(0);
	vec4 color = vec4(0);
	if(screentexcoord.x > 0.5 || screentexcoord.y > 0.5) {
		if (matF < 0.1) discard;
		light = texture2D(shadowcolor1, screentexcoord);
		vec3 lightmult = vec3(1.0);
		if (abs(matF - 120) < 0.1 || abs(matF - 320) < 0.1 || abs(matF - 3) < 0.1) {
			lightmult = texture2D(tex, texCoordF).rgb * glcolorF.rgb;
		} else {
			lightmult = vec3(0.5 * texCoordF, heightF);
		}
		float mat1 = matF + 26 - 200 * float(matF > 300);
		color = vec4(lightmult, mat1 / 255.0);

		#ifdef SHADOWS
	}else{
		//Regular shadow stuff
		#if defined WRONG_MIPMAP_FIX
			color.a = texture2DLod(tex, texCoordF.xy, 0.0).a;
		#else
			color.a = texture2D(tex, texCoordF.xy).a;
		#endif

		if (color.a < 0.0001) discard;

		color.rgb *= glcolorF.rgb;

		float premult = float(matF > 119.5 && matF < 120.5);
		float water = float(matF > 2.5 && matF < 3.5);
		float ice = float(matF > 319.5 && matF < 330.5);
		float foliage = 0;//float(mat > 3.95 && mat < 4.05);

		#ifdef NO_FOLIAGE_SHADOWS
			if (foliage > 0.5) discard;
		#endif
		
		#ifdef FOLIAGE_SHADOWCOL
			if (foliage > 0.5) {
				color.a = 0.5;
				color.b = 1.0;
			}
		#endif

		if (water > 0.5) {
			if (isEyeInWater < 0.5) { 
				color = vec4(1.0, 1.0, 1.0, 1.0);
			} else {
				float dither = Bayer64(gl_FragCoord.xy);
				doWaterShadowCaustics(color, dither);
			}
		}
		#ifndef SHADOW_COLOR
			if (premult > 0.5) {
				if (color.a < 0.51) discard;
			}
		#else
			vec3 shadowcol = texture2D(tex, texCoordF).rgb;
			shadowcol = mix(shadowcol, vec3(1), pow(6, -color.a) * (1 - length(shadowcol) * 0.58));
			shadowcol *= 1 - pow(color.a, 6);
			shadowcol = floor(15.9 * shadowcol);
			shadowcol.r /= 32;
			shadowcol.g /= 512;
			shadowcol.b /= 8192;
			color.g = shadowcol.r + shadowcol.g + shadowcol.b;
			shadowcol *= max(1 - pow(abs(2.2 * texture2D(shadowtex0, texCoordF).r - 1.1), 1000.0), 0.0);
		#endif
	#endif
	}

	/*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
	gl_FragData[1] = light;
}
#endif

#ifdef GSH
#if defined SHADOWS && (defined OVERWORLD || defined END || defined SEVEN)
const int maxVerticesOut = 6;
#else
const int maxVerticesOut = 3;
#endif

varying in vec4 shadowPos[3];
varying in vec2 lmCoord[3];
varying in vec2 texCoord[3];
varying in vec4 glcolor[3];
varying in vec3 glnormal[3];
varying in float mat[3];
varying in float height[3];
varying in vec4 position[3];


varying out vec2 screentexcoord;
varying out vec2 lmCoordF;
varying out vec2 texCoordF;
varying out vec4 glcolorF;
varying out vec3 glnormalF;
varying out float matF;
varying out float heightF;
varying out vec4 positionF;


void main() {
	for (int i = 0; i < 3; i++) {
		gl_Position = gl_PositionIn[i];
		screentexcoord = gl_Position.xy * 0.5 + vec2(0.5);
		lmCoordF = lmCoord[i];
		texCoordF = texCoord[i];
		glcolorF = glcolor[i];
		glnormalF = glnormal[i];
		matF = mat[i];
		heightF = height[i];
		positionF = position[i];
		EmitVertex();
	}
	EndPrimitive();

#if defined SHADOWS && (defined OVERWORLD || defined END || defined SEVEN)
	for (int i = 0; i < 3; i++) {
		gl_Position = shadowPos[i];
		gl_Position.xy *= 0.5;
		gl_Position.xy -= vec2(0.5);
		screentexcoord = gl_Position.xy * 0.5 + vec2(0.5);
		lmCoordF = lmCoord[i];
		texCoordF = texCoord[i];
		glcolorF = glcolor[i];
		glnormalF = glnormal[i];
		matF = mat[i];
		heightF = height[i];
		positionF = position[i];
		EmitVertex();
	}
	EndPrimitive();
#endif	
}
#endif

#ifdef VSH
//Local Varyings
varying vec4 position;
varying vec4 shadowPos;
varying vec2 lmCoord;
varying vec2 texCoord;
varying vec4 glcolor;
varying vec3 glnormal;
varying float mat;
varying float height;


//Attributes//
attribute vec2 mc_Entity;
attribute vec3 at_midBlock;
attribute vec2 mc_midTexCoord;

//Uniforms//
#if WORLD_TIME_ANIMATION >= 2
uniform int worldTime;
#else
uniform float frameTimeCounter;
#endif

uniform int blockEntityId;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

#include "/lib/vx/voxelPos.glsl"

//Program//
void main() {
	mat =
		float((mc_Entity.x > 9999.5 && mc_Entity.x < 10203.5 && abs(mc_Entity.x - 10008) > 0.5) || abs(mc_Entity.x - 10225) < 3.5 || abs(mc_Entity.x - 11015.5) < 1.0 || abs(mc_Entity.x - 7978) < 0.1 || abs(mc_Entity.x - 10205.5) < 1.0 || abs(mc_Entity.x - 10208.5) < 1.0 || abs(mc_Entity.x - 10218) < 1.5 || (abs(mc_Entity.x - 10232) < 2.5 && abs(mc_Entity.x - 10231) > 0.5)) + //full blocks
		//2 * float(abs(mc_Entity.x - 55) < 0.1 || abs(mc_Entity.x - 300) < 0.1 || abs(mc_Entity.x - 63) < 0.1 || abs(mc_Entity.x - 12000) < 0.1 || abs(mc_Entity.x - 59) < 0.1 || abs(mc_Entity.x - 10212.5) < 1.0) + //discard
		3 * float(abs(mc_Entity.x - 8) < 0.1) + //water
		4 * float(abs(mc_Entity.x - 31) < 0.1 || abs(mc_Entity.x - 6) < 0.1 || abs(mc_Entity.x - 175) < 0.1 || abs(mc_Entity.x - 176) < 0.1 || abs(mc_Entity.x - 83) < 0.1) + //cross model blocks
		5 * float((mc_Entity.x > 20008.5 && mc_Entity.x < 20011.5) || (mc_Entity.x > 23008.5 && mc_Entity.x < 23011.5) || (mc_Entity.x > 23100.5 && mc_Entity.x < 23103.5) || abs(mc_Entity.x - 11013.5) < 1.0 || abs(mc_Entity.x - 11024.5) < 1.0 || abs(mc_Entity.x - 20212) < 0.5 || abs(mc_Entity.x - 20003) < 0.5 || (mc_Entity.x > 20010.5 && mc_Entity.x < 20118.5) || abs(mc_Entity.x - 20218) < 1.5 || abs(mc_Entity.x - 20201.5) < 1.0 || abs(mc_Entity.x - 20222) < 0.5 || abs(mc_Entity.x - 20228) < 0.5 || abs(mc_Entity.x - 20232.5) < 1.0 || abs(mc_Entity.x - 20199.5) < 1.0) + //block bottom stuff
		6 * float((mc_Entity.x > 23110.5 && mc_Entity.x < 23118.5) || abs(mc_Entity.x - 23051.5) < 1.0 || abs(mc_Entity.x - 23012) < 0.5 || abs(mc_Entity.x - 23003) < 0.5 || abs(mc_Entity.x - 23218) < 1.5 || abs(mc_Entity.x - 23201.5) < 1.0 || abs(mc_Entity.x - 23222) < 0.5 || abs(mc_Entity.x - 23228) < 0.5 || abs(mc_Entity.x - 23232.5) < 1.0 || abs(mc_Entity.x - 23199.5) < 1.0) + //top slabs
		8 * float(abs(mc_Entity.x - 12004) < 0.1) + //top trapdoors
		9 * float(abs(mc_Entity.x - 12005) < 0.1) + //more trapdoors
		10 * float(abs(mc_Entity.x - 12006) < 0.1) + //MOAR trapdoors
		11 * float(abs(mc_Entity.x - 12007) < 0.1) + //EVEN MOAR trapdoors
		12 * float(abs(mc_Entity.x - 12008) < 0.1) + //THE MOST trapdoors
		13 * float(abs(mc_Entity.x - 12009) < 0.1) + //fences
		14 * float(abs(mc_Entity.x - 12010) < 0.1) + //walls
		17 * float(abs(mc_Entity.x - 12011) < 0.1) + //pressure plates
		22 * float(abs(mc_Entity.x - 12013) < 0.1) + //bumbo cactoni
		50 * float(abs(mc_Entity.x - 11021) < 0.1) + //torch
		51 * float(abs(mc_Entity.x - 21012) < 0.1) + //redstone torch
		52 * float(abs(mc_Entity.x - 11022) < 0.1) + //soul torch
		53 * float(abs(mc_Entity.x - 11017) < 0.1) + //lantern
		54 * float(abs(mc_Entity.x - 11018) < 0.1) + //soul lantern
		55 * float(abs(mc_Entity.x - 21024) < 0.1) + //campfire
		56 * float(abs(mc_Entity.x - 21025) < 0.1) + //soul campfire
		60 * float(abs(mc_Entity.x - 11001) < 0.1) + //glowstone
		61 * float(abs(mc_Entity.x - 10) < 0.1) + //lava
		62 * float(abs(mc_Entity.x - 1010) < 0.1) + //fire
		63 * float(abs(mc_Entity.x - 80) < 0.1) + //nether portal
		64 * float(abs(mc_Entity.x - 210) < 0.1) + //soul fire
		65 * float(abs(mc_Entity.x - 11004) < 0.1) + //shroomlight
		66 * float(abs(mc_Entity.x - 11003) < 0.1) + //magma block
		67 * float(abs(mc_Entity.x - 11002) < 0.1) + //sea lantern
		68 * float(abs(mc_Entity.x - 11020) < 0.1) + //lit furni
		69 * float(abs(mc_Entity.x - 11008) < 0.1) + //bacon
		70 * float(abs(mc_Entity.x - 200) < 0.1 || abs(mc_Entity.x - 12014) < 0.1) + //end portals
		71 * float(abs(mc_Entity.x - 12001) < 0.1) + //conduit
		72 * float(abs(mc_Entity.x - 11005) < 0.1) + //redstone lamp
		73 * float(abs(mc_Entity.x - 24023) < 0.1) + //dim respawn anchor
		74 * float(abs(mc_Entity.x - 24024) < 0.1) + //brighter respawn anchor
		75 * float(abs(mc_Entity.x - 24025) < 0.1) + //EVEN brighter respawn anchor
		76 * float(abs(mc_Entity.x - 24026) < 0.1) + //BRIGHTEST respawn anchor
		77 * float(abs(mc_Entity.x - 11007) < 0.1) + //jack o'lantern
		78 * float(abs(mc_Entity.x - 11027) < 0.1) + //sea pickle
		79 * float(abs(mc_Entity.x - 21027) < 0.1) + //sea pickle
		80 * float(abs(mc_Entity.x - 24027) < 0.1) + //sea pickle
		81 * float(abs(mc_Entity.x - 27027) < 0.1) + //sea pickle
		82 * float(abs(mc_Entity.x - 11009) < 0.1) + //end rod
		83 * float(abs(mc_Entity.x - 11023) < 0.1) + //crying obsidian
		84 * float(abs(mc_Entity.x - 11032) < 0.1) + //disturbed redstone ore
		85 * float(abs(mc_Entity.x - 21030) < 0.1) + //magic ore
		86 * float(abs(mc_Entity.x - 11029) < 0.1) + //diamond ore
		87 * float(abs(mc_Entity.x - 21029) < 0.1) + //emerald ore
		88 * float(abs(mc_Entity.x - 11030) < 0.1) + //gold ore
		89 * float(abs(mc_Entity.x - 11033) < 0.1) + //iron ore
		90 * float(abs(mc_Entity.x - 11031) < 0.1) + //peaceful redstone ore
		91 * float(abs(mc_Entity.x - 10207) < 0.1) + //emerald block
		92 * float(abs(mc_Entity.x - 10210) < 0.1) + //redstone block
		93 * float(abs(mc_Entity.x - 10211) < 0.1) + //lapis block

		120 * float(abs(mc_Entity.x - 79) < 0.1 || abs(mc_Entity.x - 12002) < 0.1) + //stained glass, honey, slime
		320 * float(abs(mc_Entity.x - 7979) < 0.1) + //ice
		121 * float(abs(mc_Entity.x - 10008) < 0.1) + //clear glass
		0;
	height = 
		0.0625 * float(abs(mc_Entity.x - 20212) < 0.1) + //carpet
		0.125 * float(abs(mc_Entity.x - 20009) < 0.1 || abs(mc_Entity.x - 11013.5) < 1.0) + //repeater etc
		0.1875 * float(abs(mc_Entity.x - 12003) < 0.1) + //bottom trapdoors
		0.25 * float(abs(mc_Entity.x - 23009) < 0.1) + //two snow layers
		0.375 * float(abs(mc_Entity.x - 23010) < 0.1) + //three snow layers
		0.4375 * float(abs(mc_Entity.x - 11024) < 0.1 || abs(mc_Entity.x - 11025) < 0.1 || abs(mc_Entity.x - 21024) < 0.1 || abs(mc_Entity.x - 21025) < 0.1) + //campfires
		0.5 * float(abs(mc_Entity.x - 23011) < 0.1 || abs(mc_Entity.x - 20218) < 1.5 || (mc_Entity.x > 20002.5 && mc_Entity.x < 20118.5) || abs(mc_Entity.x - 20201.5) < 1.0 || abs(mc_Entity.x - 20222) < 0.5 || abs(mc_Entity.x - 20228) < 0.5 || abs(mc_Entity.x - 20232.5) < 1.0 || abs(mc_Entity.x - 20199.5) < 1.0) + //half
		0.5625 * float(abs(mc_Entity.x - 12018) < 0.1) + //stonecutter
		0.625 * float(abs(mc_Entity.x - 23101) < 0.1) + //five snow layers
		0.75 * float(abs(mc_Entity.x - 23102) < 0.1 || abs(mc_Entity.x - 9881) < 0.1) + //six snow layers
		0.875 * float(abs(mc_Entity.x - 23103) < 0.1) + //seven snow layers
		0.9375 * float(abs(mc_Entity.x - 20007) < 0.1 || abs(mc_Entity.x - 10229) < 0.1) + //grass path, farmland
	0;
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmCoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	glnormal = gl_Normal;
	float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
	position = (shadowModelViewInverse * shadowProjectionInverse * ftransform());
	vec3 vxPos = position.xyz;
	vxPos += cameraPosition - floor(previousCameraPosition);
	vxPos += at_midBlock / 64;
	//if (at_midBlock == vec3(0)) position = vec3(1000.5);
	vec3[2] posNorm = getVoxelPos(vxPos);
	vxPos = posNorm[0];
	if (mat < 79 || mat > 81) {
		vxPos.xz += (at_midBlock.xy * glnormal.z + at_midBlock.zx * glnormal.y + at_midBlock.yz * glnormal.x)/64.0;
	}else{
		vxPos.xz += (at_midBlock.xy * glnormal.z + at_midBlock.zx * glnormal.y + at_midBlock.yz * glnormal.x)/64.0 + vec2(0.28, -0.28);
	}
	if(posNorm[1].y < 0.5 || blockEntityId == 12000 || abs(mat - 2.0) < 0.1) mat = -1;
	gl_Position = vec4((2 * vxPos.xz / shadowMapResolution), 1.0 - (vxPos.y + cameraPosition.y + 0.001 * (glnormal.y + at_midBlock.y *0.002)) / 128, 1.0);
	if (gl_Position.x < 0.0 && gl_Position.y < 0.0) gl_Position = vec4(-0);
	shadowPos = vec4(0);
	#ifdef SHADOWS
	//Regular shadow stuff//
	if (mc_Entity.x == 8) {  //water
		#ifdef WATER_DISPLACEMENT
			position.y += WavingWater(position.xyz);
		#endif
	}
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz += WavingBlocks(position.xyz, istopv);

	#ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
	#endif
	
	shadowPos = shadowProjection * shadowModelView * position;

	float dist = length(shadowPos.xy);
	float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
	
	shadowPos.xy *= 1.0 / distortFactor;
	shadowPos.z = shadowPos.z * 0.2;
	#endif
}
#endif