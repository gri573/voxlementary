#if MC_VERSION <= 11600
vec3 netherColSqrt = vec3(NETHER_R, NETHER_G, NETHER_B) * 0.25 * NETHER_I / 255.0;
vec3 netherCol = netherColSqrt * netherColSqrt;
#else
vec3 netherCol = fogColor * (1 - length(fogColor / 3.0)) * 0.25 * NETHER_I;
#endif