//Pixel Shader 2

static const float Detail = 2.0; // 0..10
static const float edgeColorAmount = 2.0; // 1..2

float3 eyepos;
float3 eyevec;
float2 rcpres;
float fov;
float waterlevel;

texture lastshader;
texture depthframe;
texture shadowMap; // Texture for shadow mapping
sampler s0 = sampler_state { texture=<lastshader>; addressu = clamp; addressv = clamp; magfilter = point; minfilter = point; };
sampler s1 = sampler_state { texture=<depthframe>; addressu = clamp; addressv = clamp; magfilter = point; minfilter = point; };
sampler shadowSampler = sampler_state { texture = <shadowMap>; };

static const float BlurWeights[13] =
{
    0.002216,
    0.008764,
    0.026995,
    0.064759,
    0.120985,
    0.176033,
    0.199471,
    0.176033,
    0.120985,
    0.064759,
    0.026995,
    0.008764,
    0.002216,
};

//pixel step vectors
static float2 xdisp = float2( 1.0, 0.0) * rcpres;
static float2 ydisp = float2( 0.0, 1.0) * rcpres;

static const float xylength = sqrt(1 - eyevec.z * eyevec.z);
static const float t   = 2.0 * tan(radians(fov * 0.5));
static const float ty  = t / rcpres.y * rcpres.x;
static const float sky = 1e6;


float3 toView(float2 uv)
{
    float depth = tex2D(s1, uv).r;
    float x = 0; //(uv.x - 0.5) * depth * t;
    float y = (uv.y - 0.5) * depth * ty;
    return float3(x, y, depth);
}

float CalculateShadow(float2 texCoord, float depth)
{
    float shadow = 1.0;
    float shadowBias = 0.005; // Adjust bias as needed
    float4 shadowMapCoords = float4(texCoord, depth, 1.0);
    float visibility = tex2Dproj(shadowSampler, shadowMapCoords).r;
    
    if (depth < visibility + shadowBias)
        shadow = 0.5; // Enhance shadow effect by darkening non-visible areas
    
    return shadow;
}

float4 WaterColorPass(float2 uv : TEXCOORD0) : COLOR0
{
    float4 pixelColor = tex2D(s0, uv);

    // Increase brightness
    pixelColor.rgb *= 1.5;

    // Increase contrast
    pixelColor.rgb = saturate(pixelColor.rgb * 1.5);

    // Remove fog
    pixelColor.rgb = lerp(pixelColor.rgb, float3(1.0, 1.0, 1.0), 0.0);

    // Check if the pixel color represents a star
    bool isStar = pixelColor.r > 0.8 && pixelColor.g > 0.8 && pixelColor.b > 0.8;

    if (isStar) {
        // Add yellow halos around stars
        float3 yellowHaloColor = float3(1.0, 1.0, 0.0); // Yellow color
        float haloStrength = 0.1; // Adjust halo strength as needed
        pixelColor.rgb += yellowHaloColor * haloStrength;
    }

    // Enhance real-time shadows
    float depth = tex2D(s1, uv).r;
    float shadow = CalculateShadow(uv, depth);

    // Apply sharpening effect
    float3 blurredColor = float3(0, 0, 0);
    for (int i = 0; i < 13; i++) {
        float2 offset = float2(xdisp.x * BlurWeights[i], ydisp.y * BlurWeights[i]);
        blurredColor += tex2D(s0, uv + offset).rgb * BlurWeights[i];
    }
    float3 sharpenedColor = pixelColor.rgb * 2.0 - blurredColor;
    pixelColor.rgb = lerp(pixelColor.rgb, sharpenedColor, 0.2);

    // Apply shadow
    pixelColor.rgb *= shadow;

    return pixelColor;
}

technique T0 < string MGEinterface="MGE XE 0"; >
{
    pass { PixelShader = compile ps_3_0 WaterColorPass(); }
}