#pragma once

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QObject>
#include <QProcess>
#include <QStandardPaths>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Split out of TrayIconManager so a headless run still gets user-visible toasts.
class Notifier : public QObject
{
    Q_OBJECT

public:
    explicit Notifier(QObject *parent = nullptr) : QObject(parent) {}

    bool enabled() const { return m_enabled; }

    void setEnabled(bool enabled)
    {
        if (m_enabled != enabled)
        {
            m_enabled = enabled;
            emit enabledChanged(enabled);
        }
    }

    static QString resolveIcon()
    {
        const QString home = QDir::homePath();
        const QString shareIcon = home + QStringLiteral("/.local/share/icons/airpods.png");
        if (QFile::exists(shareIcon)) {
            return shareIcon;
        }
        const QString hicolorIcon = home + QStringLiteral("/.local/share/icons/hicolor/512x512/apps/airpods.png");
        if (QFile::exists(hicolorIcon)) {
            return hicolorIcon;
        }
        const QString scalableIcon = home + QStringLiteral("/.local/share/icons/hicolor/scalable/apps/airpods.png");
        if (QFile::exists(scalableIcon)) {
            return scalableIcon;
        }
        const QString devAsset = home + QStringLiteral("/Projects/pond-pods/daemon/assets/airpods_straight.png");
        if (QFile::exists(devAsset)) {
            return devAsset;
        }
        const QString rootAsset = home + QStringLiteral("/Projects/pond-pods/airpods_straight.png");
        if (QFile::exists(rootAsset)) {
            return rootAsset;
        }
        return QStringLiteral("airpods");
    }

    void notify(const QString &title, const QString &message)
    {
        if (!m_enabled) {
            return;
        }

        const QString iconPath = resolveIcon();

        // Direct Freedesktop D-Bus notification for desktop shells (e.g. Quickshell / Pond)
        if (QDBusConnection::sessionBus().isConnected()) {
            QDBusMessage msg = QDBusMessage::createMethodCall(
                QStringLiteral("org.freedesktop.Notifications"),
                QStringLiteral("/org/freedesktop/Notifications"),
                QStringLiteral("org.freedesktop.Notifications"),
                QStringLiteral("Notify")
            );

            QVariantMap hints;
            if (message.contains(QStringLiteral("Disconnected"), Qt::CaseInsensitive)) {
                hints.insert(QStringLiteral("sound-name"), QStringLiteral("device-removed"));
                hints.insert(QStringLiteral("category"), QStringLiteral("device"));
            } else if (message.contains(QStringLiteral("Low"), Qt::CaseInsensitive)
                       || title.contains(QStringLiteral("Low"), Qt::CaseInsensitive)) {
                hints.insert(QStringLiteral("urgency"), uchar(1));
                hints.insert(QStringLiteral("category"), QStringLiteral("device.battery"));
            }

            QVariantList args;
            args << QStringLiteral("AirPods");                     // app_name
            args << quint32(0);                                    // replaces_id
            args << iconPath;                                      // app_icon
            args << title;                                         // summary (Header in Pond)
            args << message;                                       // body (Main text in Pond)
            args << QStringList();                                 // actions
            args << hints;                                         // hints
            args << qint32(-1);                                    // expire_timeout (-1 = default)

            msg.setArguments(args);
            if (QDBusConnection::sessionBus().send(msg)) {
                return;
            }
        }

        // Fallback to notify-send CLI if D-Bus session is unavailable
        const QString notifySend = QStandardPaths::findExecutable(QStringLiteral("notify-send"));
        if (!notifySend.isEmpty()) {
            QProcess::startDetached(notifySend, {
                QStringLiteral("-a"), QStringLiteral("AirPods"),
                QStringLiteral("-i"), iconPath,
                title, message
            });
            return;
        }

        emit fallbackRequested(title, message);
    }

signals:
    void enabledChanged(bool enabled);
    void fallbackRequested(const QString &title, const QString &message);

private:
    bool m_enabled = true;
};
