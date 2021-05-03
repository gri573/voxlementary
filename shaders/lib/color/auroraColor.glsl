vec3 auroraUColSqrt = vec3(AURORA_UP_R, AURORA_UP_G, AURORA_UP_B) * AURORA_UP_I / 255.0;
vec3 auroraUCol = auroraUColSqrt * auroraUColSqrt;

vec3 auroraDColSqrt = vec3(AURORA_DOWN_R, AURORA_DOWN_G, AURORA_DOWN_B) * AURORA_DOWN_I / 255.0;
vec3 auroraDCol = auroraDColSqrt * auroraDColSqrt;