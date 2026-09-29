#include "thumbdecoder.h"

#include <QImageReader>
#include <QMutexLocker>

#include <algorithm>
#include <cmath>

namespace {

QString tokenFor(const QString &key, ThumbDecoder::Tier tier)
{
    return key + QLatin1Char('|') + QString::number(int(tier));
}

QString keyFor(const QString &token)
{
    const int cut = token.lastIndexOf(QLatin1Char('|'));
    return cut < 0 ? token : token.left(cut);
}

int mipCount(QSize layer)
{
    return int(std::floor(std::log2(std::max(1, std::max(layer.width(), layer.height()))))) + 1;
}

QSize fitted(QSize source, QSize box)
{
    if (!source.isValid() || source.isEmpty())
        return box;
    const double scale = std::min({1.0, double(box.width()) / source.width(), double(box.height()) / source.height()});
    return QSize(std::max(1, int(std::lround(source.width() * scale))),
                 std::max(1, int(std::lround(source.height() * scale))));
}

QImage decodeScaled(const QString &path, QSize box, QSize &sourceOut)
{
    QImageReader reader(path);
    reader.setAutoTransform(true);
    const QSize source = reader.size();
    reader.setScaledSize(fitted(source, box));
    QImage image = reader.read();
    if (image.isNull())
        return QImage();
    if (image.width() > box.width() || image.height() > box.height())
        image = image.scaled(box, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    sourceOut = source.isValid() ? source : image.size();
    return std::move(image).convertToFormat(QImage::Format_RGBA8888);
}

}

ThumbDecoder::ThumbDecoder(QObject *parent)
    : QObject(parent)
    , m_nearTile(1024, 576)
    , m_farTile(256, 160)
{
    m_pool.setMaxThreadCount(std::clamp(QThread::idealThreadCount() / 2, 2, 6));
    m_pool.setExpiryTimeout(2000);
}

ThumbDecoder::~ThumbDecoder()
{
    m_pool.clear();
    m_pool.waitForDone();
}

void ThumbDecoder::setTileSizes(QSize near, QSize far)
{
    m_nearTile = near;
    m_farTile = far;
}

bool ThumbDecoder::pending(const QString &key, Tier tier) const
{
    QMutexLocker lock(&m_mutex);
    return m_inflight.contains(tokenFor(key, tier));
}

bool ThumbDecoder::wantedLocked(const QString &key) const
{
    return !m_retaining || m_wanted.contains(key);
}

void ThumbDecoder::request(const QString &key, const QString &path, Tier tier, int priority)
{
    request(key, path, QString(), tier, priority);
}

void ThumbDecoder::request(const QString &key, const QString &path, const QString &fallback, Tier tier, int priority)
{
    const QString token = tokenFor(key, tier);
    {
        QMutexLocker lock(&m_mutex);
        if (!wantedLocked(key) || m_inflight.contains(token))
            return;
        m_inflight.insert(token);
    }
    const QSize box = tier == Near ? m_nearTile : m_farTile;
    const int levels = tier == Near ? mipCount(m_nearTile) : 1;
    const int generation = m_generation.load();
    m_pool.start([this, key, path, fallback, tier, box, levels, token, generation] {
        {
            QMutexLocker lock(&m_mutex);
            if (generation != m_generation.load() || !m_inflight.contains(token) || !wantedLocked(key)) {
                m_inflight.remove(token);
                return;
            }
        }
        QSize source;
        QImage image = decodeScaled(path, box, source);
        if (image.isNull() && !fallback.isEmpty())
            image = decodeScaled(fallback, box, source);
        if (image.isNull()) {
            QMutexLocker lock(&m_mutex);
            m_inflight.remove(token);
            return;
        }

        Result result{tier, TierImage{key, {}}, source};
        result.image.levels.reserve(size_t(levels));
        result.image.levels.push_back(std::move(image));
        for (int level = 1; level < levels; ++level) {
            const QImage &prev = result.image.levels.back();
            const QSize next(std::max(1, prev.width() / 2), std::max(1, prev.height() / 2));
            result.image.levels.push_back(prev.scaled(next, Qt::IgnoreAspectRatio, Qt::SmoothTransformation));
        }
        finish(std::move(result), token);
    }, priority);
}

void ThumbDecoder::finish(Result &&result, const QString &token)
{
    {
        QMutexLocker lock(&m_mutex);
        if (!m_inflight.contains(token))
            return;
        m_results.push_back(std::move(result));
    }
    Q_EMIT ready();
}

std::vector<ThumbDecoder::Result> ThumbDecoder::take(int maxCount)
{
    QMutexLocker lock(&m_mutex);
    const size_t n = std::min(m_results.size(), size_t(std::max(0, maxCount)));
    std::vector<Result> out;
    out.reserve(n);
    for (size_t i = 0; i < n; ++i) {
        m_inflight.remove(tokenFor(m_results[i].image.key, m_results[i].tier));
        out.push_back(std::move(m_results[i]));
    }
    m_results.erase(m_results.begin(), m_results.begin() + qsizetype(n));
    return out;
}

bool ThumbDecoder::hasResults() const
{
    QMutexLocker lock(&m_mutex);
    return !m_results.empty();
}

void ThumbDecoder::cancelQueued()
{
    ++m_generation;
}

void ThumbDecoder::retain(const QSet<QString> &keys)
{
    QMutexLocker lock(&m_mutex);
    m_retaining = true;
    m_wanted = keys;
    // Clearing the inflight token makes a finishing worker discard its result.
    for (auto it = m_inflight.begin(); it != m_inflight.end();) {
        if (keys.contains(keyFor(*it)))
            ++it;
        else
            it = m_inflight.erase(it);
    }
    m_results.erase(std::remove_if(m_results.begin(), m_results.end(),
                                   [&keys](const Result &r) { return !keys.contains(r.image.key); }),
                    m_results.end());
}
