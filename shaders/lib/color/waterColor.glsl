vec4 rawWaterColor = vec4(pow(fogColor, vec3(UNDERWATER_R, UNDERWATER_G, UNDERWATER_B)) * UNDERWATER_I * 0.2, 1.0);
vec4 waterColorSqrt = vec4(WATER_R, WATER_G, WATER_B, 255.0) * WATER_I / 255.0;
vec4 waterColor = waterColorSqrt * waterColorSqrt;

const float waterFog = WATER_F;

//#ifndef COMPATIBILITY_MODE
const float waterAlpha = WATER_OPACITY;
//#else
//const float waterAlpha = min(WATER_OPACITY*1.1, 1.0);
//#endif