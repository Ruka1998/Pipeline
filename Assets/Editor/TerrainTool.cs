using System;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using PathCreation;

public class TerrainTool : EditorWindow
{
    private Terrain m_terrain;
    Vector2 scrollPosition = Vector2.zero;
    private string[] toorbar = new string[2];
    int Editortoolbar = 0;

    [Serializable]
    public class TextureAttributes
    {
        [Range(0.0f, 1.0f)]
        public float minSteepness;
        [Range(0.0f, 1.0f)]
        public float blendWidth;
    }
    public List<TextureAttributes> listTextures = new List<TextureAttributes>();

    float[,] originalHeight;
    private bool inSplineControl = false;
    private GameObject go;

    private BezierPath.ControlMode controlMode = BezierPath.ControlMode.Automatic;
    private bool isClosed = false;
    private int radius = 10;

    [MenuItem("Tools/场景工具/地形工具", false)]
    static void CreateMangerWindow()
    {
        EditorWindow window = GetWindow<TerrainTool>("Terrain Toolbox");
        window.minSize = new Vector2(200, 150);
        window.Show();
    }

    void OnGUI()
    {
        toorbar[0] = "地形道路样条线编辑";
        toorbar[1] = "地形贴图自动生成";
        Editortoolbar = GUILayout.Toolbar(Editortoolbar, toorbar);
        switch (Editortoolbar)
        {
            case 0:
                scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);

                EditorGUILayout.BeginVertical("Box");
                m_terrain = EditorGUILayout.ObjectField("地形", m_terrain, typeof(Terrain), true) as Terrain;
                EditorGUILayout.Space();
                EditorGUI.BeginChangeCheck();
                controlMode = (BezierPath.ControlMode)EditorGUILayout.EnumPopup("控制方式", controlMode);
                EditorGUILayout.Space();
                isClosed = EditorGUILayout.Toggle("闭环", isClosed);
                EditorGUILayout.Space();
                radius = Mathf.Clamp(EditorGUILayout.IntField("道路宽度", radius), 0, 100);
                EditorGUILayout.Space();
                if (EditorGUI.EndChangeCheck())
                {
                    UpdatePathSettings();
                }
                if (GUILayout.Button(new GUIContent("新建样条控制线", "选中你要处理的地形，即可生成")))
                {
                    GenerateSplineControl();
                }
                EditorGUILayout.Space();
                EditorGUILayout.BeginHorizontal();
                if (GUILayout.Button(new GUIContent("清除样条线", "结束样条线对地形的影响")))
                {
                    RemoveSplineControl();
                }
                if (GUILayout.Button(new GUIContent("还原原地形", "清除样条线对地形的影响")))
                {
                    RecoverTerrain();
                }
                EditorGUILayout.EndHorizontal();
                EditorGUILayout.EndVertical();

                EditorGUILayout.EndScrollView();

                break;
            case 1:
                scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);
                EditorGUILayout.HelpBox("Terrain 这一栏把你要处理的地形选进来\n在Size这里填上你想使用的贴图数量，不要超过8\n新增的贴图列表和地形的贴图顺序是对应的\n第一张贴图是默认平地上的贴图，不需要调数值\nsteepness 是该贴图的起始陡峭度\nblendwidth是该帖图与上一张贴图的融合程度",MessageType.None);
                m_terrain = EditorGUILayout.ObjectField("Terrain", m_terrain, typeof(Terrain), true) as Terrain;

                ScriptableObject target = this;
                SerializedObject so = new SerializedObject(target);
                SerializedProperty stringsProperty = so.FindProperty("listTextures");
                EditorGUILayout.PropertyField(stringsProperty, true);
                so.ApplyModifiedProperties();

                EditorGUILayout.Space();
                if (GUILayout.Button("Import"))
                {
                    if (m_terrain == null) return;

                    TerrainData terrainData = m_terrain.terrainData;
                    float[,,] splatmapData = new float[terrainData.alphamapWidth, terrainData.alphamapHeight, terrainData.alphamapLayers];

                    for (int y = 0; y < terrainData.alphamapHeight; y++)
                    {
                        for (int x = 0; x < terrainData.alphamapWidth; x++)
                        {
                            float y_01 = (float)y / (float)terrainData.alphamapHeight;
                            float x_01 = (float)x / (float)terrainData.alphamapWidth;

                            float steepness = terrainData.GetSteepness(y_01, x_01) / 90.0f;
                            float[] splatWeights = new float[terrainData.alphamapLayers];


                            for (int i = 0; i < listTextures.Count; i++)
                            {
                                if (i == 0)
                                {
                                    splatWeights[i] = 1.0f;
                                }
                                else
                                {
                                    splatWeights[i] = Mathf.Lerp(0.0f, 1.0f, smoothstep(
                                        listTextures[i].minSteepness - listTextures[i].blendWidth,
                                        listTextures[i].minSteepness + listTextures[i].blendWidth,
                                        steepness)
                                    );
                                    for (int j = 0; j < i; j++)
                                    {
                                        splatWeights[j] *= (1.0f - splatWeights[i]);
                                    }
                                }
                            }
                            for (int i = 0; i < terrainData.alphamapLayers; i++)
                            {
                                splatmapData[x, y, i] = splatWeights[i];
                            }
                        }
                    }
                    terrainData.SetAlphamaps(0, 0, splatmapData);
                }
                EditorGUILayout.EndScrollView();
                break;
        }


    }

    float smoothstep(float a, float b, float x)
    {
        float t = Mathf.Clamp((x - a) / (b - a), 0.0f, 1.0f);
        return t * t * (3.0f - (2.0f * t));
    }

    void GenerateSplineControl()
    {
        if (m_terrain == null || inSplineControl) return;
        go = new GameObject("PathController");
        var pathCreator = go.AddComponent<PathCreator>();

        pathCreator.bezierPath.ControlPointMode = BezierPath.ControlMode.Automatic;
        pathCreator.EditorData.showTransformTool = false;
        pathCreator.EditorData.keepConstantHandleSize = true;
        // pathCreator.bezierPath.MovePoint()

        var terrainAdjuster = go.AddComponent<TerrainAdjusterRuntime>();
        terrainAdjuster.terrain = m_terrain;
        terrainAdjuster.initialPassRadii = new int[] { 5 };

        originalHeight = m_terrain.terrainData.GetHeights(0, 0, m_terrain.terrainData.heightmapResolution, m_terrain.terrainData.heightmapResolution);

        inSplineControl = true;
        Selection.activeGameObject = go;

    }
    void RemoveSplineControl()
    {
        if (inSplineControl)
        {
            var terrainAdjuster = go.GetComponent<TerrainAdjusterRuntime>();
            terrainAdjuster.CleanUp();
            DestroyImmediate(go.GetComponent<TerrainAdjusterRuntime>());
            DestroyImmediate(go.GetComponent<PathCreator>());
            DestroyImmediate(go);

            inSplineControl = false;
        }
    }
    void RecoverTerrain()
    {
        if (m_terrain != null && originalHeight != null)
        {
            m_terrain.terrainData.SetHeights(0, 0, originalHeight);
        }

    }

    void UpdatePathSettings()
    {
        if (inSplineControl)
        {
            var terrainAdjuster = go.GetComponent<TerrainAdjusterRuntime>();
            var pathCreator = go.GetComponent<PathCreator>();
            pathCreator.bezierPath.ControlPointMode = controlMode;
            pathCreator.bezierPath.IsClosed = isClosed;
            terrainAdjuster.initialPassRadii[0] = radius;
            terrainAdjuster.ShapeTerrain();
        }
    }

}