Shader "Custom/snowshader"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [Normal]_NormalMap("Normal Map",2D) = "bump" {}
        [NoScaleOffset] _AOMap("AO Map", 2D) = "white" {}
        _footprintsMap("foot Map",2D)="white"{}
        _Roungness("roungness",Range(0,1))=0.1

    }

    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.0
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Roungness;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal:NORMAL;
                float4 tangentOS:TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalOS   : TEXCOORD2;   // 物体空间法线
                float4 tangentOS  : TEXCOORD3;   // 物体空间切线（w 是副切线符号）
                noperspective float2 screenUV : TEXCOORD5;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_AOMap);
            SAMPLER(sampler_AOMap);

            float3 LambertBRDF(float3 albedo)
            {
                return albedo / PI;   // 除以 PI 是为了能量守恒
            }

            // 全部加 My_ 前缀
            float My_D_GGX(float NdotH, float roughness)
            {
                float alpha  = roughness * roughness;
                float alpha2 = alpha * alpha;
                float d = (NdotH * NdotH) * (alpha2 - 1.0) + 1.0;
                return alpha2 / (PI * d * d);
            }

            float3 My_FresnelSchlick(float3 F0, float VdotH)
            {
                return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
            }

            float My_G1_SchlickGGX(float NdotX, float roughness)
            {
                float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
                return NdotX / (NdotX * (1.0 - k) + k);
            }

            float My_G_Smith(float NdotV, float NdotL, float roughness)
            {
                return My_G1_SchlickGGX(NdotV, roughness) * My_G1_SchlickGGX(NdotL, roughness);
            }

            float3 My_ComputeF0(float3 albedo, float metallic)
            {
                return lerp(0.04, albedo, metallic);
            }

            float3 My_CookTorrance(float3 N, float3 V, float3 L,
            float3 radiance,
            float3 albedo, float metallic, float roughness)
            {
                float3 H = normalize(V + L);
                float NdotV = max(dot(N, V), 1e-4);
                float NdotL = max(dot(N, L), 0.0);
                float NdotH = max(dot(N, H), 0.0);
                float VdotH = max(dot(V, H), 0.0);

                float3 F0 = lerp(0.04, albedo, metallic);
                float3 F  = My_FresnelSchlick(F0, VdotH);
                float  D  = My_D_GGX(NdotH, roughness);
                float  G  = My_G_Smith(NdotV, NdotL, roughness);

                float3 specular = (F * D * G) / max(4.0 * NdotV * NdotL, 1e-4);
                float3 kd = (1.0 - F) * (1.0 - metallic);
                float3 diffuse = kd * albedo / PI;

                return (diffuse + specular) * radiance * NdotL;
            }

            

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = posInputs.positionCS;
                OUT.positionWS = posInputs.positionWS;     
                OUT.uv = IN.uv;
               
                // 只传递物体空间的 TBN 三个轴，不做世界空间变换
                OUT.normalOS = IN.normal;
                OUT.tangentOS = IN.tangentOS;
                OUT.screenUV=posInputs.positionCS.xy / posInputs.positionCS.w * 0.5 + 0.5;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //法线
                // 1. 归一化物体空间法线和切线（插值后长度可能不是 1）
                float3 normalOS = normalize(IN.normalOS);
                float3 tangentOS = normalize(IN.tangentOS.xyz);

                // 2. 算副切线（物体空间）
                float3 bitangentOS = cross(normalOS, tangentOS) * IN.tangentOS.w;

                // 3. 构建物体空间 TBN 矩阵
                float3x3 TBN_object = float3x3(tangentOS, bitangentOS, normalOS);

                // 4. 采样法线贴图，得到切线空间法线
                half4 normalSample = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv);
                half3 normalTS = UnpackNormal(normalSample);

                // 5. 切线空间 → 物体空间
                float3 normalObject = mul(normalTS, TBN_object);
                normalObject = normalize(normalObject);

                // 6. 物体空间 → 世界空间（法线用逆转置矩阵）
                float3 normalWS = TransformObjectToWorldNormal(normalObject);
                normalWS = normalize(normalWS);
                float4 shadowcoord=TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight=GetMainLight(shadowcoord);
                half shadow=mainLight.shadowAttenuation;
                float3 V=normalize(GetWorldSpaceViewDir(IN.positionWS));
                float3 L=normalize(mainLight.direction);
                float3 radiance=mainLight.color;
                float3 basecolor=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,IN.uv);
                float3 color=My_CookTorrance(normalWS,V,L,radiance,basecolor,0,_Roungness)*shadow;
                //IBL光
                float3 reflectVector = reflect(-V, normalWS);
                float mark=SAMPLE_TEXTURE2D(_AOMap,sampler_AOMap,IN.uv);
                color+=GlossyEnvironmentReflection(reflectVector,IN.positionWS,_Roungness,1.0,IN.screenUV)*mark;
                return float4(color,1.0f);

            }
            ENDHLSL
        }

        Pass
        {
            Name "HeightMap"
            Tags { "LightMode" = "HeightMap" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // 输出高度到R通道
                float height = IN.positionWS.y;
                return float4(height, 0, 0, 1);
            }
            ENDHLSL
        }

    }
}
