using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class heighmapRenderPass : ScriptableRenderPass
{
    private heighmapRendererFeature.Settings Settings;
    private RenderTexture _heightRT;
    private static readonly ShaderTagId HeightMapTag = new ShaderTagId("HeightMap");
    public heighmapRenderPass(heighmapRendererFeature.Settings settings,RenderTexture renderTexture)
    {
        Settings = settings;
        _heightRT = renderTexture;
        renderPassEvent = settings.renderPassEvent;//设置渲染顺序
    }
    private class PassData
    {
        public RendererListHandle rendererList; // 要绘制的物体列表
        public TextureHandle heightMapTexture; // 高度图纹理句柄
    }
    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        // 从frameData中获取相机数据
        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
        UniversalRenderingData renderingData = frameData.Get<UniversalRenderingData>();
        TextureHandle heightMapHandle = renderGraph.ImportTexture(
          RTHandles.Alloc(_heightRT)
      );//获取外部纹理
        // 声明一个Raster渲染Pass
        using (var builder = renderGraph.AddRasterRenderPass<PassData>("HeightMapPass", out var passData))
        {
            // 设置渲染目标为高度图纹理，并标记为写入
            builder.SetRenderAttachment(heightMapHandle, 0, AccessFlags.Write);

            // 构造绘制设置和过滤设置
            DrawingSettings drawSettings = new DrawingSettings(HeightMapTag, new SortingSettings(cameraData.camera));
            FilteringSettings filterSettings = new FilteringSettings(RenderQueueRange.all, Settings.terrainLayer);

            // 创建RendererListHandle，这是RenderGraph中绘制物体的方式
            RendererListParams rendererListParams = new RendererListParams(renderingData.cullResults, drawSettings, filterSettings);
            passData.rendererList = renderGraph.CreateRendererList(rendererListParams);

            // 将纹理句柄存入PassData
            passData.heightMapTexture = heightMapHandle;

            // 标记RendererList为使用状态
            builder.UseRendererList(passData.rendererList);

            // 设置渲染函数
            builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
            {
                // 清空渲染目标为黑色
                context.cmd.ClearRenderTarget(true, true, Color.black);

                // 设置视图投影矩阵（使用正交相机的矩阵）
                Camera cam = Settings.orthoCamera;
                context.cmd.SetViewProjectionMatrices(cam.worldToCameraMatrix, cam.projectionMatrix);

                // 绘制地形
                context.cmd.DrawRendererList(data.rendererList);

                // 恢复主相机的矩阵（RenderGraph会自动处理，但显式恢复更安全）
                context.cmd.SetViewProjectionMatrices(
                    cameraData.camera.worldToCameraMatrix,
                    cameraData.camera.projectionMatrix
                );
            });
        }
    }
}
