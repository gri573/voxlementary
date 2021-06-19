if (mat > 100.5 && mat < 10000.0) {
    if (mat < 109.5) {
        if (mat < 104.5) {
            if (mat < 102.5) {
                if (material == 101.0) { // Redstone Stuff
                    float comPos = fract(worldPos.y + cameraPosition.y);
                    if (comPos > 0.18) emissive = float((albedo.r > 0.65 && albedo.r > albedo.b * 1.0) || albedo.b > 0.99);
                    else emissive = float(albedo.r > albedo.b * 3.0 && albedo.r > 0.5) * 0.125;
                    emissive *= max(0.65 - 0.3 * dot(albedo.rgb, vec3(1.0, 1.0, 0.0)), 0.0);
                    if (specB > 900.0) { // Observer
                        emissive *= float(albedo.r > albedo.g * 1.5);
                    }
                }
                else if (material == 102.0) { // Warped Stem+
                    #ifdef EMISSIVE_NETHER_STEMS
                        float core = float(albedo.r < 0.1);
                        float edge = float(albedo.b > 0.35 && albedo.b < 0.401 && core == 0.0);
                        emissive = core * 0.195 + 0.035 * edge;
                    #endif
                }
            } else {
                if (material == 103.0) { // Crimson Stem+
                    #ifdef EMISSIVE_NETHER_STEMS
                        emissive = float(albedo.b < 0.16);
                        emissive = min(pow2(lAlbedoP * lAlbedoP) * emissive * 3.0, 0.3);
                    #endif
                }
                else if (material == 104.0) { // Command Blocks
                    vec3 comPos = fract(worldPos.xyz + cameraPosition.xyz);
                    comPos = abs(comPos - vec3(0.5));
                    float comPosM = min(max(comPos.x, comPos.y), min(max(comPos.x, comPos.z), max(comPos.y, comPos.z)));
                    emissive = 0.0;
                    if (comPosM < 0.1875) { // Command Block Center
                        vec3 dif = vec3(albedo.r - albedo.b, albedo.r - albedo.g, albedo.b - albedo.g);
                        dif = abs(dif);
                        emissive = float(max(dif.r, max(dif.g, dif.b)) > 0.1) * 25.0;
                        emissive *= float(albedo.r > 0.44 || albedo.g > 0.29);
                    }
                    smoothness = 0.385;
                    metalness = 1.0;
                }
            }
        } else {
            if (mat < 107.5) {
                if (material == 105.0) { // Snowy Grass Block
                    if (lAlbedoP > 1.0) smoothness = lAlbedoP * lAlbedoP * 0.165;
                    else metalness = 0.003;
                }
                else if (material == 106.0) { // Dragon Egg, Spawner
                    emissive = float(albedo.r + albedo.b > albedo.g * 30.0 && lAlbedoP < 0.6);
                    emissive *= 8.0 + float(lAlbedoP < 0.4) * 100.0;
                    if (albedo.b + albedo.g > albedo.r * 2.0 && lAlbedoP > 0.2) { // Spawner Metal
                        smoothness = 0.385;
                        metalness = 0.8;
                    }
                    if (max(abs(albedo.r - albedo.b), abs(albedo.g - albedo.r)) < 0.01) { // Dragon Egg Subtle Emission
                        emissive = 2.5 * float(lAlbedoP < 0.2);
                    }
                }
                else if (material == 107.0) // Furnaces Lit
                    emissive = 0.75 * float(albedo.r * albedo.r > albedo.b * 4.0 || (albedo.r > 0.9 && (albedo.r > albedo.b || albedo.r > 0.99)));
            } else {
                if (material == 108.0) // Torch, Soul Torch
                    emissive = float(albedo.r > 0.9 || albedo.b > 0.65) * (1.4 - albedo.b * 1.05);
                else if (material == 109.0) { // Obsidian++
                    smoothness = max(smoothness, 0.375);
                    if (specB > 0.5) { // Crying Obsidian, Respawn Anchor
                        emissive = (albedo.b - albedo.r) * albedo.r * 6.0;
                        emissive *= emissive * emissive;
                        emissive = clamp(emissive, 0.05, 1.0);
                        if (lAlbedoP > 1.6 || albedo.r > albedo.b * 1.7) emissive = 1.0;
                    } else {
                        if (lAlbedoP > 0.75) { // Enchanting Table Diamond
                            f0 = smoothness;
                            smoothness = 0.9 - f0 * 0.1;
                            metalness = 0.0;
                        }
                        if (albedo.r > albedo.g + albedo.b) { // Enchanting Table Cloth
                            smoothness = max(smoothness - 0.45, 0.0);
                            metalness = 0.0;
                        }
                    }
                }
            }
        }
    } else {
        if (mat < 113.5) {
            if (mat < 111.5) {
                if (material == 110.0) { // Campfires, Powered Lever
                    if (albedo.g + albedo.b > albedo.r * 2.3 && albedo.g > 0.38 && albedo.g > albedo.b * 0.9) emissive = 0.09;
                    if (albedo.r > albedo.b * 3.0 || albedo.r > 0.8) emissive = 0.65;
                    emissive *= max(1.0 - albedo.b + albedo.r, 0.0);
                    emissive *= lAlbedoP;
                }
                else if (material == 111.0) { // Cauldron, Hopper, Anvils
                    if (color.r < 0.99) { // Cauldron
                        cauldron = 1.0, smoothness = 1.0, metalness = 0.0;
                        skymapMod = lmCoord.y * 0.475 + 0.515;
                        #if defined REFLECTION_RAIN && defined RAIN_REF_BIOME_CHECK
                            noRain = 1.0;
                        #endif
                        #if WATER_TYPE == 0
                            albedo.rgb = waterColor.rgb;
                        #elif WATER_TYPE == 1
                            albedo.rgb = pow(albedo.rgb, vec3(1.3));
                        #else
                            albedo.rgb = vec3(0.4, 0.5, 0.4) * (pow(albedo.rgb, vec3(2.8)) + 4 * waterColor.rgb * pow(albedo.r, 1.8)
                                                        + 16 * waterColor.rgb * pow(albedo.g, 1.8) + 4 * waterColor.rgb * pow(albedo.b, 1.8));
                            albedo.rgb = pow(albedo.rgb * 1.5, vec3(0.5, 0.6, 0.5)) * 0.6;
                            albedo.rgb *= 1 + length(albedo.rgb) * pow(WATER_OPACITY, 32.0) * 2.0;
                        #endif
                        #ifdef NORMAL_MAPPING
                            vec2 cauldronCoord1 = texCoord + fract(frametime * 0.003);
                            float cauldronNoise1 = texture2D(noisetex, cauldronCoord1 * 2.0).r;
                            vec2 cauldronCoord2 = texCoord - fract(frametime * 0.003);
                            float cauldronNoise2 = texture2D(noisetex, cauldronCoord2 * 2.0).r;
                            float waveFactor = 0.0166 + 0.05 * lightmap.y;
                            normalMap.xy += (0.5 * waveFactor) * (cauldronNoise1 * cauldronNoise2 - 0.3);
                            albedo.rgb *= (1.0 - waveFactor * 0.5) + waveFactor * cauldronNoise1 * cauldronNoise2;
                        #endif
                    }
                }
            } else {
                if (material == 112.0) { // Chorus Plant, Chorus Flower Age 5
                    if (albedo.g > 0.55 && albedo.r < albedo.g * 1.1) {
                        emissive = 1.0;
                    }
                }
                else if (material == 113.0) { // Emissive Ores
                    float stoneDif = max(abs(albedo.r - albedo.g), max(abs(albedo.r - albedo.b), abs(albedo.g - albedo.b)));
                    float brightFactor = max(lAlbedoP - 1.5, 0.0);
                    float ore = max(max(stoneDif - 0.175 + specG, 0.0), brightFactor);
                    emissive *= sqrt4(ore) * 0.15 * ORE_EMISSION;
                    metalness = 0.0;
                    if (albedo.r > 0.95 && albedo.b + albedo.g < 1.1 && albedo.b + albedo.g > 0.5 && albedo.g < albedo.b + 0.1)
                        // White pixels of the new Redstone Ore
                        albedo.rgb *= vec3(0.8, 0.2, 0.2);
                }
            }
        } else {
            if (mat < 115.5) {
                if (material == 114.0) { // Wet Farmland
                    if (lAlbedoP > 0.3) smoothness = lAlbedoP * 0.7;
                    else smoothness = lAlbedoP * 2.7;
                    smoothness = min(smoothness, 1.0);
                }
                else if (material == 115.0) { // Beacon
                    vec3 comPos = fract(worldPos.xyz + cameraPosition.xyz);
                    comPos = abs(comPos - vec3(0.5));
                    float comPosM = max(max(comPos.x, comPos.y), comPos.z);
                    if (comPosM < 0.4 && albedo.b > 0.5) { // Beacon Core
                        albedo.rgb = vec3(0.625, 1.0, 0.975);
                        emissive = 1.9;
                    }
                }
            } else {
                if (material == 116.0) { // End Rod
                    if (lAlbedoP > 1.3) {
                        smoothness = 0.0;
                        emissive = 0.45;
                    }
                }
                else if (material == 117.0) { // Rails
                    if (albedo.r > albedo.g * 2.0 + albedo.b) {
                        if (lAlbedoP > 0.45) { // Rail Redstone Lit
                            emissive = lAlbedoP;
                        } else { // Rail Redstone Unlit
                            smoothness = 0.4;
                            metalness = 1.0;
                        }
                    } else {
                        if (albedo.r > albedo.g + albedo.b || abs(albedo.r - albedo.b) < 0.1) { // Rail Gold, Rail Iron
                            smoothness = 0.4;
                            metalness = 1.0;
                        }
                    }
                }
            }
        }
    }
}

#ifdef EMISSIVE_NETHER_ORES
    if (specB < -9.0) {
        emissive = float(albedo.r + albedo.g > albedo.b * 2.0 && albedo.g > albedo.b * (1.2 - albedo.g * 0.5));
        if (abs(albedo.g - albedo.b) < 0.1) emissive *= float(albedo.b > 0.35 || albedo.b < 0.05); // Eliminate Some Pixels On Quartz Ore
        emissive *= albedo.r * 0.05 * ORE_EMISSION;
        if (emissive > 0.01) // Desaturate Some Red-Looking Pixels
        albedo.rgb = mix(albedo.rgb, vec3(dot(albedo.rgb, vec3(0.4, 0.5, 0.07))), clamp((albedo.r - albedo.g) * 2.0, 0.0, 0.3));

        /*
        if ((albedo.r + albedo.b + albedo.g > 2.8 && albedo.r > albedo.g && albedo.r > albedo.b && albedo.g > albedo.b)
            || (albedo.r > 0.63 && albedo.g + 0.01 > albedo.b && albedo.g < albedo.b + 0.1 && (albedo.g == albedo.b || albedo.r * 1.6 > albedo.g + albedo.b) && albedo.g + albedo.b > 0.85)) {
            emissive *= 0.0;
            //albedo.rgb = vec3(1.0, 0.0, 1.0);
        }
        */
    }
#endif