#include "previewvideo.h"

#include <QAudioOutput>
#include <QMediaPlayer>
#include <QMutexLocker>
#include <QUrl>
#include <QVideoSink>

#include <algorithm>

namespace {
constexpr QSize kMaxPreview(640, 360);
}

PreviewVideo::PreviewVideo(QObject *parent)
    : QObject(parent)
{
}

PreviewVideo::~PreviewVideo()
{
    stop();
}

void PreviewVideo::ensurePipeline()
{
    if (m_player)
        return;
    m_sink = new QVideoSink(this);
    m_audio = new QAudioOutput(this);
    m_player = new QMediaPlayer(this);
    m_player->setVideoSink(m_sink);
    m_player->setAudioOutput(m_audio);
    m_player->setLoops(QMediaPlayer::Infinite);
    connect(m_sink, &QVideoSink::videoFrameChanged, this, &PreviewVideo::onFrame);
}

void PreviewVideo::prewarm()
{
    ensurePipeline();
}

void PreviewVideo::play(const QString &path, bool muted, double volume)
{
    if (path.isEmpty()) {
        stop();
        return;
    }
    ensurePipeline();
    m_audio->setMuted(muted);
    m_audio->setVolume(float(std::clamp(volume, 0.0, 1.0)));
    m_active = true;
    const QUrl url = path.contains(QStringLiteral("://")) ? QUrl(path) : QUrl::fromLocalFile(path);
    m_player->setSource(url);
    m_player->play();
}

void PreviewVideo::stop()
{
    m_active = false;
    if (m_player) {
        m_player->stop();
        m_player->setSource(QUrl());
    }
    QMutexLocker lock(&m_mutex);
    m_latest = QVideoFrame();
    m_hasFrame = false;
}

void PreviewVideo::onFrame(const QVideoFrame &frame)
{
    if (!frame.isValid())
        return;
    {
        QMutexLocker lock(&m_mutex);
        m_latest = frame;
        m_hasFrame = true;
    }
    Q_EMIT frameReady();
}

QImage PreviewVideo::takeFrame()
{
    QVideoFrame frame;
    {
        QMutexLocker lock(&m_mutex);
        if (!m_hasFrame)
            return QImage();
        frame = m_latest;
        m_hasFrame = false;
    }
    QImage img = frame.toImage();
    if (img.isNull())
        return QImage();
    if (img.format() != QImage::Format_RGBA8888)
        img = std::move(img).convertToFormat(QImage::Format_RGBA8888);
    if (img.width() > kMaxPreview.width() || img.height() > kMaxPreview.height())
        img = img.scaled(kMaxPreview, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    return img;
}
