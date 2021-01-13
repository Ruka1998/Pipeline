#ifndef Self01
    #define Self01
    
    inline fixed3 SelfUnpackNormalDXT5nm(fixed4 packednormal)
    {
        fixed3 normal;
        normal.xy = packednormal.xy * 2 - 1;
        normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
        return normal;
    }
    
    inline fixed3 SelfUnpackNormal(fixed4 packednormal)
    {
        #if defined(UNITY_NO_DXT5nm)
            fixed3 normal;
            normal = packednormal.xyz * 2 - 1;
            normal.z = 1;
            return normal;
        #else
            return SelfUnpackNormalDXT5nm(packednormal);
        #endif
    }
    
    
    
    
    
    /* fixed3 depthFog1st(float3 worldPos,fixed DepthStartFog,fixed DepthEndFog,fixed4  DepthColor,fixed4 color,fixed inten)
    {
        fixed Depthfog = saturate((worldPos.y - DepthStartFog) / (DepthEndFog));
        Depthfog = saturate(Depthfog + (1- inten));
        color.rgb = lerp(color.rgb, DepthColor.rgb,  1-Depthfog);
        return color.rgb;
    }*/
    
    fixed3 depthFogLine(float3 worldPos, fixed3 CameraPos, fixed _DepthStartDis, fixed _DepthEndDis, fixed4 DepthColor, fixed DepthStartFog, fixed DepthEndFog, fixed4 LineColor, fixed4 color, fixed LineInten, fixed DepthInten, fixed LineStartFog, fixed LineEndFog, fixed Alpha)
    {
        //Line
        fixed LineDistance = distance(worldPos.xyz, CameraPos.xyz);
        fixed Linefog = saturate((LineDistance - LineStartFog) / LineEndFog);
        
        Linefog = saturate(Linefog - (1 - LineInten));
        LineColor.rgb = LineColor.rgb * (lerp(saturate(Alpha * 5), 1, Linefog));
        color.rgb = lerp(color.rgb, LineColor.rgb, Linefog);
        
        //Depth
        fixed Depthfog = saturate((worldPos.y - DepthStartFog) / (DepthEndFog));
        Depthfog = saturate(Depthfog + (1 - DepthInten));
        //DepthLine
        fixed Depthfog02 = saturate((LineDistance - _DepthStartDis) / _DepthEndDis);
        color.rgb = lerp(color.rgb, DepthColor.rgb, Depthfog02 * (1 - Depthfog));
        
        return color.rgb;
    }
    
    
    /*  fixed3 LineFog2ed(float3 worldPos,fixed3 CameraPos,fixed LineStartFog,fixed LineEndFog,fixed4 FogColor, fixed4 color, fixed inten,fixed Alpha)
    {
        fixed LineDistance = distance(worldPos.xyz,CameraPos.xyz);
        fixed Linefog = saturate((LineDistance - LineStartFog) / (LineEndFog));
        
        Linefog = saturate(Linefog-(1-inten));
        FogColor.rgb = FogColor.rgb*(lerp(saturate(Alpha*5), 1, Linefog));
        color.rgb = lerp(color.rgb, FogColor.rgb, Linefog);
        return color.rgb;
        
    }*/
    
    half4 Rock(half3 albedo, half3 indirectdiffuse, half3 LightColor, half roughness, fixed3 nomWorld, fixed3 viewDir, fixed3 LightDir, half atten, fixed3 _DLightShadowColor, half _EnvInfo, fixed4 _SkyLightmapColor)
    {
        half nl = saturate(dot(nomWorld, LightDir));
        half3 h = normalize(viewDir + LightDir);
        half nh = saturate(dot(nomWorld, h));
        
        roughness *= roughness;
        half specPower = (2.0 / max(1e-4f, roughness * roughness)) - 2.0;
        specPower = max(specPower, 1e-4f) * 1.6;
        
        half spec = pow(nh, specPower) * (specPower + 1) * 0.2;
        
        #if defined(SHADER_API_MOBILE)
            spec = spec - 1e-4f;
            spec = clamp(spec, 0.0, 100.0);
        #endif
        
        half3 lightMinusDir = normalize(half3(-_WorldSpaceLightPos0.x, _WorldSpaceLightPos0.y, -_WorldSpaceLightPos0.z));
        half nl2 = saturate(dot(nomWorld, lightMinusDir));
        nl2 = nl2 * 0.5 + 0.5;
        indirectdiffuse = indirectdiffuse * atten + indirectdiffuse * _DLightShadowColor.rgb * (1 - atten) * 2 * (nl + nl2);
        
        half3 col = (albedo + spec * _EnvInfo * half3(0.04, 0.04, 0.04)) * nl * LightColor + albedo * indirectdiffuse * _SkyLightmapColor.rgb;
        return half4(col, 1.0);
    }
    
    inline half3 EnvBRDFApprox_(half3 SpecularColor, half Roughness, half NoV)
    {
        half4 c0 = {
            ( - (1)), ( - (0.0275)), ( - (0.572)), 0.022
        };
        half4 c1 = {
            1, 0.0425, 1.04, ( - (0.04))
        };
        half4 r = ((((Roughness) * (c0))) + (c1));
        half a004 = ((((min(((r.x) * (r.x)), exp2(((( - (9.28))) * (NoV))))) * (r.x))) + (r.y));
        half2 AB = ((((half2(( - (1.04)), 1.04)) * (a004))) + (r.zw));
        return((((SpecularColor) * (AB.x))) + (AB.y));
    }
    
    inline half4 PBS_OutSideSimple_NoEnv(half3 diffColor, half3 specColor, half3 diffColorIndirect, half3 lightcolor, half smoothness, half3 normal, half3 viewdir, half3 lightdir, half _EnvInfo, half atten, fixed3 _DLightShadowColor, fixed4 _SkyLightmapColor)
    {
        half perceptualRoughness = 1.0 - smoothness;
        half m = perceptualRoughness * perceptualRoughness + 0.02;
        half m2 = m * m;
        half3 halfDir = normalize(lightdir + viewdir);
        half nv = max(0, dot(normal, viewdir));
        half nl = max(0, dot(normal, lightdir));
        half nh = max(0, dot(normal, halfDir));
        half3 nxh = cross(normal, halfDir);
        half nh2 = dot(nxh, nxh);
        half diffuse = nl;
        specColor = EnvBRDFApprox_(specColor, perceptualRoughness, nv);
        half D = nh2 + nh * nh * m2;
        D = D * D + 1e-06;
        D = (1 + perceptualRoughness) * 0.25 * min((m2 / D), 65504.0);
        #if defined(SHADER_API_MOBILE)
            D = D - 1e-4f;
            D = clamp(D, 0.0, 100.0);
        #endif
        
        half3 lightMinusDir = normalize(half3(-_WorldSpaceLightPos0.x, _WorldSpaceLightPos0.y, -_WorldSpaceLightPos0.z));
        half nl2 = saturate(dot(normal, lightMinusDir));
        nl2 = nl2 * 0.5 + 0.5;
        diffColorIndirect = diffColorIndirect * atten + diffColorIndirect * _DLightShadowColor.rgb * (1 - atten) * 2 * (nl + nl2);
        
        half3 sunSpec = specColor * D * lightcolor * diffuse;
        half3 color = diffColor * (diffColorIndirect * _SkyLightmapColor.rgb + lightcolor * diffuse) + sunSpec * _EnvInfo;
        return half4(color, 1);
    }
    
    inline half4 PBS_InSide_Spe_NoEnv(half3 specColor, half smoothness, half3 normal, half3 viewdir, half3 lightdir, half4 _SpeColor)
    {
        half perceptualRoughness = 1.0 - smoothness;
        float m = perceptualRoughness * perceptualRoughness + 0.02;
        float m2 = m * m;
        float3 halfDir = normalize(lightdir + viewdir);
        float nv = max(0, dot(normal, viewdir));
        float nl = max(0, dot(normal, lightdir));
        float nh = max(0, dot(normal, halfDir));
        float3 nxh = cross(normal, halfDir);
        float nh2 = dot(nxh, nxh);
        float diffuse = nl;
        
        specColor = EnvBRDFApprox_(specColor, perceptualRoughness, nv);
        float D = nh2 + nh * nh * m2;
        D = D * D + 1e-06;
        
        D = (1 + perceptualRoughness) * 0.25 * min((m2 / D), 65504.0);
        #if defined(SHADER_API_MOBILE)
            D = D - 1e-4f;
            D = clamp(D, 0.0, 100.0);
        #endif
        //return half4(D.rrr, 1);
        
        half3 sunSpec = specColor * D * _SpeColor * nl;
        half3 color = sunSpec;
        return half4(color, 1);
        //return half4(0,0,0, 1);
    }
    
    
    inline float RGBXToFloat(float4 c)
    {
        return floor(c.r * 255.0) + floor(c.g * 255.0) * 256.0 + floor(c.b * 255.0) * 256.0 * 256.0;
    }
    
    inline float4 FloatToRGBX(float v)
    {
        float4 color;
        color.b = floor(v / 256.0 / 256.0);
        color.g = floor((v - color.b * 256.0 * 256.0) / 256.0);
        color.r = floor(v - color.b * 256.0 * 256.0 - color.g * 256.0);
        color.a = 255.0;
        return color / 255.0;
    }
    
#endif





