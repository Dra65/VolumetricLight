using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class CameraRay : MonoBehaviour
{
    Vector3[] FrustumCorners = new Vector3[4];
    Vector3[] NormCorners = new Vector3[4];

    public Material material;

    void Update()
    {
        Camera.main.CalculateFrustumCorners(new
            Rect(0, 0, 1, 1), Camera.main.farClipPlane, Camera.MonoOrStereoscopicEye.Mono, FrustumCorners);
        for (int i = 0; i < 4; i++)
        {
            NormCorners[i] = Camera.main.transform.TransformVector(FrustumCorners[i]);
            NormCorners[i] = NormCorners[i].normalized;
        }

        material.SetVector("_BL", NormCorners[0]);
        material.SetVector("_TL", NormCorners[1]);
        material.SetVector("_TR", NormCorners[2]);
        material.SetVector("_BR", NormCorners[3]);
    }

    private void OnDrawGizmos()
    {
        Debug.DrawRay(Camera.main.transform.position, NormCorners[0], Color.red); //BL
        Debug.DrawRay(Camera.main.transform.position, NormCorners[1], Color.blue); //TL
        Debug.DrawRay(Camera.main.transform.position, NormCorners[2], Color.yellow); //TR
        Debug.DrawRay(Camera.main.transform.position, NormCorners[3], Color.green); //BR
    }
}