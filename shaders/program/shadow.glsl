#include "/lib/common.glsl"

//Varyings//
varying vec2 lmcoord;
varying vec2 texcoord;
varying vec2 screentexcoord;
varying vec4 glcolor;
varying vec3 glnormal;
varying float entityMat;
varying float mat;
varying float height;

#ifdef FSH
//Uniforms//
uniform ivec2 atlasSize;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowcolor1;

//Optifine Constants//
const float shadowDistanceRenderMul = 1.0;

//Other Random Things//
vec2[4] offsets = vec2[4](
	vec2(-1, -1),
	vec2(-1, 1),
	vec2(1, -1),
	vec2(1, 1)
);

//Program//
void main() {
	if (mat < 0.1) discard;
	vec4 light = texture2D(shadowcolor1, screentexcoord);
	vec3 lightmult = vec3(1.0);
	if (abs(mat - 120) < 0.1 || abs(mat - 3) < 0.1) {
		lightmult = texture2D(texture, texcoord).rgb * glcolor.rgb;
	} else {
		lightmult = vec3(0.5 * texcoord, height);
	}
	float mat1 = mat + 26;
	vec4 color = vec4(lightmult, mat1 / 255.0);
	/*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
	gl_FragData[1] = light;
}
#endif
#ifdef VSH
//Attributes//
attribute vec2 mc_Entity;
attribute vec3 at_midBlock;
attribute vec2 mc_midTexCoord;

//Uniforms//
uniform int blockEntityId;
uniform vec3 cameraPosition, previousCameraPosition;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;
//Includes//
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

		120 * float(abs(mc_Entity.x - 79) < 0.1 || abs(mc_Entity.x - 12002) < 0.1 || abs(mc_Entity.x - 7979) < 0.1) + //stained glass, honey, slime
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
	entityMat = 0;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	texcoord = mc_midTexCoord;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	glnormal = gl_Normal;
	float vxDist = shadowMapResolution * 0.0625 / VXHEIGHT;
	vec3 position = (shadowModelViewInverse * shadowProjectionInverse * ftransform()).xyz;
	position += cameraPosition - floor(previousCameraPosition);
	position += at_midBlock / 64;
	//if (at_midBlock == vec3(0)) position = vec3(1000.5);
	vec3[2] posNorm = getVoxelPos(position);
	position = posNorm[0];
	if (mat < 79 || mat > 81) {
		position.xz += (at_midBlock.xy * glnormal.z + at_midBlock.zx * glnormal.y + at_midBlock.yz * glnormal.x)/64.0;
	}else{
		position.xz += (at_midBlock.xy * glnormal.z + at_midBlock.zx * glnormal.y + at_midBlock.yz * glnormal.x)/64.0 + vec2(0.28, -0.28);
	}
	if(posNorm[1].y < 0.5 || blockEntityId == 12000 || abs(mat - 2.0) < 0.1) mat = -1;
	gl_Position = vec4((2 * position.xz / shadowMapResolution), 1.0 - (position.y + cameraPosition.y + 0.001 * (glnormal.y + at_midBlock.y *0.002)) / 128, 1.0);
	screentexcoord = gl_Position.xy * 0.5 + vec2(0.5);
}
#endif