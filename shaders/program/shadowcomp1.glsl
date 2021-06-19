#include "/lib/common.glsl"

//Varyings//
varying vec2 texCoord;

#ifdef FSH
//Uniforms//
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
//Includes//
#include "/lib/vx/voxelPos.glsl"

void main() {
	vec4 col = vec4(0);
	vec3 pos = vec3(0);
	if(texCoord.x > 0.5 || texCoord.y > 0.5) {
	pos = getVoxelPosInverse(texCoord);
	vec4 blockData = texture2D(shadowcolor0, texCoord);
	float ID = floor(blockData.a * 255.0 - 25.5);
	vec3 colMult = texture2D(shadowcolor0, texCoord).rgb;
	colMult /= max(colMult.r, max(colMult.g, colMult.b));
	vec2 pos0 = getVoxelPos(pos + vec3(-1, 0, 0))[0].xz / shadowMapResolution + vec2(0.5);
	vec2 pos1 = getVoxelPos(pos + vec3(0, -1, 0))[0].xz / shadowMapResolution + vec2(0.5);
	vec2 pos2 = getVoxelPos(pos + vec3(0, 0, -1))[0].xz / shadowMapResolution + vec2(0.5);
	vec2 pos3 = getVoxelPos(pos + vec3(1, 0, 0))[0].xz / shadowMapResolution + vec2(0.5);
	vec2 pos4 = getVoxelPos(pos + vec3(0, 1, 0))[0].xz / shadowMapResolution + vec2(0.5);
	vec2 pos5 = getVoxelPos(pos + vec3(0, 0, 1))[0].xz / shadowMapResolution + vec2(0.5);

	vec4 col0 = texture2D(shadowcolor1, pos0) * float(abs(pos0.x - 0.5) < 0.5 && abs(pos0.y - 0.5) < 0.5);
	vec4 col1 = texture2D(shadowcolor1, pos1) * float(abs(pos1.x - 0.5) < 0.5 && abs(pos1.y - 0.5) < 0.5);
	vec4 col2 = texture2D(shadowcolor1, pos2) * float(abs(pos2.x - 0.5) < 0.5 && abs(pos2.y - 0.5) < 0.5);
	vec4 col3 = texture2D(shadowcolor1, pos3) * float(abs(pos3.x - 0.5) < 0.5 && abs(pos3.y - 0.5) < 0.5);
	vec4 col4 = texture2D(shadowcolor1, pos4) * float(abs(pos4.x - 0.5) < 0.5 && abs(pos4.y - 0.5) < 0.5);
	vec4 col5 = texture2D(shadowcolor1, pos5) * float(abs(pos5.x - 0.5) < 0.5 && abs(pos5.y - 0.5) < 0.5);
	vec4 col6 = texture2D(shadowcolor1, texCoord);
	
	col0.rgb *= float(abs(col0.a - 0.75) > 0.1 && ((ID == 5 && abs(col0.a - 0.25) > 0.1) || (ID == 6 && abs(col0.a - 0.5) > 0.1) || abs(ID - 5.5) > 1.0));
	col1.rgb *= float(abs(col1.a - 0.75) > 0.1 && abs(ID - 5) > 0.5 && abs(col1.a - 0.25) > 0.1);
	col2.rgb *= float(abs(col2.a - 0.75) > 0.1 && ((ID == 5 && abs(col2.a - 0.25) > 0.1) || (ID == 6 && abs(col2.a - 0.5) > 0.1) || abs(ID - 5.5) > 1.0));
	col3.rgb *= float(abs(col3.a - 0.75) > 0.1 && ((ID == 5 && abs(col3.a - 0.25) > 0.1) || (ID == 6 && abs(col3.a - 0.5) > 0.1) || abs(ID - 5.5) > 1.0));
	col4.rgb *= float(abs(col4.a - 0.75) > 0.1 && abs(ID - 6) > 0.5 && abs(col4.a - 0.5) > 0.1);
	col5.rgb *= float(abs(col5.a - 0.75) > 0.1 && ((ID == 5 && abs(col5.a - 0.25) > 0.1) || (ID == 6 && abs(col5.a - 0.5) > 0.1) || abs(ID - 5.5) > 1.0));
	col6.rgb *= float(abs(col6.a - 0.75) > 0.1);

	col0.a = max(max(col0.r, max(col0.g, col0.b)), 0.0001);
	col1.a = max(max(col1.r, max(col1.g, col1.b)), 0.0001);
	col2.a = max(max(col2.r, max(col2.g, col2.b)), 0.0001);
	col3.a = max(max(col3.r, max(col3.g, col3.b)), 0.0001);
	col4.a = max(max(col4.r, max(col4.g, col4.b)), 0.0001);
	col5.a = max(max(col5.r, max(col5.g, col5.b)), 0.0001);
	col6.a = max(max(col6.r, max(col6.g, col6.b)), 0.0001);

	col0.rgb /= col0.a;
	col1.rgb /= col1.a;
	col2.rgb /= col2.a;
	col3.rgb /= col3.a;
	col4.rgb /= col4.a;
	col5.rgb /= col5.a;
	col6.rgb /= col6.a;

	col0.a = max(col0.a * BLOCKLIGHT_SPREAD_MULT - BLOCKLIGHT_SPREAD_SUB, 0.0);
	col1.a = max(col1.a * BLOCKLIGHT_SPREAD_MULT - BLOCKLIGHT_SPREAD_SUB, 0.0);
	col2.a = max(col2.a * BLOCKLIGHT_SPREAD_MULT - BLOCKLIGHT_SPREAD_SUB, 0.0);
	col3.a = max(col3.a * BLOCKLIGHT_SPREAD_MULT - BLOCKLIGHT_SPREAD_SUB, 0.0);
	col4.a = max(col4.a * BLOCKLIGHT_SPREAD_MULT - BLOCKLIGHT_SPREAD_SUB, 0.0);
	col5.a = max(col5.a * BLOCKLIGHT_SPREAD_MULT - BLOCKLIGHT_SPREAD_SUB, 0.0);

	float maxAlpha = max(max(col0.a, max(col1.a, col2.a)), max(max(col3.a, col4.a), max(col5.a, col6.a)));
	col = vec4(col0.rgb * max(1 - 5 * (maxAlpha - col0.a), 0.0) + 
					col1.rgb * max(1 - 5 * (maxAlpha - col1.a), 0.0) + 
					col2.rgb * max(1 - 5 * (maxAlpha - col2.a), 0.0) + 
					col3.rgb * max(1 - 5 * (maxAlpha - col3.a), 0.0) + 
					col4.rgb * max(1 - 5 * (maxAlpha - col4.a), 0.0) + 
					col5.rgb * max(1 - 5 * (maxAlpha - col5.a), 0.0) + 
					col6.rgb * 4 * col6.a, 1.0);
	col.rgb /= max(max(0.0001, col.r), max(col.g, col.b));
	col.rgb *= maxAlpha;
	if (abs(ID - 120) < 0.5 || abs(ID - 3) < 0.5) col.rgb *= (TRANSLUCENT_BLOCKLIGHT_TINT * colMult + vec3(1 - TRANSLUCENT_BLOCKLIGHT_TINT));
	//col = texture2D(shadowcolor1, oldtexcoord2);
	col.a = 1.0 - 0.25 * float(ID == 1) - 0.5 * float(ID == 5) - 0.75 * float(ID == 6);
	}
	/*DRAWBUFFERS:1*/
	gl_FragData[0] = max(col, vec4(0));
}
#endif
#ifdef VSH
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif
