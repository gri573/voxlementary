/**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**/
vec3 glowstoneColor     = vec3(0.9, 0.5, 0.2);
vec3 sealanternColor    = vec3(0.5, 0.57, 0.78);
vec3 shroomlightColor   = vec3(1.0, 0.3, 0.125);
vec3 jackolanternColor  = vec3(0.9, 0.5, 0.2);
vec3 beaconColor        = vec3(0.33, 0.51, 0.6);
vec3 endrodColor        = vec3(0.53, 0.5, 0.47);
vec3 redstonetorchColor = vec3(1.0, 0.0, 0.0);
vec3 lanternColor       = vec3(0.9, 0.5, 0.2);
vec3 soullanternColor   = vec3(0.0, 0.7, 1.0);
vec3 torchColor         = vec3(0.9, 0.5, 0.2);
vec3 soultorchColor     = vec3(0.0, 0.7, 1.0);
vec3 respawnanchorColor = vec3(0.3, 0.0, 1.0);
vec3 campfireColor      = vec3(0.94, 0.5, 0.2);
vec3 soulcampfireColor  = vec3(0.0, 0.7, 1.0);
vec3 lavabucketColor    = vec3(0.94, 0.5, 0.2);
/**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**/
vec3 heldLightAlbedo1 = vec3(0.0);
vec3 heldLightAlbedo2 = vec3(0.0);
if (heldItemId < 11012.5) {
    if (heldItemId < 11005.5) {
        if (heldItemId == 11001) // Glowstone
            heldLightAlbedo1 = glowstoneColor;
        else if (heldItemId == 11002) // Sea Lantern
            heldLightAlbedo1 = sealanternColor;
        else if (heldItemId == 11004) // Shroomlight
            heldLightAlbedo1 = shroomlightColor;
    } else {
        if (heldItemId == 11007) // Jack o'Lantern
            heldLightAlbedo1 = jackolanternColor;
        else if (heldItemId == 11008) // Beacon
            heldLightAlbedo1 = beaconColor;
        else if (heldItemId == 11009) // End Rod
            heldLightAlbedo1 = endrodColor;
        else if (heldItemId == 11012) // Redstone Torch
            heldLightAlbedo1 = redstonetorchColor;
    }
} else {
    if (heldItemId < 11022.5) {
        if (heldItemId == 11017) // Lantern
            heldLightAlbedo1 = lanternColor;
        else if (heldItemId == 11018) // Soul Lantern
            heldLightAlbedo1 = soullanternColor;
        else if (heldItemId == 11021) // Torch
            heldLightAlbedo1 = torchColor;
        else if (heldItemId == 11022) // Soul Torch
            heldLightAlbedo1 = soultorchColor;
    } else {
        if (heldItemId == 11023) // Crying Obsidian, Respawn Anchor
            heldLightAlbedo1 = respawnanchorColor;
        else if (heldItemId == 11024) // Campfire
            heldLightAlbedo1 = campfireColor;
        else if (heldItemId == 11025) // Soul Campfire
            heldLightAlbedo1 = soulcampfireColor;
        else if (heldItemId == 12001) // Lava Bucket
            heldLightAlbedo1 = lavabucketColor;
    }
}
if (heldItemId2 < 11012.5) {
    if (heldItemId2 < 11005.5) {
        if (heldItemId2 == 11001) // Glowstone
            heldLightAlbedo2 = glowstoneColor;
        else if (heldItemId2 == 11002) // Sea Lantern
            heldLightAlbedo2 = sealanternColor;
        else if (heldItemId2 == 11004) // Shroomlight
            heldLightAlbedo2 = shroomlightColor;
    } else {
        if (heldItemId2 == 11007) // Jack o'Lantern
            heldLightAlbedo2 = jackolanternColor;
        else if (heldItemId2 == 11008) // Beacon
            heldLightAlbedo2 = beaconColor;
        else if (heldItemId2 == 11009) // End Rod
            heldLightAlbedo2 = endrodColor;
        else if (heldItemId2 == 11012) // Redstone Torch
            heldLightAlbedo2 = redstonetorchColor;
    }
} else {
    if (heldItemId2 < 11022.5) {
        if (heldItemId2 == 11017) // Lantern
            heldLightAlbedo2 = lanternColor;
        else if (heldItemId2 == 11018) // Soul Lantern
            heldLightAlbedo2 = soullanternColor;
        else if (heldItemId2 == 11021) // Torch
            heldLightAlbedo2 = torchColor;
        else if (heldItemId2 == 11022) // Soul Torch
            heldLightAlbedo2 = soultorchColor;
    } else {
        if (heldItemId2 == 11023) // Crying Obsidian, Respawn Anchor
            heldLightAlbedo2 = respawnanchorColor;
        else if (heldItemId2 == 11024) // Campfire
            heldLightAlbedo2 = campfireColor;
        else if (heldItemId2 == 11025) // Soul Campfire
            heldLightAlbedo2 = soulcampfireColor;
        else if (heldItemId2 == 12001) // Lava Bucket
            heldLightAlbedo2 = lavabucketColor;
    }
}
/**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**/
vec3 heldLightAlbedo = heldLightAlbedo1 + heldLightAlbedo2;

if (dot(heldLightAlbedo, heldLightAlbedo) > 0.001) {
    heldLightAlbedo /= length(heldLightAlbedo);
    heldLightAlbedo *= BLOCKLIGHT_I * 0.4;
    float mixFactor = finalHandLight * finalHandLight;
    blocklightCol = mix(blocklightCol, heldLightAlbedo, max(mixFactor, 0.0));
}
/**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**//**/