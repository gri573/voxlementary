float fovmult = gbufferProjection[1][1] / 1.37373871;

float BaseLens(vec2 lightPos, float size, float dist, float hardness){
	vec2 lensCoord = (texCoord + (lightPos * dist - 0.5)) * vec2(aspectRatio,1.0);
	float lens = clamp(1.0 - length(lensCoord) / (size * fovmult), 0.0, 1.0 / hardness) * hardness;
	lens *= lens; lens *= lens;
	return lens;
}

float OverlapLens(vec2 lightPos, float size, float dista, float distb){
	return BaseLens(lightPos, size, dista, 2.0) * BaseLens(lightPos, size, distb, 2.0);
}

float PointLens(vec2 lightPos, float size, float dist){
	return BaseLens(lightPos, size, dist, 1.5) + BaseLens(lightPos, size * 4.0, dist, 1.0) * 0.5;
}

float RingLensTransform(float lensFlare){
	return pow(1.0 - pow(1.0 - pow(lensFlare, 0.25), 10.0), 5.0);
}
float RingLens(vec2 lightPos, float size, float distA, float distB){
	float lensFlare1 = RingLensTransform(BaseLens(lightPos, size, distA, 1.0));
	float lensFlare2 = RingLensTransform(BaseLens(lightPos, size, distB, 1.0));
	
	float lensFlare = clamp(lensFlare2 - lensFlare1, 0.0, 1.0);
	lensFlare *= sqrt(lensFlare);
	return lensFlare;
}

float AnamorphicLens(vec2 lightPos){
	vec2 lensCoord = abs(texCoord - lightPos.xy - 0.5) * vec2(aspectRatio * 0.1, 2.0);
	float lens = clamp(1.0 - length(pow(lensCoord, vec2(0.85))) * 4.0 / fovmult, 0.0, 1.0);
	lens *= lens * lens;
	return lens;
}

vec3 AddLens(float lens, vec3 color, float truePos){
	float isMoon = truePos * 0.5 + 0.5;

	vec3 lensColor = mix(color, GetLuminance(color) * lightNight * 0.25, isMoon * 0.98);
	float visibility = mix(sunVisibility, 1.0 - sunVisibility, isMoon);
	visibility *= visibility;
	visibility *= visibility;
	return lens * lensColor * visibility;
}

float getLensVisibilityA(vec2 lightPos){
	float str = length(lightPos * vec2(aspectRatio, 1.0));
	return pow(clamp(str * 8.0, 0.0, 1.0), 2.0) - clamp(str * 3.0 - 1.5, 0.0, 1.0);
}

float getLensVisibilityB(vec2 lightPos){
	float str = length(lightPos * vec2(aspectRatio, 1.0));
	return (1.0 - clamp(str * 3.0 - 1.5, 0.0, 1.0));
}

void LensFlare(inout vec3 color, vec2 lightPos, float truePos, float multiplier){
	float visibilityA = getLensVisibilityA(lightPos);
	float visibilityB = getLensVisibilityB(lightPos);
	multiplier *= multiplier;

	if (visibilityB > 0.001){
		vec3 lensFlare = (
		AddLens(BaseLens(lightPos, 0.3, -0.45, 1.0), vec3(2.2, 1.2, 0.1), truePos) * 0.07 +
		AddLens(BaseLens(lightPos, 0.3,  0.10, 1.0), vec3(2.2, 0.4, 0.1), truePos) * 0.03 +
		AddLens(BaseLens(lightPos, 0.3,  0.30, 1.0), vec3(2.2, 0.2, 0.1), truePos) * 0.04 +
		AddLens(BaseLens(lightPos, 0.3,  0.50, 1.0), vec3(2.2, 0.4, 2.5), truePos) * 0.05 +
		AddLens(BaseLens(lightPos, 0.3,  0.70, 1.0), vec3(1.8, 0.4, 2.5), truePos) * 0.06 +
		AddLens(BaseLens(lightPos, 0.3,  0.90, 1.0), vec3(0.1, 0.2, 2.5), truePos) * 0.07 +
		
		AddLens(OverlapLens(lightPos, 0.08, -0.28, -0.39), vec3(2.5, 1.2, 0.1), truePos) * 0.015 +
		AddLens(OverlapLens(lightPos, 0.08, -0.20, -0.31), vec3(2.5, 0.5, 0.1), truePos) * 0.010 +
		AddLens(OverlapLens(lightPos, 0.12,  0.06,  0.19), vec3(2.5, 0.2, 0.1), truePos) * 0.020 +
		AddLens(OverlapLens(lightPos, 0.12,  0.15,  0.28), vec3(1.8, 0.1, 1.2), truePos) * 0.015 +
		AddLens(OverlapLens(lightPos, 0.12,  0.24,  0.37), vec3(1.0, 0.1, 2.5), truePos) * 0.010 +
			
		AddLens(PointLens(lightPos, 0.03, -0.55), vec3(2.5, 1.6, 0.0), truePos) * 0.20 +
		AddLens(PointLens(lightPos, 0.02, -0.40), vec3(2.5, 1.0, 0.0), truePos) * 0.15 +
		AddLens(PointLens(lightPos, 0.04,  0.43), vec3(2.5, 0.6, 0.6), truePos) * 0.20 +
		AddLens(PointLens(lightPos, 0.02,  0.60), vec3(0.2, 0.6, 2.5), truePos) * 0.15 +
		AddLens(PointLens(lightPos, 0.03,  0.67), vec3(0.7, 1.1, 3.0), truePos) * 0.25 +
			
		AddLens(RingLens(lightPos, 0.22, 0.44, 0.46), vec3(0.10, 0.35, 2.50), truePos) +
		AddLens(RingLens(lightPos, 0.15, 0.98, 0.99), vec3(0.15, 0.40, 2.55), truePos) * 2.5
		) * visibilityA + (
		AddLens(AnamorphicLens(lightPos), vec3(0.3,0.7,1.0), truePos) * 0.5
		) * visibilityB;
	
		color = mix(color, vec3(1.0), lensFlare * multiplier);
	}
}