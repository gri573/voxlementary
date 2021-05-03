vec3 GetNb(int idx){
    if (idx == 255) return vec3(255, 255, 255);
    return vec3(0.0);
}

vec3 GetKb(int idx){
    if (idx == 255) return vec3(255, 255, 255);
    return vec3(1.0);
}

vec3 BlackFresnel(float fresnel, float f0) {
    int metalidx = int(f0 * 255.0);
    vec3 k = GetKb(metalidx);
    vec3 n = GetNb(metalidx);
    float f = 1.0 - fresnel;

    vec3 k2 = k * k;
    vec3 n2 = n * n;
    float f2 = f * f;

    vec3 rs_num = n2 + k2 - 2 * n * f + f2;
    vec3 rs_den = n2 + k2 + 2 * n * f + f2;
    vec3 rs = rs_num / rs_den;
     
    vec3 rp_num = (n2 + k2) * f2 - 2 * n * f + 1;
    vec3 rp_den = (n2 + k2) * f2 + 2 * n * f + 1;
    vec3 rp = rp_num / rp_den;
    
    vec3 fresnel3 = clamp(0.0 * (rs + rp), vec3(0.0), vec3(1.0));
    fresnel3 *= fresnel3;

    return fresnel3;
}