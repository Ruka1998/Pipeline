Shader "Scene/Uber"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
        _CutOff ("CutOff", Range(0, 1)) = 0.5
        [Tex(_, _MainCol)]_MainTex ("主贴图", 2D) = "white" { }
        [HideInInspector][HDR]_MainCol ("偏色", Color) = (1, 1, 1, 1)
        [Tex][NoScaleOffset]_NormTex ("功能图(法线rg)(粗糙度b)(自发光a)", 2D) = "gray" { }

        [Main(g1)]_SecLayer ("第二层", Float) = 0
        [Tex(g1, _SecCol)]_SecTex ("第二层贴图", 2D) = "white" { }
        [HideInInspector][HDR]_SecCol ("偏色", Color) = (1, 1, 1, 1)
        
        [Tex(g1,_SecNormStr)][NoScaleOffset]_SecNormTex ("功能图", 2D) = "gray" { }
        [HideInInspector]_SecNormStr ("法线强度", Range(0, 3)) = 1
        
        [Title(g1, Normal Based Gradient)]
        [SubToggle(g1)]_NormGrad("法线遮罩开关",Float) = 0
        [Sub(g1)]_NormGradRange ("法线遮罩大小", Float) = 0.5
        [Sub(g1)]_NormGradFeather ("法线遮罩羽化", Float) = 0
        
        [Title(g1, Height Based Gradient)]
        [SubToggle(g1)]_MaskGrad("自定义遮罩开关",Float) = 0
        [Tex(g1)]_MaskTex ("自定义遮罩", 2D) = "white" { }
        [Sub(g1)]_MaskRange ("遮罩大小", Range(0, 0.999)) = 0
        [Sub(g1)]_MaskFeather ("遮罩羽化", Range(0, 1)) = 1
        [Sub(g1)]_MaskGradHeight ("遮罩渐变高度", Float) = 0
        [Sub(g1)]_MaskGradFeather ("遮罩渐变羽化", Float) = 0
        
        [Main(g2)]_GradLayer ("基于高度的渐变颜色", Float) = 0
        [Sub(g2)]_GradCol ("渐变颜色", Color) = (1, 1, 1, 1)
        [Sub(g2)]_GradColHeight ("渐变高度", Float) = 1
        [Sub(g2)]_GradColFeather ("渐变羽化", Float) = 0.5
        
        [Main(g3)]_DLayer ("细节法线开关", Float) = 0
        [Tex(g3, _DNormStr)][NoScaleOffset]_DNormTex ("细节法线", 2D) = "gray" { }
        [HideInInspector]_DNormStr ("细节法线强度", Range(0, 3)) = 1
        [Sub(g3)]_DNormTilling ("Tilling", float) = 1
        
        [Main(g4)]_EmisLayer ("自发光开关", Float) = 0
        [Sub(g4)][HDR]_EmisCol ("自发光颜色", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
        LOD 100
        Cull [_Cull]
        
        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            // #define UNITY_PASS_FORWARDBASE
            #pragma multi_compile_fwdbase nodynlightmap nodirlightmap
            #pragma skip_variants LIGHTPROBE_SH
            #pragma skip_variants VERTEXLIGHT_ON
            // #include "UnityStandardUtils.cginc"
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "SelfCG.cginc"
            // #pragma multi_compile __ _HS_ALPHATEST_ON
            // #pragma multi_compile __ _SHADER_LOD_DEBUG_DISPLAY
            
            // #pragma shader_feature _TOPLAYER_ON
            // #pragma shader_feature _DETAILLAYER_ON
            
            struct appdata
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
                float2 uvLM: TEXCOORD1;
                half3 normal: NORMAL;
                half4 tangent: TANGENT;
            };
            
            struct v2f
            {
                float4 uv: TEXCOORD0;
                float4 uvLM: TEXCOORD1; //在zw放了一个没有缩放的uv
                float4 pos: SV_POSITION;
                half4 normal: TEXCOORD2; //在w放了一个objectPos的y
                float4 posWorld: TEXCOORD3;
                LIGHTING_COORDS(4, 5)
                half3 tspace0: TEXCOORD6;
                half3 tspace1: TEXCOORD7;
                half3 tspace2: TEXCOORD8;
                #ifndef LIGHTMAP_ON
                    half4 vertexGI: TEXCOORD9;
                #endif
            };
            
            fixed4 _LightColor0;
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormTex;
            fixed4 _MainCol;
            fixed _GradLayer;
            fixed _EmisLayer;
            fixed4 _EmisCol;
            half _CutOff;
            
            fixed4 _GradCol;
            half _GradColHeight;
            half _GradColFeather;
            
            fixed _SecLayer;
            sampler2D _SecTex;
            float4 _SecTex_ST;
            fixed4 _SecCol;
            sampler2D _SecNormTex;
            half _SecNormStr;
            fixed _NormGrad;
            half _NormGradRange;
            half _NormGradFeather;
            fixed _MaskGrad;
            sampler2D _MaskTex;
            float4 _MaskTex_ST;
            half _MaskGradHeight;
            half _MaskGradFeather;
            half _MaskRange;
            half _MaskFeather;
            
            fixed _DLayer;
            sampler2D _DNormTex;
            half _DNormTilling;
            half _DNormStr;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _SecTex);
                o.uvLM.xy = v.uvLM * unity_LightmapST.xy + unity_LightmapST.zw;
                o.uvLM.zw = TRANSFORM_TEX(v.uv, _MaskTex);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                
                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
                
                // #ifndef LIGHTMAP_ON
                // #ifdef UNITY_SHOULD_SAMPLE_SH
                // #ifdef VERTEXLIGHT_ON
                //     o.vertexGI.a = 10.0;
                // #endif
                //     o.vertexGI.rgb = ShadeSH9(half4(wNormal, 1.0));
                // #endif
                // #endif
                
                o.normal = float4(wNormal, v.vertex.y);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }
            
            fixed4 frag(v2f i): SV_Target
            {
                //diffuse map
                fixed4 albedo = tex2D(_MainTex, i.uv.xy) * _MainCol;
                clip(albedo.a - _CutOff);
                //gradientStr
                //normal/roughness map
                half4 nomBaseData = tex2D(_NormTex, i.uv.xy);
                half roughness = nomBaseData.b;
                half3 nomBase = SelfUnpackNormal(nomBaseData);
                
                //detail map
                #if _DLayer
                
                    half3 nomDetail = SelfUnpackNormal(tex2D(_DNormTex, i.uv.xy * _DNormTilling));
                    nomBase.xy += nomDetail.xy * _DNormStr;
                #endif

                half3 nomWorld;
                //mask
                if (_SecLayer)
                {
                    half blendFactor = 1;
                    if(_NormGrad){
                        nomWorld.x = dot(i.tspace0, nomBase);
                        nomWorld.y = dot(i.tspace1, nomBase);
                        nomWorld.z = dot(i.tspace2, nomBase);
                        nomWorld = normalize(nomWorld);
                        nomWorld.y = nomWorld.y * 0.5 + 0.5;
                        blendFactor = smoothstep(1-_NormGradRange, 1-_NormGradRange-_NormGradFeather, nomWorld.y);
                    }
                    if(_MaskGrad){
                        //mask map
                        fixed maskTex = tex2D(_MaskTex, i.uvLM.zw).r;
                        maskTex = saturate(max(0, maskTex - _MaskRange) / min(_MaskFeather, 1 - _MaskRange));
                        float maskGradientStr = smoothstep(_MaskGradHeight, _MaskGradHeight + _MaskGradFeather, i.normal.w);
                        blendFactor *= 1 - (1 - maskTex) * (1 - maskGradientStr);
                    }
                    //diffuse blend
                    albedo = albedo * blendFactor + tex2D(_SecTex, i.uv.zw) * _SecCol * (1 - blendFactor);
                    //topLayer normal/roughness map
                    half4 nomTopData = tex2D(_SecNormTex, i.uv.zw);
                    half3 nomTop = SelfUnpackNormal(nomTopData);
                    //roughness blend
                    roughness = roughness * blendFactor + nomTopData.b * (1 - blendFactor);
                    //normal blend
                    nomTop.xy *= _SecNormStr;
                    nomBase = float3(nomBase.xy + nomTop.xy, nomBase.z * nomTop.z) * (1 - blendFactor) + nomBase * blendFactor;
                    
                }
                nomWorld.x = dot(i.tspace0, nomBase);
                nomWorld.y = dot(i.tspace1, nomBase);
                nomWorld.z = dot(i.tspace2, nomBase);
                nomWorld = normalize(nomWorld);
                
                //GI
                //gi.light.dir
                fixed3 LightDir = normalize(_WorldSpaceLightPos0.xyz);
                
                //gi.light.color
                float atten = LIGHT_ATTENUATION(i);
                half bakedAtten = UnitySampleBakedOcclusion(i.uvLM, i.posWorld);
                float zDist = dot(_WorldSpaceCameraPos - i.posWorld, UNITY_MATRIX_V[2].xyz);
                float fadeDist = UnityComputeShadowFadeDistance(i.posWorld, zDist);
                atten = UnityMixRealtimeAndBakedShadows(atten, bakedAtten, UnityComputeShadowFade(fadeDist));
                fixed4 LightColor = _LightColor0 * atten;
                
                //gi.indirect.diffuse
                half3 indirectdiffuse = 0;
                
                // #if defined(LIGHTMAP_ON)
                //     half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uvLM);
                //     half3 bakedColor = DecodeLightmap(bakedColorTex);
                //     indirectdiffuse = bakedColor;
                // #else
                // if (i.vertexGI.a > 8)
                // {
                //     indirectdiffuse = i.vertexGI.rgb + Shade4PointLights(
                //     unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                //     unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                //     unity_4LightAtten0, i.posWorld.xyz, i.normal.xyz);
                // }
                // #endif
                        
                        
                //计算光照
                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
                half4 c = Rock(albedo, indirectdiffuse, LightColor, roughness, nomWorld, viewDir, LightDir, atten, 1, 1, 1);
                
                if (_GradLayer)
                {
                    //给一个高度上的颜色渐变
                    float gradientStr = smoothstep(_GradColHeight, _GradColHeight + _GradColFeather, i.normal.w);
                    half3 gradientColor = lerp(_GradCol, fixed4(1, 1, 1, 1), gradientStr);//objectPos
                    c.rgb *= gradientColor;
                }
                if (_EmisLayer)
                {
                    c.rgb = c.rgb * nomBaseData.a + _EmisCol * (1 - nomBaseData.a);
                }
                // c.rgb = depthFogLine(i.posWorld, _WorldSpaceCameraPos, _DepthStartDis, _DepthEndDis, _DepthFogColor, _DepthStart, _DepthEnd, _LineFogColor, c, _LineInsten, _DepthInsten, _LineStartFog, _LineEndFog, 1);
                c.rgb = clamp(c.rgb, 0, 10);
                
                return c;
            }
            ENDCG
                
        }
    }
    FallBack "Transparent/Cutout/Diffuse"
    CustomEditor "JTRP.ShaderDrawer.LWGUI"
}