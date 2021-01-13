using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class DrawCloud : MonoBehaviour
{
    public Gradient gradient;
    public int horizontalStackSize = 20;
    public float cloudHeight = 1f;
    public Mesh quadMesh;
    public Material cloudMaterial;
    float offset;

    public int layer;
    public Camera camera;
    private Matrix4x4 matrix;
    private Matrix4x4[] matrices;

    public bool useGpuInstancing = true;

    void Start()
    {
    }

    void Update()
    {
        // foreach (var item in gradient.colorKeys)
        // {
        //     Debug.Log(item.color.ToString()+item.time.ToString());
        // }
        cloudMaterial.SetFloat("_midYValue", transform.position.y);
        cloudMaterial.SetFloat("_cloudHeight", cloudHeight);

        offset = cloudHeight / horizontalStackSize / 2f;
        Vector3 startPosition = transform.position + (Vector3.up * (offset * horizontalStackSize / 2f));

        if (useGpuInstancing)
        {
            matrices = new Matrix4x4[horizontalStackSize];
        }

        for (int i = 0; i < horizontalStackSize; i++)
        {
            matrix = Matrix4x4.TRS(startPosition - (Vector3.up * offset * i), transform.rotation, transform.localScale);
            if (useGpuInstancing)
            {
                matrices[i] = matrix;
            }
            else
            {
                Graphics.DrawMesh(quadMesh, matrix, cloudMaterial, layer, camera, 0, null, false, false, false);
            }
        }

        if (useGpuInstancing)
        {
            UnityEngine.Rendering.ShadowCastingMode shadowCasting = UnityEngine.Rendering.ShadowCastingMode.Off;
            Graphics.DrawMeshInstanced(quadMesh, 0, cloudMaterial, matrices, horizontalStackSize, null, shadowCasting, false, layer, camera);
        }
    }
}
