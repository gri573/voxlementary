if (blockID ==  31 || blockID ==   6 || blockID ==  59 || 
    blockID == 175 || blockID == 176 || blockID ==  83 || 
    blockID == 104 || blockID == 105 || blockID == 11019) // Foliage
    mat = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87), quarterNdotUfactor = 0.0;
    
if (blockID == 18 || blockID == 9600 || blockID == 9100 || blockID == 10231) // Leaves, Vine, Lily Pad, Cave Vines
    #ifdef COMPBR
        specR = 12.065, specG = 0.003,
    #endif
    mat = 2.0;

if (blockID == 10) // Lava
    #ifdef COLORED_LIGHT
        lightVarying = 3.0,
    #endif
    mat = 4.0,
    specB = 0.25, quarterNdotUfactor = 0.0, color.a = 1.0, lmCoord.x = 0.9,
    color.rgb = normalize(color.rgb) * vec3(LAVA_INTENSITY * 1.45);
if (blockID == 1010) // Fire
    #ifdef COLORED_LIGHT
        lightVarying = 3.0,
    #endif
    specB = 0.25, lmCoord.x = 0.98, color.a = 1.0, color.rgb = vec3(FIRE_INTENSITY * 0.67);
if (blockID == 210) // Soul Fire
    #ifdef COLORED_LIGHT
        lightVarying = 2.0,
    #endif
    #ifdef SNOW_MODE
        noSnow = 1.0,
    #endif
    specB = 0.25, lmCoord.x = 0.0, color.a = 1.0, color.rgb = vec3(FIRE_INTENSITY * 0.53);

if (blockID > 12344 && blockID < 12355) // Custom Emissive
	specB = 2.05 * clamp(lmCoord.x * 2 - 1, 0.0, 1.0);
    lmCoord = vec2(0.0);

if (blockID == 300) // No Vanilla AO
    color.a = 1.0;

if (lmCoord.x > 0.99) // Clamp full bright emissives
    lmCoord.x = 0.9;

/*
if (lmCoord.x > 0.85) { // Reduce lightmap
    float lightmapO = max(lmCoord.x - 0.85, 0.0);
    lmCoord.x = 0.85 + lightmapO * 0.75, quarterNdotUfactor = 1.0 - lightmapO * 3.33333;
}
*/

#ifdef COMPBR
    if (blockID < 10218.5) {
        if (blockID < 10115.5) {
            if (blockID < 10052.5) {
                if (blockID < 10008.5) {
                    if (blockID < 10002.5) {
                        if (blockID == 10000) { // Grass Block
                            if (color.b < 0.8) { // Grass Block Grass
                                specR = 8.034, specG = 0.003;
                            } else { // Grass Block Dirt
                                specR = 2.035, specG = 0.003;
                            }
                        }
                        else if (blockID == 10001) // Snowy Grass Block
                            mat = 105.0,
                            specR = 2.035;
                        else if (blockID == 10002) // Sand
                            specR = 80.004, mat = 3.0;
                    } else {
                        if (blockID == 10003) // Stone+, Deepslate+
                            specR = 20.04;
                        else if (blockID == 10007) // Dirt, Coarse Dirt, Podzol, Grass Path, Dirt Path, Farmland Dry
                            specR = 2.035, specG = 0.003;
                        else if (blockID == 10008) // Glass, Glass Pane
                            specR = 0.8, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87), mipmapDisabling = 1.0;
                    }
                } else {
                    if (blockID < 10012.5) {
                        if (blockID == 10009) // Snow, Snow Block
                            specR = 18.037, mat = 3.0;
                        else if (blockID == 10010) // Gravel
                            specR = 32.06;
                        else if (blockID == 10012) // Cobblestone+, Clay
                            specR = 18.037;
                    } else {
                        if (blockID == 10050) // Red Sand
                            specR = 80.115, mat = 3.0;
                        else if (blockID == 10051) // Andesite, Diorite, Granite, Basalt+, Calcite, Tuff, Dripstone+
                            specR = 12.05;
                        else if (blockID == 10052) // Terracottas
                            specR = 2.045, mat = 15000.0, color.rgb = vec3(0.03, 1.0, 0.0);
                    }
                }
            } else {
                if (blockID < 10106.5) {
                    if (blockID < 10102.5) {
                        if (blockID == 10053) // Packed Ice, Blue Ice, Purpur Block+
                            specR = 20.055;

                        else if (blockID == 10101) // Birch Log+
                            specR = 3.055;
                        else if (blockID == 10102) // Oak Log+, Bone Block
                            specR = 8.055;
                    } else {
                        if (blockID == 10103) // Jungle Log+, Acacia Log+
                            specR = 6.055;
                        else if (blockID == 10105) // Spruce Log+, Scaffolding, Cartography Table, Bee Nest, Beehive
                            specR = 6.06;
                        else if (blockID == 10106) // Warped Log+
                            specR = 10.07, mat = 102.0,
                            mipmapDisabling = 1.0;
                    }
                } else {
                    if (blockID < 10111.5) {
                        if (blockID == 10107) // Crimson Log+
                            specR = 10.07, mat = 103.0,
                            mipmapDisabling = 1.0;
                        else if (blockID == 10108) // Dark Oak Log+
                            specR = 2.04;		
                        else if (blockID == 10111) // Birch Planks+, Fletching Table, Loom
                            specR = 20.036;
                    } else {
                        if (blockID == 10112) // Oak Planks+, Jungle Planks+, Bookshelf, Composter
                            specR = 20.055;
                        else if (blockID == 10114) // Acacia Planks+, Barrel, Honeycomb Block
                            specR = 20.075;
                        else if (blockID == 10115) // Spruce Planks+, Smithing Table
                            specR = 20.12;
                    }
                }
            }
        } else {
            if (blockID < 10207.5) {
                if (blockID < 10201.5) {
                    if (blockID < 10118.5) {
                        if (blockID == 10116) // Warped Planks+
                            specR = 12.075;
                        else if (blockID == 10117) // Crimson Planks+, Note Block, Jukebox
                            specR = 12.095;
                        else if (blockID == 10118) // Dark Oak Planks+
                            specR = 20.4;
                    } else {
                        if (blockID == 10198) // Stone Bricks++
                            specR = 20.09;
                        else if (blockID == 10199) // Nether Ores, Gilded Blackstone
                            #ifdef EMISSIVE_NETHER_ORES
                                specB = -10.0,
                            #endif
                            specR = 12.087, mat = 20000.0, color.rgb = vec3(1.0, 0.7, 1.0);
                        else if (blockID == 10200) // Netherrack, Crimson/Warped Nylium, Blackstone++
                            specR = 12.087, mat = 20000.0, color.rgb = vec3(1.0, 0.7, 1.0);
                        else if (blockID == 10201) // Polished Andesite, Polished Diorite, Polished Granite, Melon
                            specR = 6.085;
                    }
                } else {
                    if (blockID < 10205.5) {
                        if (blockID == 10202) // Nether Bricks+
                            specR = 12.375, mat = 20000.0, color.rgb = vec3(0.55, 1.0, 1.0);
                        else if (blockID == 10203 || blockID == 10204) // Iron Block+
                            specR = 6.07, specG = 131.0;
                        else if (blockID == 10205) // Gold Block+
                            specR = 8.1, mat = 30000.0, color.rgb = vec3(1.0, 1.0, 1.0), specG = 1.0;
                    } else {
                        if (blockID == 10206) // Diamond Block
                            specR = 100.007, mat = 201.0;
                        else if (blockID == 10207) // Emerald Block
                            specR = 7.2, mat = 201.0;
                    }
                }
            } else {
                if (blockID < 10212.5) {
                    if (blockID < 10209.5) {
                        if (blockID == 10208) // Netherite Block
                            specR = 12.135, specG = 0.7;
                        else if (blockID == 10209) // Ancient Debris
                            #ifdef GLOWING_DEBRIS
                                specB = 6.0 + min(0.3 * ORE_EMISSION, 0.9), color.a = 1.0,
                            #endif
                            specR = 8.07, specG = 0.7;
                    } else {
                        if (blockID == 10210) // Block of Redstone
                            #ifdef GLOWING_REDSTONE_BLOCK
                                specB = 7.99, mat = 20000.0, color.rgb = vec3(1.1), color.a = 1.0,
                            #endif
                            specR = 8.05, specG = 1.0;
                        else if (blockID == 10211) // Lapis Lazuli Block
                            #ifdef GLOWING_LAPIS_BLOCK
                                specB = 6.99, mat = 20000.0, color.rgb = vec3(1.13), color.a = 1.0,
                            #endif
                            specR = 16.11;
                        else if (blockID == 10212) // Carpets, Wools
                            specR = 2.02, mat = 15000.0, color.rgb = vec3(0.03, 1.0, 0.0), specG = 0.003, lmCoord.x *= 0.96;
                    }
                } else {
                    if (blockID < 10215.5) {
                        if (blockID == 10213) // Obsidian
                            specR = 2.15, specG = 0.6, mat = 109.0;
                        else if (blockID == 10214) // Enchanting Table
                            specR = 2.15, specG = 0.6, mat = 109.0;
                        else if (blockID == 10215) // Chain
                            specR = 0.5, specG = 1.0,
                            lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
                    } else {
                        if (blockID == 10216) // Cauldron, Hopper, Anvils
                            specR = 1.08, specG = 1.0, mat = 111.0,
                            lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
                        else if (blockID == 10217) // Sandstone+
                            specR = 24.029;
                        else if (blockID == 10218) // Red Sandstone+
                            specR = 24.085;
                    }
                }
            }
        }
    } else {
        if (blockID < 11009.5) {
            if (blockID < 10231.5) {
                if (blockID < 10225.5) {
                    if (blockID < 10221.5) {
                        if (blockID == 10219) // Quartz+, Daylight Detector, Dried Kelp Block
                            specR = 16.082;
                        else if (blockID == 10220) // Chorus Plant, Chorus Flower Age 5
                            mat = 112.0, specR = 6.1,
                            mipmapDisabling = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
                        else if (blockID == 10221) // Chorus Flower Age<=4
                            specB = 5.0001, specR = 5.07,
                            mipmapDisabling = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
                    } else {
                        if (blockID == 10222) // End Stone++, Smooth Stone+, Lodestone, TNT, Pumpkin+, Mushroom Blocks, Polished Deepslate+
                            specR = 12.065;
                        else if (blockID == 10224) // Concretes
                            specR = 3.044, mat = 15000.0, color.rgb = vec3(0.03, 1.0, 0.0);
                        else if (blockID == 10225) // Concrete Powders
                            specR = 6.014, mat = 15000.0, color.rgb = vec3(0.01, 1.0, 0.0);
                    }
                } else {
                    if (blockID < 10228.5) {
                        if (blockID == 10226) // Bedrock
                            specR = 16.0675;
                        else if (blockID == 10227) // Hay Block, Target
                            specR = 16.085, specG = 0.003, mat = 20000.0, color.rgb = vec3(1.0, 0.0, 0.0);
                        else if (blockID == 10228) // Bricks+, Furnaces Unlit, Dispenser, Dropper
                            specR = 10.07;
                    } else {
                        if (blockID == 10229) // Farmland Wet
                            mat = 114.0;
                        else if (blockID == 10230) // Crafting Table
                            specR = 24.06;
                        else if (blockID == 10231) // Cave Vines (Hanging Glow Berries)
                            specB = 8.3, mat = 20000.0, color.rgb = vec3(1.2, -5.0, 0.0),
                            mipmapDisabling = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
                    }
                }
            } else {
                if (blockID < 11003.5) {
                    if (blockID < 10234.5) {
                        if (blockID == 10232) // Prismarine+
                            specR = 3.08, specG = 0.75;
                        else if (blockID == 10233) // Dark Prismarine+
                            specR = 3.11, specG = 0.75;
                        else if (blockID == 10234) // Glazed Terracottas
                            specR = 0.5;
                    } else {
                        if (blockID == 11001) // Glowstone
                            #ifdef COLORED_LIGHT
                                lightVarying = 3.0,
                            #endif
                            lmCoord.x = 0.87, specB = 3.075, color.rgb = vec3(0.69, 0.68, 0.65),
                            mipmapDisabling = 1.0;
                        else if (blockID == 11002) // Sea Lantern
                            #ifdef COLORED_LIGHT
                                lightVarying = 4.0,
                            #endif
                            lmCoord.x = 0.93, specB = 9.0055, color.rgb = vec3(0.62, 0.60, 0.657),
                            quarterNdotUfactor = 0.0, mipmapDisabling = 1.0;
                        else if (blockID == 11003) // Magma Block
                            lmCoord = vec2(0.0), specB = 2.05, color.rgb = vec3(0.85, 0.84, 0.7),
                            quarterNdotUfactor = 0.0, mipmapDisabling = 1.0;
                    }
                } else {
                    if (blockID < 11006.5) {
                        if (blockID == 11004) // Shroomlight
                            #ifdef COLORED_LIGHT
                                lightVarying = 1.0,
                            #endif
                            lmCoord.x = 0.93, specB = 16.005, color.rgb = vec3(0.45),
                            quarterNdotUfactor = 0.0;
                        else if (blockID == 11005) // Redstone Lamp Lit
                            #ifdef COLORED_LIGHT
                                lightVarying = 3.0,
                            #endif
                            lmCoord.x = 0.915, specB = 5.099, color.rgb = vec3(0.6), quarterNdotUfactor = 0.0,
                            specG = 0.63, specR = 0.55, mipmapDisabling = 1.0;
                        else if (blockID == 11006) // Redstone Lamp Unlit
                            specG = 0.63, specR = 3.15,	mipmapDisabling = 1.0;
                    } else {
                        if (blockID == 11007) // Jack o'Lantern
                            #ifdef COLORED_LIGHT
                                lightVarying = 3.0,
                            #endif
                            specR = 12.065, lmCoord.x = 0.87, specB = 16.0001, color.rgb = vec3(1.0, 1.0, 1.15), mipmapDisabling = 1.0;
                        else if (blockID == 11008) // Beacon
                            #ifdef COLORED_LIGHT
                                lightVarying = 4.0,
                            #endif
                            mat = 115.0, lmCoord.x = 0.87;
                        else if (blockID == 11009) // End Rod
                            #ifdef COLORED_LIGHT
                                lightVarying = 4.0,
                            #endif
                            specR = 1.0, lmCoord.x = 0.88, mat = 116.0;
                    }
                }
            }
        } else {
            if (blockID < 11021.5) {
                if (blockID < 11015.5) {
                    if (blockID < 11012.5) {
                        if (blockID == 11010) // Dragon Egg, Spawner
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            mat = 106.0;
                        else if (blockID == 11011) // Redstone Wire
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            specB = smoothstep(0.0, 1.0, pow2(length(color.rgb))) * 0.07;
                        else if (blockID == 11012) // Redstone Torch
                            #ifdef COLORED_LIGHT
                                lightVarying = 2.0,
                            #endif
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            mat = 101.0, lmCoord.x = min(lmCoord.x, 0.86), mipmapDisabling = 1.0;
                    } else {
                        if (blockID == 11013) // Redstone Repeater & Comparator Powered
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            mat = 101.0, mipmapDisabling = 1.0;
                        else if (blockID == 11014) // Redstone Repeater & Comparator Unpowered
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            mat = 101.0, mipmapDisabling = 1.0;
                        else if (blockID == 11015) // Observer
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            specR = 10.07, mat = 101.0, specB = 1000.0;
                    }
                } else {
                    if (blockID < 11018.5) {
                        if (blockID == 11016) // Command Blocks
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            mat = 104.0, mipmapDisabling = 1.0;
                        else if (blockID == 11017) // Lantern
                            #ifdef COLORED_LIGHT
                                lightVarying = 3.0,
                            #endif
                            lmCoord.x = 0.87, specB = 3.4, mat = 20000.0, color.rgb = vec3(1.0, 0.0, 0.0),
                            specR = 0.5, specG = 1.0;
                        else if (blockID == 11018) // Soul Lantern
                            #ifdef COLORED_LIGHT
                                lightVarying = 2.0,
                            #endif
                            lmCoord.x = min(lmCoord.x, 0.87), specB = 4.15, mat = 20000.0, color.rgb = vec3(0.0, 1.0, 0.0),
                            specR = 0.5, specG = 1.0;
                    } else {
                        if (blockID == 11019) // Crimson Fungus, Warped Fungus
                            specB = 16.007, mat = 20000.0, color.rgb = vec3(1.0, 0.0, 0.0);
                        else if (blockID == 11020) // Furnaces Lit
                            #ifdef COLORED_LIGHT
                                lightVarying = 3.0,
                            #endif
                            specR = 10.07, mat = 107.0, lmCoord.x = pow(lmCoord.x, 1.5);
                        if (blockID == 11021) // Torch
                            #ifdef COLORED_LIGHT
                                lightVarying = 1.0,
                            #endif
                            lmCoord.x = min(lmCoord.x, 0.86), mat = 108.0, mipmapDisabling = 1.0;
                    }
                }
            } else {
                if (blockID < 11028.5) {
                    if (blockID < 11025.5) {
                        if (blockID == 11022) // Soul Torch
                            #ifdef COLORED_LIGHT
                                lightVarying = 2.0,
                            #endif
                            lmCoord.x = min(lmCoord.x, 0.86), mat = 108.0, mipmapDisabling = 1.0;
                        else if (blockID == 11023) // Crying Obsidian, Respawn Anchor
                            #ifdef COLORED_LIGHT
                                lightVarying = 2.0,
                            #endif
                            specR = 2.15, specG = 0.6, mat = 109.0,
                            specB = 0.75, lmCoord.x = min(lmCoord.x, 0.88), mipmapDisabling = 1.0;
                        else if (blockID == 11024) // Campfire, Powered Lever
                            #ifdef COLORED_LIGHT
                                lightVarying = 3.0,
                            #endif
                            lmCoord.x = min(lmCoord.x, 0.885), mat = 110.0;
                        else if (blockID == 11025) // Soul Campfire
                            #ifdef COLORED_LIGHT
                                lightVarying = 2.0,
                            #endif
                            lmCoord.x = min(lmCoord.x, 0.885), mat = 110.0;
                    } else {
                        if (blockID == 11026) // Jigsaw Block, Structure Block
                            #ifdef SNOW_MODE
                                noSnow = 1.0,
                            #endif
                            specB = 8.004, quarterNdotUfactor = 0.0;
                        else if (blockID == 11027) // Sea Pickle
                            specB = 12.0003, lmCoord.x = min(lmCoord.x, 0.885), mipmapDisabling = 1.0;
                        else if (blockID == 11028) // Empty
                            specR = 0.0;
                    }
                } else {
                    if (blockID < 11032.5) {
                        if (blockID == 11029) // Diamond Ore, Emerald Ore
                            #ifdef EMISSIVE_ORES
                                specB = 0.30, mat = 113.0, mipmapDisabling = 1.0,
                            #endif
                            specR = 20.04;
                        else if (blockID == 11030) // Gold Ore, Lapis Ore
                            #ifdef EMISSIVE_ORES
                                specB = 0.08, mat = 113.0, mipmapDisabling = 1.0,
                            #endif
                            specR = 20.04;
                        else if (blockID == 11031) // Redstone Ore Unlit
                            #ifdef EMISSIVE_ORES
                                specB = 4.27, mat = 113.0, mipmapDisabling = 1.0,
                            #endif
                            specR = 20.04;
                        else if (blockID == 11032) // Redstone Ore Lit
                            #ifdef COLORED_LIGHT
                                lightVarying = 2.0,
                            #endif
                            lmCoord.x *= 0.9,
                            specB = 4.27, mat = 113.0, mipmapDisabling = 1.0,
                            specR = 20.04;
                    } else {
                        if (blockID == 11033) // Iron Ore
                            #ifdef EMISSIVE_ORES
                                specB = 0.05, mat = 113.0, mipmapDisabling = 1.0, specG = 0.07,
                            #endif
                            specR = 20.04;
                        else if (blockID == 11034) // Copper Ore
                            #ifdef EMISSIVE_ORES
                                specB = 0.20, mat = 113.0, mipmapDisabling = 1.0, specG = 0.175,
                            #endif
                            specR = 20.04;
                        else if (blockID == 11050) // Rails
                            mat = 117.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87), mipmapDisabling = 1.0;
                    }
                }
            }
        }
    }

    // Too bright near a light source fix
    if (blockID == 99 || blockID == 10204)
        lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);

    // No shading
    if (blockID == 20091 || blockID == 901 || blockID == 97)
        quarterNdotUfactor = 0.0;

    // Mipmap Fix
    if (blockID == 880 || blockID == 76 || blockID == 98 || blockID == 95)
        mipmapDisabling = 1.0;
#endif

#if !defined COMPBR && defined COLORED_LIGHT
    if (blockID < 11012.5) {
        if (blockID < 11005.5) {
            if (blockID == 11001) // Glowstone
                lightVarying = 3.0;
            else if (blockID == 11002) // Sea Lantern
                lightVarying = 4.0;
            else if (blockID == 11004) // Shroomlight
                lightVarying = 1.0;
            else if (blockID == 11005) // Redstone Lamp Lit
                lightVarying = 3.0;
        } else {
            if (blockID == 11007) // Jack o'Lantern
                lightVarying = 3.0;
            else if (blockID == 11008) // Beacon
                lightVarying = 4.0;
            else if (blockID == 11009) // End Rod
                lightVarying = 4.0;
            else if (blockID == 11012) // Redstone Torch
                lightVarying = 2.0;
        }
    } else {
        if (blockID < 11022.5) {
            if (blockID == 11017) // Lantern
                lightVarying = 3.0;
            else if (blockID == 11018) // Soul Lantern
                lightVarying = 2.0;
            else if (blockID == 11020) // Furnaces Lit
                lightVarying = 3.0;
            else if (blockID == 11021) // Torch
                lightVarying = 1.0;
            else if (blockID == 11022) // Soul Torch
                lightVarying = 2.0;
        } else {
            if (blockID == 11023) // Crying Obsidian, Respawn Anchor
                lightVarying = 2.0;
            else if (blockID == 11024) // Campfire
                lightVarying = 3.0;
            else if (blockID == 11025) // Soul Campfire
                lightVarying = 2.0;
            else if (blockID == 11032) // Redstone Ore Lit
                lightVarying = 2.0;
        }
    }
#endif