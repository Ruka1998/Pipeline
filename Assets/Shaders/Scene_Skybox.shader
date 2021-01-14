Shader "Scene/Skybox"
{
    Properties
    {
        _Exposure ("Exposure", Range(0, 8)) = 1.3
        _SunSize ("Sun Size", Range(0, 1)) = 0.04
        _GroundColor ("Ground", Color) = (.369, .349, .341, 1)
        
        [Main(g1, _, 3)]_Sky ("天空颜色", Float) = 0
        [Color(g1, _, _SkyCol2, _SkyCol3)]_SkyCol ("Sky Color", Color) = (.5, .5, .5, 1)
        [HideInInspector]_SkyCol2 ("Sky Col2", Color) = (.5, .5, .5, 1)
        [HideInInspector]_SkyCol3 ("Sky Col3", Color) = (.5, .5, .5, 1)
        [Sub(g1)]_SkyColBlendTime ("Sky ColGrad", Range(0, 1)) = 0.5
        
        [Main(g2, _, 3)]_Cloud ("云彩", Float) = 0
        [Tex(g2)][NoScaleOffset]_NoiseTex ("噪声贴图", 2D) = "white" { }
        [Color(g2, _, _Col2)][HDR]_Col1 ("偏色", Color) = (1, 1, 1, 1)
        [HideInInspector][HDR]_Col2 ("偏色", Color) = (1, 1, 1, 1)
        [Sub(g2)]_CutOff ("云层密度", Range(0, 1)) = 0.5
        [Sub(g2)]_CloudSize ("云层缩放", Range(0.01, 1)) = 1
        [Sub(g2)]_CloudDir ("云层方向", Range(0, 1)) = 0
        [Sub(g2)]_CloudSpeed ("云层移动速度", Range(0, 4)) = 1
        [Sub(g2)]_CloudMergeSpeed ("云层变形速度", Range(0, 1)) = 1
        
        [Title(g2, Light)]
        [Sub(g2)]_LitOffset ("光照偏移", Float) = 1
        [Sub(g2)]_LitStr ("LitStr", Float) = 1
        [Sub(g2)]_LitBackStr ("LitBackStr", Float) = 1
        [Sub(g2)]_LitEdgeStr ("LitEdgeStr", Float) = 1
        [Sub(g2)]_LitEdgePower ("LitEdgePower", Range(0, 1)) = 1
    }
    
    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
        Cull Off ZWrite Off
        
        Pass
        {
            
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            half _Exposure;     // HDR exposure
            half _SunSize;
            fixed3 _GroundColor;
            
            fixed3 _SkyCol;
            fixed3 _SkyCol2;
            fixed3 _SkyCol3;
            half _SkyColBlendTime;
            
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            fixed4 _Col1;
            fixed4 _Col2;
            
            fixed _CutOff;
            half _CloudSize;
            half _CloudSpeed;
            half _CloudMergeSpeed;
            half _CloudDir;
            
            half _LitOffset;
            half _LitStr;
            half _LitBackStr;
            half _LitEdgeStr;
            half _LitEdgePower;
            
            #define SKY_GROUND_THRESHOLD 0.02
            
            struct appdata_t
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
                fixed4 tangent: TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f
            {
                float4 pos: SV_POSITION;
                half3 rayDir: TEXCOORD0;
                half3 groundColor: TEXCOORD1;
                half3 skyColor: TEXCOORD2;
                half3 sunColor: TEXCOORD3;
                float4 posWorld: TEXCOORD4;
                half4 uvOffset1: TEXCOORD5;
                half4 uvOffset2: TEXCOORD6;
                float4 uv: TEXCOORD7;
            };
            
            v2f vert(appdata_t v)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(v);
                
                OUT.groundColor = _Exposure * _GroundColor;
                fixed3 col1 = lerp(_SkyCol, _SkyCol2, smoothstep(0, _SkyColBlendTime, v.vertex.y));
                fixed3 col2 = lerp(_SkyCol2, _SkyCol3, smoothstep(_SkyColBlendTime, 1, v.vertex.y));
                
                OUT.skyColor = _Exposure * lerp(col1, col2, step(_SkyColBlendTime, v.vertex.y)) ;
                OUT.sunColor = _LightColor0.xyz / clamp(length(_LightColor0.xyz), 0.25, 1);
                
                OUT.pos = UnityObjectToClipPos(v.vertex);
                OUT.posWorld = mul(unity_ObjectToWorld, v.vertex);
                
                _CloudDir *= 6.28;
                fixed2 dir = fixed2(sin(_CloudDir), cos(_CloudDir));
                
                float2 uv = OUT.posWorld.xz / OUT.posWorld.y;
                OUT.uv.xy = uv * (_CloudSize + 0.13) + dir * _Time.x * _CloudSpeed;
                OUT.uv.zw = uv * _CloudSize + dir * _Time.x * (_CloudSpeed + _CloudMergeSpeed);
                
                fixed3 tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(OUT.posWorld));
                OUT.rayDir = half3(-normalize(OUT.posWorld.xyz)); //-eyeRay
                half4 litOffset = (lightDir * tangentWorld.xy * _LitOffset).xyxy;
                OUT.uvOffset1 = OUT.uv + litOffset;
                OUT.uvOffset2 = OUT.uv - litOffset;
                
                return OUT;
            }
            
            // Calculates the sun shape
            half calcSunAttenuation(half3 lightPos, half3 ray)
            {
                half3 delta = lightPos - ray;
                half dist = length(delta);
                half spot = 1.0 - smoothstep(_SunSize - 0.02, _SunSize, dist);
                return spot * spot;
            }
            
            fixed3 calcCloud(float4 uv, float4 uvOffset1, float4 uvOffset2, float atten, fixed3 col)
            {
                fixed noise1 = tex2D(_NoiseTex, uv.xy).r;
                fixed noise2 = tex2D(_NoiseTex, uv.zw).r;
                fixed noise = noise1 * noise2;
                // return noise;
                
                fixed noiseOffset1 = tex2D(_NoiseTex, uvOffset1.xy);
                fixed noiseOffset2 = tex2D(_NoiseTex, uvOffset1.zw);
                fixed light = saturate(noise1 + noise2 - noiseOffset1 - noiseOffset2) * _LitStr;
                
                fixed noiseOffset3 = tex2D(_NoiseTex, uvOffset2.xy);
                fixed noiseOffset4 = tex2D(_NoiseTex, uvOffset2.zw);
                fixed lightBack = saturate(noise1 + noise2 - noiseOffset3 - noiseOffset4) * _LitBackStr;
                
                // fixed lightEdge = pow((1 - noise), _LitEdgePower) * _LitEdgeStr;
                fixed lightFinal = light + lightBack;// + lightEdge;
                fixed3 cloudCol = lerp(_Col1, _Col2, saturate(lightFinal));
                cloudCol = lerp(col, cloudCol, 1-pow(1-atten, _LitEdgeStr));
                return cloudCol;
            }
            
            half4 frag(v2f IN): SV_Target
            {
                half3 ray = IN.rayDir.xyz;
                half y = ray.y / SKY_GROUND_THRESHOLD;
                half3 col = lerp(IN.skyColor, IN.groundColor, saturate(y));
                
                if (y < 0.0)
                {
                    fixed noise1 = tex2D(_NoiseTex, IN.uv.xy).r;
                    fixed noise2 = tex2D(_NoiseTex, IN.uv.zw).r;
                    fixed noise = noise1 * noise2;
                    // return noise;
                    
                    fixed noiseOffset1 = tex2D(_NoiseTex, IN.uvOffset1.xy);
                    fixed noiseOffset2 = tex2D(_NoiseTex, IN.uvOffset1.zw);
                    fixed light = saturate(noise1 + noise2 - noiseOffset1 - noiseOffset2) * _LitStr;
                    
                    fixed noiseOffset3 = tex2D(_NoiseTex, IN.uvOffset2.xy);
                    fixed noiseOffset4 = tex2D(_NoiseTex, IN.uvOffset2.zw);
                    fixed lightBack = saturate(noise1 + noise2 - noiseOffset3 - noiseOffset4) * _LitBackStr;
                    
                    // fixed lightEdge = pow((1 - noise), _LitEdgePower) * _LitEdgeStr;
                    fixed lightFinal = light + lightBack;// + lightEdge;
                    // return lightFinal;
                    
                    fixed3 cloudCol = calcCloud(IN.uv, IN.uvOffset1, IN.uvOffset2, - ray.y, col);
                    fixed3 sunCol = IN.sunColor * calcSunAttenuation(_WorldSpaceLightPos0.xyz, -ray);
                    col += sunCol;
                    // col += cloudCol;
                    col = lerp(col, cloudCol, smoothstep(0, saturate(noise - _CutOff) + _LitEdgePower, saturate(noise - _CutOff)));
                }
                return half4(col, 1);
            }
            ENDCG
            
        }
    }
    Fallback Off
    CustomEditor "JTRP.ShaderDrawer.LWGUI"
}
