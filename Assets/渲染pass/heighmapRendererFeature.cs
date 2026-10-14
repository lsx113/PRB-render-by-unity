using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class heighmapRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public Camera orthoCamera; // 场景中的正交相机
        public LayerMask terrainLayer = 0; // 地形Layer
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
        public int textureSize = 1024;
     
    }

    // 关键修改：给settings初始值，避免为null
    public Settings settings = new Settings();

    private heighmapRenderPass _pass;
    private RenderTexture _heightRT; // 高度图

    public override void Create()
    {
        // 保护：如果settings为null，重新创建
        if (settings == null)
            settings = new Settings();

        // 如果RT已存在，先释放，避免重复创建
        if (_heightRT != null)
        {
            _heightRT.Release();
            DestroyImmediate(_heightRT);
        }

        // 创建RFloat格式RT，保证高度精度
        _heightRT = new RenderTexture(settings.textureSize, settings.textureSize, 0, RenderTextureFormat.RFloat);
        _heightRT.name = "HeightMapRT";
        _heightRT.Create();

        // 创建Pass，传入settings和RT
        _pass = new heighmapRenderPass(settings, _heightRT);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_heightRT == null || settings.orthoCamera == null) return;

        // 将RT设为全局纹理，后续Shader可通过_TerrainHeightMap采样
        Shader.SetGlobalTexture("_TerrainHeightMap", _heightRT);
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        if (_heightRT != null)
        {
            _heightRT.Release();
            DestroyImmediate(_heightRT);
        }
    }
}