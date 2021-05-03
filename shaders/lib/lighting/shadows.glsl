uniform sampler2DShadow shadowtex0;

vec2 shadowoffsets[8] = vec2[8](    vec2( 0.0   , 1.0   ),
                                    vec2( 0.7071, 0.7071),
                                    vec2( 1.0   , 0.0   ),
                                    vec2( 0.7071,-0.7071),
                                    vec2( 0.0   ,-1.0   ),
                                    vec2(-0.7071,-0.7071),
                                    vec2(-1.0   , 0.0   ),
                                    vec2(-0.7071, 0.7071));

vec2 offsetDist(float x, float s){
	float n = fract(x * 1.414) * 3.1415;
    return vec2(cos(n), sin(n)) * 1.4 * x / s;
}

float SampleBasicShadow(vec3 shadowPos){
    float shadow0 = shadow2D(shadowtex0, vec3(shadowPos.st, shadowPos.z)).x;

    return shadow0;
}

float SampleFilteredShadow(vec3 shadowPos, float offset){
    float shadow = SampleBasicShadow(vec3(shadowPos.st, shadowPos.z)) * 2.0;

    for(int i = 0; i < 8; i++){
        shadow+= SampleBasicShadow(vec3(offset * 1.2 * shadowoffsets[i] + shadowPos.st, shadowPos.z));
    }

    return shadow * 0.1;
}

float SampleTAAFilteredShadow(vec3 shadowPos, float offset){
    float noise = InterleavedGradientNoise();
    float shadow = 0.0;
    offset = offset * (2.0 - 0.5 * (0.85 + 0.25 * (3072.0 / shadowMapResolution)));
    if (shadowMapResolution < 400.0) offset *= 30.0;

    for(int i = 0; i < 2; i++){
        vec2 offset = offsetDist(noise + i, 2.0) * offset;
        shadow += SampleBasicShadow(vec3(shadowPos.st + offset, shadowPos.z));
        shadow += SampleBasicShadow(vec3(shadowPos.st - offset, shadowPos.z));
    }
    
    return shadow * 0.25;
}

float GetShadow(vec3 shadowPos, float offset){

    #ifdef SHADOW_FILTER
        #if AA > 1
            float shadow = SampleTAAFilteredShadow(shadowPos, offset);
        #else
            float shadow = SampleFilteredShadow(shadowPos, offset);
        #endif
    #else
       float shadow = SampleBasicShadow(shadowPos);
    #endif

    return shadow;
}