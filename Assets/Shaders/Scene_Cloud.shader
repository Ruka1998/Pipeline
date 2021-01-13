Shader "Scene/Cloud"
{
    Properties
    {
        [Tex][NoScaleOffset]_NoiseTex ("噪声贴图", 2D) = "white" { }
        [Color(_, _, _Col2)]_Col1 ("偏色", Color) = (1, 1, 1, 1)
        [HideInInspector]_Col2 ("偏色", Color) = (1, 1, 1, 1)
        
        [Header(Cloud Properties)][Space(20)]
        _TaperPower ("云层形状衰减", Float) = 1
        _CutOff ("云层密度", Range(0, 1)) = 0.5
        _CloudSize ("云层缩放", Range(0, 4)) = 1
        _CloudDir ("云层方向", Range(0, 1)) = 0
        _CloudSpeed ("云层移动速度", Range(0, 4)) = 1
        _CloudMergeSpeed ("云层变形速度", Range(0, 1)) = 1
        
        [Header(Light)][Space(20)]
        _LitOffset ("光照偏移", Float) = 1
        _LitStr ("LitStr", Float) = 1
        _LitBackStr ("LitBackStr", Float) = 1
        _LitEdgeStr ("LitEdgeStr", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        LOD 100
        Cull Front
        Blend SrcAlpha OneMinusSrcAlpha
        
        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ INSTANCING_ON
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
                fixed4 tangent: TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct v2f
            {
                float4 uv: TEXCOORD0;
                float4 pos: SV_POSITION;
                float4 posWorld: TEXCOORD1;
                half4 uvOffset1: TEXCOORD2;
                half4 uvOffset2: TEXCOORD3;
                fixed3 lightDir: TEXCOORD4;
                fixed3 viewDir: TEXCOORD5;
            };
            
            fixed4 _LightColor0;
            
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            fixed4 _Col1;
            fixed4 _Col2;
            
            fixed _CutOff;
            half _CloudSize;
            half _CloudSpeed;
            half _CloudMergeSpeed;
            half _CloudDir;
            half _TaperPower;
            
            half _LitOffset;
            half _LitStr;
            half _LitBackStr;
            half _LitEdgeStr;
            
            //script value -----------------
            half _midYValue;
            half _cloudHeight;
            //------------------------------
            
            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                
                o.pos = UnityObjectToClipPos(v.vertex);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                
                _CloudDir *= 6.28;
                fixed2 dir = fixed2(sin(_CloudDir), cos(_CloudDir));
                o.uv.xy = v.uv * (_CloudSize + 0.13) + dir * _Time.x * _CloudSpeed;
                o.uv.zw = v.uv * _CloudSize + dir * _Time.x * (_CloudSpeed + _CloudMergeSpeed);
                
                o.lightDir = normalize(UnityWorldSpaceLightDir(o.posWorld));
                o.viewDir = normalize(UnityWorldSpaceViewDir(o.posWorld));
                
                fixed3 tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                half4 litOffset = (o.lightDir.xy * tangentWorld.xy * _LitOffset).xyxy;
                
                o.uvOffset1 = o.uv + litOffset;
                o.uvOffset2 = o.uv - litOffset;
                
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {
                fixed noise1 = tex2D(_NoiseTex, i.uv.xy).r;
                fixed noise2 = tex2D(_NoiseTex, i.uv.zw).r;
                fixed noise = noise1 * noise2;
                
                fixed noiseOffset1 = tex2D(_NoiseTex, i.uvOffset1.xy);
                fixed noiseOffset2 = tex2D(_NoiseTex, i.uvOffset1.zw);
                fixed light = saturate(noise1 + noise2 - noiseOffset1 - noiseOffset2) * _LitStr;
                
                fixed noiseOffset3 = tex2D(_NoiseTex, i.uvOffset2.xy);
                fixed noiseOffset4 = tex2D(_NoiseTex, i.uvOffset2.zw);
                fixed lightBack = saturate(noise1 + noise2 - noiseOffset3 - noiseOffset4) * _LitBackStr;
                
                fixed lightEdge = pow((1 - noise), 1) * _LitEdgeStr;
                fixed lightFinal = light + lightBack + lightEdge;
                
                
                half vFalloff = pow(saturate(abs(_midYValue - i.posWorld.y) / (_cloudHeight * 0.25)), _TaperPower);
                clip(noise - _CutOff - vFalloff);
                // return lightFinal;
                
                fixed4 col = lerp(_Col1, _LightColor0, lightFinal);
                col.a = noise*_Col1.a;
                return col;
            }
            ENDCG
            
        }
    }
    CustomEditor "JTRP.ShaderDrawer.LWGUI"
}