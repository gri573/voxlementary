#include "/lib/outline/blackOutlineOffset.glsl"

void BlackOutline(inout vec3 color, sampler2D depth, float wFogMult){
	float ph = 1.0 / 1080.0;
	float pw = ph / aspectRatio;

	float outline = 1.0;
	float z = GetLinearDepth(texture2D(depth, texCoord).r) * far * 2.0;
	float minZ = 1.0, sampleZA = 0.0, sampleZB = 0.0;

	for(int i = 0; i < 12; i++){
		vec2 offset = vec2(pw, ph) * blackOutlineOffsets[i];
		sampleZA = texture2D(depth, texCoord + offset).r;
		sampleZB = texture2D(depth, texCoord - offset).r;
		float sampleZsum = GetLinearDepth(sampleZA) + GetLinearDepth(sampleZB);
		outline *= clamp(1.0 - (z - sampleZsum * far), 0.0, 1.0);
		minZ = min(minZ, min(sampleZA,sampleZB));
	}
	
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord.x, texCoord.y, minZ, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	color = color * outline;

	if (outline < 1.0){
		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);
		float lViewPos = length(viewPos.xyz);
		vec3 worldPos = ToWorld(viewPos.xyz);
		vec3 theFog = startFog(color.rgb, nViewPos, lViewPos, worldPos, vec3(0.0), NdotU);
		color.rgb = mix(theFog, color.rgb, pow(outline, 4));
	}

}

float BlackOutlineMask(sampler2D depth0, sampler2D depth1){
	float ph = 1.0 / 1080.0;
	float pw = ph / aspectRatio;

	float mask = 0.0;
	for(int i = 0; i < 12; i++){
		vec2 offset = vec2(pw, ph) * blackOutlineOffsets[i];
		mask += float(texture2D(depth0, texCoord + offset).r <
		              texture2D(depth1, texCoord + offset).r);
		mask += float(texture2D(depth0, texCoord - offset).r < 
		              texture2D(depth1, texCoord - offset).r);
	}

	return clamp(mask,0.0,1.0);
}