//GGX area light approximation from Horizon Zero Dawn
float GetNoHSquared(float radiusTan, float NoL, float NoV, float VoL) {
    float radiusCos = 1.0 / sqrt(1.0 + radiusTan * radiusTan);
    
    float RoL = 2.0 * NoL * NoV - VoL;
    if (RoL >= radiusCos)
        return 1.0;

    float rOverLengthT = radiusCos * radiusTan / sqrt(1.0 - RoL * RoL);
    float NoTr = rOverLengthT * (NoV - RoL * NoL);
    float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

    float triple = sqrt(clamp(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL, 0.0, 1.0));
    
    float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
    float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
    float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;    
    float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
    float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr + 
                   q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
    float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
    float sinTheta = twoX1 * xDenom;
    float cosTheta = 1.0 - twoX1 * xNum;
    NoTr = cosTheta * NoTr + sinTheta * NoBr;
    VoTr = cosTheta * VoTr + sinTheta * VoBr;
    
    float newNoL = NoL * radiusCos + NoTr;
    float newVoL = VoL * radiusCos + VoTr;
    float NoH = NoV + newNoL;
    float HoH = 2.0 * newVoL + 2.0;
    return clamp(NoH * NoH / HoH, 0.0, 1.0);
}

float SchlickGGX(float NoL, float NoV, float roughness) {
    float k = roughness * 0.5;
        
    float smithL = 0.5 / (NoL * (1.0 - k) + k);
    float smithV = 0.5 / (NoV * (1.0 - k) + k);

    return smithL * smithV;
}

float GGX(vec3 normal, vec3 viewPos, vec3 lightVec, float smoothness, float f0, float sunSize) {
    float roughness = 1.0 - smoothness;
    if (roughness < 0.05) roughness = 0.05;
    float roughnessP = roughness;
    roughness *= roughness; roughness *= roughness;
    
    vec3 halfVec = normalize(lightVec - viewPos);

    float dotLH = clamp(dot(halfVec, lightVec), 0.0, 1.0);
    float dotNL = clamp(dot(normal,  lightVec), 0.0, 1.0);
    float dotNV = dot(normal, -viewPos);
    float dotNH = GetNoHSquared(sunSize, dotNL, dotNV, dot(-viewPos, lightVec));
    
    float denom = dotNH * roughness - dotNH + 1.0;
    float D = roughness / (3.141592653589793 * denom * denom);
    float F = exp2((-5.55473 * dotLH - 6.98316) * dotLH) * (1.0 - f0) + f0;
    float k2 = roughness * 0.5;

    float specular = max(dotNL * dotNL * D * F / (dotLH * dotLH * (1.0 - k2) + k2), 0.0);
    specular = max(specular, 0.0);
    specular = specular / (0.125 * specular + 1.0);

    float schlick = SchlickGGX(dotNL, dotNV, roughness);
    schlick = pow(schlick * 0.5, roughnessP);
    specular *= clamp(schlick, 0.0, 1.25);

    if (sunVisibility == 0.0) specular *= float(moonPhase == 0) * 0.35 + 0.65 - float(moonPhase == 4) * 0.65;
    else specular *= 1.5;

    return specular * (1.0 - isEyeInWater*0.75);
}

float stylisedGGX(vec3 normal, vec3 oldNormal, vec3 nViewPos, vec3 lightVec, float f0) {

    vec3 halfVec = normalize(lightVec - nViewPos);

    float dotLH = clamp(dot(halfVec, lightVec), 0.0, 1.0);
    float dotOldL = clamp(dot(oldNormal,  lightVec), 0.0, 1.0);
    float dotNmOL = clamp(dot(normal - oldNormal,  lightVec), 0.0, 1.0);

    float sunSize = 0.037;
    
    float dotNH = GetNoHSquared(sunSize, dotOldL, dot(oldNormal, -nViewPos), dot(-nViewPos, lightVec));

    dotOldL *= dotOldL;
    
    float roughness = 0.05;
    
    float denom = dotNH * roughness - dotNH + 1.0;
    float D = roughness / (3.141592653589793 * denom * denom);
    float F = exp2((-5.55473 * dotLH - 6.98316) * dotLH) * (1.0 - f0) + f0;
    float k2 = roughness * 0.25;

    float specular = max(dotOldL * D * F / (dotLH * dotLH * (1.0 - k2) + k2), 0.0);
    specular = max(specular, 0.0);
    specular = specular / (0.125 * specular + 1.0);

    dotNmOL *= dotNH * dotNH;
    dotNmOL *= dotNmOL * 350.0 * SUN_MOON_WATER_REF;
    dotNmOL *= dotNmOL;
    dotNmOL = max(dotNmOL * 0.25, sunVisibility * pow2(dotNmOL * dotNmOL));
    specular *= 0.075 + 9.0 * min(dotNmOL * 6.0, 50.0);
    specular *= 0.4 + 1.71 * dotOldL;

    if (sunVisibility == 0.0) {
        specular *= 0.25 * MOON_WATER_REF;
        specular *= float(moonPhase == 0) * 0.35 + 0.65 - float(moonPhase == 4) * 0.65;
    }

    return max(specular * (1.0 - isEyeInWater*0.75), 0.0);
}

vec3 GetMetalCol(float f0) {
    int metalidx = int(f0 * 255.0);

    if (metalidx == 230) return vec3(0.24867, 0.22965, 0.21366);
    if (metalidx == 231) return vec3(0.88140, 0.57256, 0.11450);
    if (metalidx == 232) return vec3(0.81715, 0.82021, 0.83177);
    if (metalidx == 233) return vec3(0.27446, 0.27330, 0.27357);
    if (metalidx == 234) return vec3(0.84430, 0.48677, 0.22164);
    if (metalidx == 235) return vec3(0.36501, 0.35675, 0.37653);
    if (metalidx == 236) return vec3(0.42648, 0.37772, 0.31138);
    if (metalidx == 237) return vec3(0.91830, 0.89219, 0.83662);
    return vec3(1.0);
}

vec3 GetSpecularHighlight(float smoothness, float metalness, float f0, vec3 specularColor,
                          vec3 rawAlbedo, float shadow, vec3 normal, vec3 viewPos) {
    #ifndef SHADOWS
        return vec3(0.0);
    #endif
                              
    if (dot(shadow, shadow) < 0.001) return vec3(0.0);

    #ifdef END
        smoothness *= 0.0;
    #endif

    float specular = GGX(normal, normalize(viewPos), lightVec, smoothness, f0,
                         0.01 * sunVisibility + 0.06);
    specular *= sqrt1inv(rainStrengthS);

    #ifdef SHADOWS
        specular *= shadowFade;
    #endif
    
    specularColor = pow(specularColor, vec3(1.0 - 0.5 * metalness));
	
	#ifdef COMPBR
		specularColor *= pow(rawAlbedo, vec3(metalness * 0.8));
	#else
		#if RP_SUPPORT == 3
            if (metalness > 0.5) {
                if (f0 < 1.0) specularColor *= GetMetalCol(f0);
                else specularColor *= rawAlbedo;
            }
		#else
		    specularColor *= pow(rawAlbedo, vec3(metalness));
		#endif
	#endif

    return specular * specularColor * shadow;
}