Shader "Custom/RippleFromSDF"
{
    Properties
    {
        _MainTex ("SDF Texture", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {} // 噪声纹理
        _RippleSpeed ("Ripple Speed", Float) = 1.0
        _RippleFrequency ("Ripple Frequency", Float) = 5.0
        _TimeFactor ("Time Factor", Float) = 1.0
        _RippleRange ("Ripple Range", Float) = 0.1
        _RippleFalloff ("Ripple Falloff", Float) = 2.0
        _NoiseStrength ("Noise Strength", Range(0,0.2)) = 0.1 // 噪声强度
        _Toonlevel ("Toon level", Range(0,1)) = 0.2 // 卡通程度
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 200

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
            };

            sampler2D _MainTex;
            sampler2D _NoiseTex; // 噪声纹理
            float4 _NoiseTex_ST;
            float _RippleSpeed;
            float _RippleFrequency;
            float _TimeFactor;
            float _RippleRange;
            float _RippleFalloff;
            float _NoiseStrength;
            float4 _IntersectionCamProperties;

            float _Toonlevel;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
                o.uv = v.uv;
                
                return o;
            }

            float rippleEffect(float distance, float time)
            {
                // Ripple function: sin wave modulated by distance and time
                return sin(distance * _RippleFrequency - time * _RippleSpeed) * 0.5 + 0.5;
            }

            float2 addNoise(float2 uv)
            {
                // 从噪声纹理中获取噪声值
                float noise = tex2D(_NoiseTex, uv * _NoiseTex_ST.xy).r; // 放大 UV 采样范围
                // 噪声扰动
                return uv + (noise - 0.5) * _NoiseStrength;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 intersectionRTUVs = i.worldPos.xz - _IntersectionCamProperties.xz;
                intersectionRTUVs = intersectionRTUVs / (_IntersectionCamProperties.w * 2);
                intersectionRTUVs += 0.5;

                // 加入噪声扰动后的 UV 坐标
                float2 disturbedUV = addNoise(intersectionRTUVs);

                // Get the SDF value (assuming it's in the red channel)
                float sdfValue = tex2D(_MainTex, disturbedUV).r;

                // Calculate time with time factor
                float time = _Time.y * _TimeFactor;

                // 限制波纹只在 SDF 值接近 0 的时候产生
                float distance = abs(sdfValue); // 绝对值表示离边缘的距离
                float ripple = 0.0;

                if (distance < _RippleRange)
                {
                    // 衰减效果，根据距离增加衰减
                    float attenuation = pow(1.0 - distance / _RippleRange, _RippleFalloff);
                    ripple = rippleEffect(distance, time) * attenuation;
                }

                ripple = step(1 - ripple, _Toonlevel);
                
                // Combine ripple effect with the original texture
                return fixed4(ripple, ripple, ripple, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}