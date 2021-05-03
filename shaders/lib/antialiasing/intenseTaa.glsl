/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
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
		float depthCheck = texture2DLod(depthtex1, texCoord + offset, 0.0).r;
		if (abs(GetLinearDepth(depthCheck) - GetLinearDepth(depth)) > 0.03) edge = 1.0;
		vec3 clr = texture2DLod(colortex1, texCoord + offset, 0.0).rgb;
		minclr = min(minclr, clr); maxclr = max(maxclr, clr);
	}

	tempColor = clamp(tempColor, minclr, maxclr);
}

void TAA(inout vec3 color, inout vec4 temp, float depth) {
	vec3 coord = vec3(texCoord, depth);
	vec2 prvCoord = Reprojection(coord);
	
	vec2 view = vec2(viewWidth, viewHeight);
	vec3 tempColor = texture2DLod(colortex2, prvCoord, 0.0).gba;
	if (tempColor == vec3(0.0)) {
		temp = vec4(temp.r, color);
		return;
	}
	float edge = 0.0;
	NeighbourhoodClamping(color, tempColor, 1.0 / view, depth, edge);
	
	vec2 velocity = (texCoord - prvCoord.xy) * view;
	float blendFactor = float(prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
	                          prvCoord.y > 0.0 && prvCoord.y < 1.0);
	blendFactor *= exp(-length(velocity * (2.0 + edge * 100.0))) * 0.3 + 0.6;
	
	color = mix(color, tempColor, blendFactor);
	temp = vec4(temp.r, color);
}