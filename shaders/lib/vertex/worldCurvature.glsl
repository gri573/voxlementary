float WorldCurvature(vec2 pos) {
    #if defined END
        float curvature = dot(pos, pos) / END_CURVATURE_SIZE;
        #if END_CURVATURE_SIZE == 999999
            curvature *= 0.0;
        #endif
    #elif defined NETHER
        float curvature = dot(pos, pos) / NETHER_CURVATURE_SIZE;
        #if NETHER_CURVATURE_SIZE == 999999
            curvature *= 0.0;
        #endif
    #else
        float curvature = dot(pos, pos) / OVERWORLD_CURVATURE_SIZE;
        #if OVERWORLD_CURVATURE_SIZE == 999999
            curvature *= 0.0;
        #endif
    #endif

    return curvature;
}