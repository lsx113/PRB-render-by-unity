using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class heighmapRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        // 这个Pass在URP渲染流程中的执行时机，默认在不透明物体渲染前
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
    }



}
