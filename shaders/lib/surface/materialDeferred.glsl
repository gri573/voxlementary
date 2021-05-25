void GetMaterials(out float smoothness, out float metalness, out float f0, 
                  out vec3 normal, out vec3 spec, vec2 coord) {
    vec2 specularData = texture2D(colortex3, coord).rg;

	smoothness = specularData.r;

	#ifdef COMPBR
		metalness = specularData.g;
		f0 = 0.78 * metalness + 0.02;
	#else
		#if RP_SUPPORT == 3
			f0 = specularData.g;
			metalness = f0 >= 0.9 ? 1.0 : 0.0;
		#else
			metalness = specularData.g;
			f0 = 0.78 * metalness + 0.02;
		#endif
	#endif

	normal = DecodeNormal(texture2D(colortex6, coord).xy);

	spec = texture2D(colortex1, coord).rgb;
}