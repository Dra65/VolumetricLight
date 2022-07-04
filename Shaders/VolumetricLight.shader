Shader "Unlit/VolumetricLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SecondaryTex("Secondary Texture", 2D) = "white" {}
        [Range(0,1)]_Scattering("Scattering", float) = 0.94
    }
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
        }

        //Volumetric Light Pass
        Pass
        {
            HLSLPROGRAM
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Ray
            {
                float3 origin, direction;
            };

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            sampler2D _SourceTex;

            float3 _BL, _TL, _TR, _BR;

            // Maximum amount of raymarching samples
            #define MAX_STEP_COUNT 32
            #define MAX_DIST 100

            #define DENSITY_MULTIPLIER 1

            float _Scattering;
            float3 _LightDirection;

            float GetDepth(float2 positionNDC)
            {
                #if UNITY_REVERSED_Z
                real depth = SampleSceneDepth(positionNDC);
                depth = depth < 0.0001 ? 0 : depth;
                #else
                // Adjust z to match NDC for OpenGL
                real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(positionNDC));
                depth = depth  > 0.9999 ? 0 : depth;
                #endif

                return depth;
            }

            float GetShadowAttenuation(float3 wpos)
            {
                float4 shadowCoord = TransformWorldToShadowCoord(wpos);
                float shadowMap = MainLightRealtimeShadow(shadowCoord);

                return shadowMap;
            }

            float ComputeScattering(float LdotV)
            {
                float result = 1.0f - _Scattering * _Scattering;
                result /= (4.0f * PI * pow(1.0f + _Scattering * _Scattering - (2.0f * _Scattering) * LdotV,
                                           1.5f));
                return result;
            }

            Ray CreateRay(float3 origin, float3 direction)
            {
                Ray ray;
                ray.origin = origin;
                ray.direction = direction;
                return ray;
            }

            float Raytracing(Ray ray, float LdotV, float depth)
            {
                const float3 rayOrigin = ray.origin;
                const float3 dir = ray.direction;
                const float stepSize = depth > 0 ? depth / MAX_STEP_COUNT : MAX_DIST / MAX_STEP_COUNT;

                float3 samplePosition = rayOrigin;
                float density = 0;
                int j = 0;

                for (; j < MAX_STEP_COUNT; j++)
                {
                    density += ComputeScattering(LdotV) * GetShadowAttenuation(samplePosition);

                    samplePosition += dir * stepSize;
                }

                return saturate(density / j);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 UV = i.vertex.xyz / _ScaledScreenParams.xy;
                float depth = GetDepth(UV);
                
                float3 direction = 0;
                float realDepth = 0;

                if (depth == 0)
                {
                    float3 d0 = lerp(_BL, _TL, i.uv.y);
                    float3 d1 = lerp(_BR, _TR, i.uv.y);
                    direction = lerp(d0, d1, i.uv.x);
                }
                else
                {
                    float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
                    direction = worldPos - _WorldSpaceCameraPos;
                    realDepth = length(direction);
                }

                Ray ray = CreateRay(_WorldSpaceCameraPos, normalize(direction));

                float3 viewDir = ray.direction;
                float density = Raytracing(ray, dot(_LightDirection, viewDir), realDepth) * DENSITY_MULTIPLIER;
                return density;
            }
            ENDHLSL
        }

        //Blur Pass
        //Customized for the Volumetric Light Texture : float4(density, depth,0,0)
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;

            float2 SampleBox(float2 uv, float delta)
            {
                float4 sample = tex2D(_MainTex, uv);
                float4 o = _MainTex_TexelSize.xyxy * float2(-delta, delta).xxyy;
                float s =
                    tex2D(_MainTex, uv + o.xy).x + tex2D(_MainTex, uv + o.zy).x +
                    tex2D(_MainTex, uv + o.xw).x + tex2D(_MainTex, uv + o.zw).x;
                return float2(s * 0.25f, sample.g);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 sample = SampleBox(i.uv, 1);
                return float4(sample.rg, 0, 0);
            }
            ENDHLSL
        }

        //Composite Pass
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            sampler2D _SourceTex;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 col = tex2D(_SourceTex, i.uv).rgb;
                float4 sample = tex2D(_MainTex, i.uv);

                float density = sample.r;

                float4 result = float4(saturate(col + density), 1);

                return result;
            }
            ENDHLSL
        }
    }
}