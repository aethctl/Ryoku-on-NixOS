#include "settings.h"

#include "daemon.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QQmlEngine>
#include <QTimer>

namespace {
constexpr int kCoalesceMs = 120;
constexpr int kSmallScreenMax = 1600;
}

Settings *Settings::s_instance = nullptr;

Settings::Settings(QObject *parent)
    : QObject(parent)
    , m_flush(new QTimer(this))
{
    m_flush->setSingleShot(true);
    m_flush->setInterval(kCoalesceMs);
    connect(m_flush, &QTimer::timeout, this, &Settings::flush);
}

Settings *Settings::create(QQmlEngine *engine, QJSEngine *)
{
    if (!s_instance) {
        s_instance = new Settings;
        QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    }
    if (!s_instance->m_daemon) {
        s_instance->m_daemon = engine->singletonInstance<Daemon *>(
            QStringLiteral("Ryoku.Ryogami"), QStringLiteral("Daemon"));
        if (s_instance->m_daemon) {
            connect(s_instance->m_daemon, &Daemon::reconnected, s_instance, &Settings::onReconnected);
            connect(s_instance->m_daemon, &Daemon::event, s_instance, &Settings::onEvent);
            if (s_instance->m_daemon->connected())
                s_instance->onReconnected();
        }
    }
    return s_instance;
}

void Settings::setViewportWidth(int width)
{
    if (m_viewportWidth == width)
        return;
    m_viewportWidth = width;
    Q_EMIT viewportWidthChanged();
}

bool Settings::smallScreen() const
{
    return m_viewportWidth > 0 && m_viewportWidth <= kSmallScreenMax;
}

QVariant Settings::userValue(const QString &key) const
{
    const auto it = m_user.constFind(key);
    return it != m_user.constEnd() ? it.value() : QVariant();
}

QVariant Settings::value(const QString &key) const
{
    const auto it = m_user.constFind(key);
    if (it != m_user.constEnd())
        return it.value();
    const auto spec = m_schema.constFind(key);
    if (spec == m_schema.constEnd())
        return QVariant();
    if (smallScreen()) {
        const QVariant small = spec->value(QStringLiteral("defaultSmall"));
        if (small.isValid() && !small.isNull())
            return small;
    }
    return spec->value(QStringLiteral("default"));
}

QVariantMap Settings::spec(const QString &key) const
{
    return m_schema.value(key);
}

QVariant Settings::defaultOf(const QString &key) const
{
    return m_schema.value(key).value(QStringLiteral("default"));
}

void Settings::set(const QString &key, const QVariant &value)
{
    if (m_user.value(key) == value && m_user.contains(key))
        return;
    m_user.insert(key, value);
    m_pending.insert(key, value);
    Q_EMIT changed(key, value);
    if (!m_flush->isActive())
        m_flush->start();
}

void Settings::reset(const QString &key)
{
    const bool had = m_user.remove(key) > 0;
    // A queued write for this key is now stale.
    m_pending.remove(key);
    if (m_daemon) {
        m_daemon->call(QStringLiteral("settings.reset"),
                       QJsonObject{{QStringLiteral("keys"), QJsonArray{key}}}, nullptr);
    }
    if (had)
        Q_EMIT changed(key, value(key));
}

void Settings::flush()
{
    m_flush->stop();
    if (m_pending.isEmpty() || !m_daemon)
        return;
    const QJsonObject values = QJsonObject::fromVariantMap(m_pending);
    m_pending.clear();
    m_daemon->call(QStringLiteral("settings.set"),
                   QJsonObject{{QStringLiteral("values"), values}}, nullptr);
}

void Settings::onReconnected()
{
    fetchSchema();
    fetchValues();
}

void Settings::maybeReady()
{
    if (m_ready || !m_schemaLoaded || !m_valuesLoaded)
        return;
    m_ready = true;
    Q_EMIT readyChanged();
}

void Settings::fetchSchema()
{
    if (!m_daemon)
        return;
    m_daemon->call(QStringLiteral("settings.schema"), QJsonObject{},
                   [this](const QJsonValue &result, const QJsonObject &error) {
        if (!error.isEmpty())
            return;
        const QJsonObject obj = result.toObject();
        m_revision = obj.value(QStringLiteral("revision")).toInt();
        QHash<QString, QVariantMap> schema;
        const QJsonArray keys = obj.value(QStringLiteral("keys")).toArray();
        for (const QJsonValue &k : keys) {
            const QJsonObject spec = k.toObject();
            const QString key = spec.value(QStringLiteral("key")).toString();
            if (key.isEmpty())
                continue;
            schema.insert(key, spec.toVariantMap());
        }
        m_schema = std::move(schema);
        m_caps = obj.value(QStringLiteral("caps")).toObject().toVariantMap();
        m_availability = obj.value(QStringLiteral("availability")).toObject().toVariantMap();
        m_schemaLoaded = true;
        Q_EMIT schemaChanged();
        maybeReady();
    });
}

void Settings::fetchValues()
{
    if (!m_daemon)
        return;
    m_daemon->call(QStringLiteral("settings.get"), QJsonObject{},
                   [this](const QJsonValue &result, const QJsonObject &error) {
        if (!error.isEmpty())
            return;
        const QVariantMap values = result.toObject().value(QStringLiteral("values")).toObject().toVariantMap();
        applyIncoming(values);
        m_valuesLoaded = true;
        maybeReady();
    });
}

void Settings::onEvent(const QString &name, const QVariantMap &data)
{
    if (name != QLatin1String("ryogami.settings.changed"))
        return;
    applyIncoming(data.value(QStringLiteral("values")).toMap());
}

void Settings::applyIncoming(const QVariantMap &values)
{
    for (auto it = values.constBegin(); it != values.constEnd(); ++it) {
        // The daemon's value is authoritative, our own echo included: adopt it and drop any queued write.
        const bool differs = !m_user.contains(it.key()) || m_user.value(it.key()) != it.value();
        m_user.insert(it.key(), it.value());
        m_pending.remove(it.key());
        if (differs)
            Q_EMIT changed(it.key(), it.value());
    }
}
