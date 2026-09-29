#include "transitionpass.h"

#include <QFile>
#include <rhi/qrhi.h>
#include <rhi/qshader.h>

namespace {

QShader loadShader(const QString &name)
{
    QFile f(name);
    if (!f.open(QIODevice::ReadOnly))
        qFatal("ryogami: missing shader %s", qPrintable(name));
    return QShader::fromSerialized(f.readAll());
}

// std140 layout of the block shared by transition.vert/.frag.
struct TransUniform {
    float resolution[2];
    float origin[2];
    float progress;
    quint32 kind;
    float opacity;
    float pad;
    float accent[4];
};
static_assert(sizeof(TransUniform) == 48);

}

TransitionPass::~TransitionPass()
{
    releaseResources();
}

bool TransitionPass::ensureTargets(QRhi *rhi, QSize pixelSize)
{
    const QSize px = pixelSize.isEmpty() ? QSize(1, 1) : pixelSize;
    if (m_texA && m_size == px)
        return false;

    m_size = px;
    m_texA.reset(rhi->newTexture(QRhiTexture::RGBA8, px, 1, QRhiTexture::RenderTarget));
    m_texA->create();
    m_texB.reset(rhi->newTexture(QRhiTexture::RGBA8, px, 1, QRhiTexture::RenderTarget));
    m_texB->create();

    m_rtA.reset(rhi->newTextureRenderTarget(QRhiTextureRenderTargetDescription(QRhiColorAttachment(m_texA.get()))));
    m_rpd.reset(m_rtA->newCompatibleRenderPassDescriptor());
    m_rtA->setRenderPassDescriptor(m_rpd.get());
    m_rtA->create();

    m_rtB.reset(rhi->newTextureRenderTarget(QRhiTextureRenderTargetDescription(QRhiColorAttachment(m_texB.get()))));
    m_rtB->setRenderPassDescriptor(m_rpd.get());
    m_rtB->create();

    // The composite bindings reference the reallocated textures.
    m_srb.reset();
    return true;
}

void TransitionPass::buildPipeline(QRhi *rhi, QRhiRenderTarget *mainTarget)
{
    if (!m_uniform) {
        m_uniform.reset(rhi->newBuffer(QRhiBuffer::Dynamic, QRhiBuffer::UniformBuffer, sizeof(TransUniform)));
        m_uniform->create();
    }
    if (!m_sampler) {
        m_sampler.reset(rhi->newSampler(QRhiSampler::Linear, QRhiSampler::Linear, QRhiSampler::None,
                                        QRhiSampler::ClampToEdge, QRhiSampler::ClampToEdge));
        m_sampler->create();
    }
    m_srb.reset(rhi->newShaderResourceBindings());
    m_srb->setBindings({
        QRhiShaderResourceBinding::uniformBuffer(0, QRhiShaderResourceBinding::FragmentStage, m_uniform.get()),
        QRhiShaderResourceBinding::sampledTexture(1, QRhiShaderResourceBinding::FragmentStage, m_texA.get(), m_sampler.get()),
        QRhiShaderResourceBinding::sampledTexture(2, QRhiShaderResourceBinding::FragmentStage, m_texB.get(), m_sampler.get()),
    });
    m_srb->create();

    m_pipeline.reset(rhi->newGraphicsPipeline());
    QRhiGraphicsPipeline::TargetBlend blend;
    blend.enable = true;
    blend.srcColor = QRhiGraphicsPipeline::One;
    blend.dstColor = QRhiGraphicsPipeline::OneMinusSrcAlpha;
    blend.srcAlpha = QRhiGraphicsPipeline::One;
    blend.dstAlpha = QRhiGraphicsPipeline::OneMinusSrcAlpha;
    m_pipeline->setTargetBlends({blend});
    m_pipeline->setTopology(QRhiGraphicsPipeline::Triangles);
    m_pipeline->setShaderStages({
        {QRhiShaderStage::Vertex, loadShader(QStringLiteral(":/shaders/transition.vert.qsb"))},
        {QRhiShaderStage::Fragment, loadShader(QStringLiteral(":/shaders/transition.frag.qsb"))},
    });
    m_pipeline->setVertexInputLayout(QRhiVertexInputLayout());
    m_pipeline->setShaderResourceBindings(m_srb.get());
    m_pipelinePass.reset(mainTarget->renderPassDescriptor()->newCompatibleRenderPassDescriptor());
    m_pipeline->setRenderPassDescriptor(m_pipelinePass.get());
    m_pipeline->setSampleCount(mainTarget->sampleCount());
    m_pipelineSamples = mainTarget->sampleCount();
    m_pipeline->create();
}

void TransitionPass::prepare(QRhi *rhi, QRhiResourceUpdateBatch *batch, QRhiRenderTarget *mainTarget,
                             float progress, int kind, QPointF origin, const QColor &accent, float opacity,
                             bool targetsChanged)
{
    if (targetsChanged || !m_srb || !m_pipeline || !m_pipelinePass
        || !m_pipelinePass->isCompatible(mainTarget->renderPassDescriptor())
        || m_pipelineSamples != mainTarget->sampleCount())
        buildPipeline(rhi, mainTarget);

    TransUniform u{};
    u.resolution[0] = float(m_size.width());
    u.resolution[1] = float(m_size.height());
    u.origin[0] = float(origin.x());
    u.origin[1] = float(origin.y());
    u.progress = progress;
    u.kind = quint32(kind < 0 ? 0 : kind);
    u.opacity = opacity;
    u.accent[0] = float(accent.redF());
    u.accent[1] = float(accent.greenF());
    u.accent[2] = float(accent.blueF());
    u.accent[3] = 1.0f;
    batch->updateDynamicBuffer(m_uniform.get(), 0, sizeof(TransUniform), &u);
}

void TransitionPass::render(QRhiCommandBuffer *cb, QSize pixelSize)
{
    if (!ready())
        return;
    cb->setGraphicsPipeline(m_pipeline.get());
    cb->setViewport(QRhiViewport(0, 0, pixelSize.width(), pixelSize.height()));
    cb->setShaderResources();
    cb->draw(3);
}

void TransitionPass::releaseResources()
{
    m_pipeline.reset();
    m_pipelinePass.reset();
    m_srb.reset();
    m_sampler.reset();
    m_uniform.reset();
    m_rtA.reset();
    m_rtB.reset();
    m_rpd.reset();
    m_texA.reset();
    m_texB.reset();
    m_size = QSize();
}
