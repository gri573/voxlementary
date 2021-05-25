#ifndef COLORED_LIGHT
vec3 blocklightColSqrt = vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B) * BLOCKLIGHT_I / 255.0;
vec3 blocklightCol = blocklightColSqrt * blocklightColSqrt;
#else
vec3 blocklightColSqrt = vec3(0.387, 0.31, 0.247);
vec3 blocklightCol = vec3(0.15, 0.096, 0.061);
#endif