using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class VolumetricLightRenderPass : ScriptableRenderPass
{
    // used to label this pass in Unity's Frame Debug utility
    string profilerTag;

    Material material;
    RenderTargetIdentifier cameraColorTargetIdent;
    RenderTexture worldPosRT;
    private ScriptableRenderer renderer;

    private RenderTexture src, dest, source;

    private int width, height, iterations;

    private const int VolumetricLightPass = 0;
    private const int BlurPass = 1;
    private const int CompositePass = 2;

    public VolumetricLightRenderPass(string profilerTag,
        RenderPassEvent renderPassEvent, Material material, int iterations)
    {
        this.profilerTag = profilerTag;
        this.renderPassEvent = renderPassEvent;
        this.material = material;
        this.worldPosRT = worldPosRT;
        this.iterations = iterations;
    }

    // This isn't part of the ScriptableRenderPass class and is our own addition.
    // For this custom pass we need the camera's color target, so that gets passed in.
    public void Setup(ScriptableRenderer renderer)
    {
        this.renderer = renderer;
    }

    // called each frame before Execute, use it to set up things the pass will need
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        cameraColorTargetIdent = renderer.cameraColorTarget;

        width = cameraTextureDescriptor.width;
        height = cameraTextureDescriptor.height;

        source = RenderTexture.GetTemporary(width, height, 0);
        src = RenderTexture.GetTemporary(width, height, 0);
        dest = RenderTexture.GetTemporary(width, height, 0);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // fetch a command buffer to use
        CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
        cmd.Clear();

        List<RenderTexture> renderTextures = new List<RenderTexture>();

        material.SetTexture("_SourceTex", source);

        cmd.Blit(cameraColorTargetIdent, source);
        cmd.Blit(source, cameraColorTargetIdent);
        cmd.Blit(cameraColorTargetIdent, source);

        cmd.Blit(null, src, material, VolumetricLightPass);

        cmd.Blit(src, dest, material, BlurPass);
        
        renderTextures.Add(dest);
        
        RenderTexture.ReleaseTemporary(src);
        src = dest;

        // DownSampling
         int i = 1;
         for (; i < iterations; i++)
         {
             width /= 2;
             height /= 2;
        
             if (height < 2 || width < 2)
             {
                 break;
             }
        
             dest = RenderTexture.GetTemporary(width, height, 0);
             cmd.Blit(src, dest, material, BlurPass);
             renderTextures.Add(dest);
             src = dest;
         }
        
         //UpSampling
         for (i -= 2; i >= 0; i--)
         {
             dest = renderTextures[i];
             renderTextures.RemoveAt(i);
        
             cmd.Blit(src, dest, material, BlurPass);
             RenderTexture.ReleaseTemporary(src);
             src = dest;
         }

        cmd.Blit(src, cameraColorTargetIdent, material, CompositePass);

        context.ExecuteCommandBuffer(cmd);

        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        RenderTexture.ReleaseTemporary(src);
        RenderTexture.ReleaseTemporary(dest);
        RenderTexture.ReleaseTemporary(source);
    }
}