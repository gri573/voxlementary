float offset = 1.0;
float offset2 = 2.0;

vec3 squareBlur = vec3(0.0);
squareBlur += texture2D(colortex0, texCoord.xy + vec2( 0.0,  offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( 0.0, -offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset / viewWidth,   0.0)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset / viewWidth,   0.0)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset / viewWidth,  offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset / viewWidth, -offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset / viewWidth, -offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset / viewWidth,  offset / viewHeight)).rgb;

squareBlur += texture2D(colortex0, texCoord.xy + vec2( 0.0,  offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( 0.0, -offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset2 / viewWidth,   0.0)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset2 / viewWidth,   0.0)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset2 / viewWidth,  offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset2 / viewWidth, -offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset2 / viewWidth, -offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset2 / viewWidth,  offset2 / viewHeight)).rgb;

squareBlur += texture2D(colortex0, texCoord.xy + vec2(  offset / viewWidth,  offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(  offset / viewWidth, -offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset2 / viewWidth,   offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset2 / viewWidth,   offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( offset2 / viewWidth,  -offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2(-offset2 / viewWidth,  -offset / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( -offset / viewWidth, -offset2 / viewHeight)).rgb;
squareBlur += texture2D(colortex0, texCoord.xy + vec2( -offset / viewWidth,  offset2 / viewHeight)).rgb;

color.rgb = mix(color.rgb, squareBlur * 0.0625, min(length(squareBlur), 1.0));