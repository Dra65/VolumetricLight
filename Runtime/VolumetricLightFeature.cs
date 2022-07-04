using UnityEngine;
using UnityEngine.Rendering.Universal;
public class VolumetricLightFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class MyFeatureSettings
    {
        public bool IsEnabled = true;
        public RenderPassEvent WhenToInsert = RenderPassEvent.BeforeRenderingPostProcessing;
        public Material Material;
        [Tooltip("Blur Iterations")]public int iterations;
    }

    // MUST be named "settings" (lowercase) to be shown in the Render Features inspector
    public MyFeatureSettings settings = new MyFeatureSettings();

    RenderTargetHandle renderTextureHandle;
    VolumetricLightRenderPass myRenderPass;

    public override void Create()
    {
        myRenderPass = new VolumetricLightRenderPass(
            "Custom Outline Pass",
            settings.WhenToInsert,
            settings.Material,
            settings.iterations
        );
    }
  
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!settings.IsEnabled)
        {
            return;
        }
        
        myRenderPass.Setup(renderer);

        renderer.EnqueuePass(myRenderPass);
    }
}
