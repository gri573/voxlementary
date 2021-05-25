float GetPuddles(vec2 pos) {
	float noise = texture2D(noisetex, pos).r;
		  noise+= texture2D(noisetex, pos * 0.5).r    *2.0;
		  noise+= texture2D(noisetex, pos * 0.25).r   *4.0;
		  noise+= texture2D(noisetex, pos * 0.125).r  *8.0;

		noise *= REFLECTION_RAIN_COVERAGE * 0.055;
		noise = max((noise-15.5) * 0.8 - 1.2 , 0.0);
		#ifdef RAIN_REF_BIOME_CHECK
			noise *= isRainy;
		#endif
		#ifndef RAIN_REF_FORCED
			float wetnessM = wetness;
		#else
			float wetnessM = 1.0;
		#endif
		noise *= wetnessM;
		noise /= sqrt(noise * noise + 1.0);
		#if REFLECTION_RAIN_COVERAGE == 100
			noise = mix(noise, 1.0, min(sqrt1(wetnessM) * 2.0, 1.0));
		#endif

	noise = clamp((noise - 0.75) * 4.5, 0.0, 1.0);

	return noise;
}