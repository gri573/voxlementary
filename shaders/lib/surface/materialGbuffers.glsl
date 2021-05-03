void GetMaterials(out float materialFormat, out float smoothness, out float metalness, out float f0, out float metalData, 
                  inout float emissive, out float ao, out float scattering, out vec3 normalMap,
                  vec2 newCoord, vec2 dcdx, vec2 dcdy) {
	#ifdef MC_SPECULAR_MAP 
		#if defined WRONG_MIPMAP_FIX
			vec4 specularMap = texture2DLod(specular, newCoord, 0.0);
		#else
			vec4 specularMap = texture2D(specular, newCoord);
		#endif
	#else
		vec4 specularMap = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
	#ifdef NORMAL_MAPPING
		normalMap = texture2DGradARB(normals, newCoord, dcdx, dcdy).xyz;
	#else
		normalMap = texture2D(normals, newCoord).xyz;
	#endif
	
	vec3 normalMapCheck = normalMap;

	if (normalMapCheck == vec3(1.0)) {
		materialFormat = 1.0;
	
		smoothness = specularMap.r;
		
		metalness = specularMap.g;
		f0 = 0.78 * metalness + 0.02;
		metalData = metalness;

		emissive = mix(specularMap.b, 1.0, emissive);
		ao = 1.0;

		ao = specularMap.a < 1.0 ? specularMap.a : 1.0;
		ao = ao > 0.000001 ? (ao < 1.0 ? pow(ao, 8) : 1.0) : 1.0;
		
		normalMap = vec3(0.0, 0.0, 1.0);
	} else {
		materialFormat = 0.0;

		normalMap += vec3(0.5, 0.5, 0.0);
		normalMap = pow(normalMap, vec3(NORMAL_MULTIPLIER));
		normalMap -= vec3(0.5, 0.5, 0.0);
		
		#if MATERIAL_FORMAT == -1
			smoothness = specularMap.r;
			
			metalness = specularMap.g;
			f0 = 0.78 * metalness + 0.02;
			metalData = metalness;

			emissive = mix(specularMap.b, 1.0, emissive);
			ao = 1.0;

			normalMap = normalMap * 2.0 - 1.0;
		#endif

		#if MATERIAL_FORMAT > -1
			smoothness = specularMap.r;

			f0 = specularMap.g;
			metalness = f0 >= 0.9 ? 1.0 : 0.0;
			metalData = f0;
			
			ao = texture2D(normals, newCoord).z;
			ao *= ao;

			scattering = specularMap.b > 0.253 ? (specularMap.b - 0.253) * 1.33 : 0.0;

			emissive = mix(specularMap.a < 1.0 ? specularMap.a : 0.0, 1.0, emissive);
			
			normalMap = normalMap * 2.0 - 1.0;
			float normalCheck = normalMap.x + normalMap.y;
			if (normalCheck > -1.999) {
				if (length(normalMap.xy) > 1.0) normalMap.xy = normalize(normalMap.xy);
				normalMap.z = sqrt(1.0 - dot(normalMap.xy, normalMap.xy));
				normalMap = normalize(clamp(normalMap, vec3(-1.0), vec3(1.0)));
			} else {
				normalMap = vec3(0.0, 0.0, 1.0);
				ao = 1.0;
			}
		#endif
	}	
	#ifdef COMPATIBILITY_MODE
		emissive *= 0.25;
	#endif
	
	emissive *= EMISSIVE_MULTIPLIER;
	
	ao = clamp(ao, 0.01, 1.0);
}