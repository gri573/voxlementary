/*
Complementary Shaders by EminGT, based on BSL Shaders by Capt Tatsu
*/

#include "/lib/util/reprojection.glsl"

vec2 neighbourhoodOffsets[8] = vec2[8](
							   	   vec2(-1.0, -1.0),
							  	   vec2( 0.0, -1.0),
							  	   vec2( 1.0, -1.0),
							  	   vec2(-1.0,  0.0),
							   	   vec2( 1.0,  0.0),
							  	   vec2(-1.0,  1.0),
							  	   vec2( 0.0,  1.0),
							  	   vec2( 1.0,  1.0)
						  );

void NeighbourhoodClamping(vec3 color, inout vec3 tempColor, vec2 view, float depth, inout float edge) {
	vec3 minclr = color, maxclr = color;

	for(int i = 0; i < 8; i++) {
		vec2 offset = neighbourhoodOffsets[i] * view;
		float depthCheck = texture2D(depthtex1, texCoord + offset).r;
		if (abs(GetLinearDepth(depthCheck) - GetLinearDepth(depth)) > 0.03) edge = 1.0;
		vec3 clr = texture2DLod(colortex1, texCoord + offset, 0.0).rgb;
		minclr = min(minclr, clr); maxclr = max(maxclr, clr);
	}

	tempColor = clamp(tempColor, minclr, maxclr);
}

void TAA(inout vec3 color, inout vec4 temp) {
	float depth = texture2D(depthtex1, texCoord).r;
	float noTAA = texture2D(colortex7, texCoord).r;
	if (depth < 0.56 || noTAA > 0.5) {
		return;
	}
	vec3 coord = vec3(texCoord, depth);
	vec2 prvCoord = Reprojection(coord);
	
	vec2 view = vec2(viewWidth, viewHeight);
	vec3 tempColor = texture2D(colortex2, prvCoord).gba;
	if (tempColor == vec3(0.0)) {
		temp = vec4(temp.r, color);
		return;
	}
	float edge = 0.0;
	NeighbourhoodClamping(color, tempColor, 1.0 / view, depth, edge);
	
	vec2 velocity = (texCoord - prvCoord.xy) * view;
	float blendFactor = float(prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
	                          prvCoord.y > 0.0 && prvCoord.y < 1.0);
	#if AA == 2 || AA == 3
		float blendVariable = 0.5;
		float blendConstant = 0.4;
	#elif AA == 4
		float blendVariable = 0.3;
		float blendConstant = 0.6;
	#endif
	blendFactor *= exp(-length(velocity * (2.0 + edge * 100.0))) * blendVariable + blendConstant;
	
	color = mix(color, tempColor, blendFactor);
	temp = vec4(temp.r, color);
	//if (edge > 0.5) color.rgb = vec3(1.0, 0.0, 1.0);
}