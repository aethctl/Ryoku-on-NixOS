#pragma once

#include <QImage>
#include <QMutex>
#include <QObject>
#include <QString>
#include <QVideoFrame>

class QAudioOutput;
class QMediaPlayer;
class QVideoSink;

class PreviewVideo : public QObject
{
    Q_OBJECT
public:
    explicit PreviewVideo(QObject *parent = nullptr);
    ~PreviewVideo() override;

    void play(const QString &path, bool muted, double volume);
    void stop();
    // Creating the first player blocks for most of a second, so it happens while the picker is hidden.
    void prewarm();

    // Null when no new frame arrived since the last take.
    QImage takeFrame();
    bool active() const { return m_active; }

Q_SIGNALS:
    void frameReady();

private:
    void ensurePipeline();
    void onFrame(const QVideoFrame &frame);

    QMediaPlayer *m_player = nullptr;
    QVideoSink *m_sink = nullptr;
    QAudioOutput *m_audio = nullptr;

    mutable QMutex m_mutex;
    QVideoFrame m_latest;
    bool m_hasFrame = false;
    bool m_active = false;
};
