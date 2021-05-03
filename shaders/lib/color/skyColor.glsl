#ifndef ONESEVEN
vec3 skyColVanilla = pow(skyColor, vec3(2.2)) * SKY_I * SKY_I;

vec3 sky_ColorSqrt = vec3(SKY_R, SKY_G, SKY_B) * SKY_I / 255.0;

vec3 skyColCustom = sky_ColorSqrt * sky_ColorSqrt;

vec3 skyCol = mix(skyColCustom, skyColVanilla, SKY_V * 0.01);
#else
vec3 skyCol = vec3(0.812, 0.741, 0.674)*0.5;
#endif