#if defined END
float WorldCurvature(vec2 pos){
    return dot(pos, pos) / END_CURVATURE_SIZE;
}
#elif defined NETHER
float WorldCurvature(vec2 pos){
    return dot(pos, pos) / NETHER_CURVATURE_SIZE;
}
#else
float WorldCurvature(vec2 pos){
    return dot(pos, pos) / OVERWORLD_CURVATURE_SIZE;
}
#endif