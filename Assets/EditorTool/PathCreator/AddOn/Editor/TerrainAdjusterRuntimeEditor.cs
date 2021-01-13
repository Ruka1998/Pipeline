using UnityEngine;
using UnityEditor;
 
[CustomEditor(typeof(TerrainAdjusterRuntime))]
public class TerrainAdjusterRuntimeEditor : Editor
{
    TerrainAdjusterRuntimeEditor editor;

 
    public void OnEnable()
    {
        this.editor = this;
 
        TerrainAdjusterRuntime targetGameObject = (TerrainAdjusterRuntime)target;
 
        if (targetGameObject.pathCreator != null)
        {
            targetGameObject.pathCreator.pathUpdated -= OnPathChanged;
            targetGameObject.pathCreator.pathUpdated += OnPathChanged;
        }
    }
 
 
    void OnDisable()
    {
        TerrainAdjusterRuntime targetGameObject = (TerrainAdjusterRuntime)target;
 
        // remove original terrain data
        // targetGameObject.CleanUp();
 
        // remove existing listeners
        if (targetGameObject.pathCreator != null)
        {
            targetGameObject.pathCreator.pathUpdated -= OnPathChanged;
        }
 
    }
 
 
    void OnPathChanged()
    {
        TerrainAdjusterRuntime targetGameObject = (TerrainAdjusterRuntime)target;
 
        targetGameObject.ShapeTerrain();
    }
 
    public override void OnInspectorGUI()
    {
        TerrainAdjusterRuntime targetGameObject = (TerrainAdjusterRuntime)target;
 
        EditorGUI.BeginChangeCheck();
 
        DrawDefaultInspector();
 
        if (EditorGUI.EndChangeCheck())
        {
            // if anything (eg falloff) changed recreate the terrain under the path
            OnPathChanged();
        }
 
        EditorGUILayout.BeginVertical();
 
        if (GUILayout.Button("Flatten entire terrain"))
        {
            SetTerrainHeight(targetGameObject.terrain, 0f);
            targetGameObject.CleanUp();
        }
 
        EditorGUILayout.EndVertical();
    }
 
    void SetTerrainHeight(Terrain terrain, float height)
    {
        TerrainData terrainData = terrain.terrainData;
 
        int w = terrainData.heightmapResolution;
        int h = terrainData.heightmapResolution;
        float[,] allHeights = terrainData.GetHeights(0, 0, w, h);
 
        float terrainMin = terrain.transform.position.y + 0f;
        float terrainMax = terrain.transform.position.y + terrain.terrainData.size.y;
        float totalHeight = terrainMax - terrainMin;
 
        for (int x = 0; x < w; x++)
        {
            for (int y = 0; y < h; y++)
            {
                allHeights[y, x] = 0f;
            }
        }
 
        terrain.terrainData.SetHeights(0, 0, allHeights);
    }
 
}