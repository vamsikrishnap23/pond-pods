// Which of the two paths a given PATH and enabled state picks, since headless has no tray.

#include "notifier.hpp"

#include <QtTest/QtTest>
#include <QSignalSpy>
#include <QTemporaryDir>

class TestNotifier : public QObject
{
    Q_OBJECT

    // -a, AirPods, -i, audio-headphones, title, message.
    static constexpr int kExpectedArgCount = 6;

private slots:
    void init()
    {
        m_dir.reset(new QTemporaryDir);
        QVERIFY(m_dir->isValid());
        m_argsFile = m_dir->path() + QStringLiteral("/args");
        qputenv("PATH", m_dir->path().toLocal8Bit());
    }

    void notifySendOnPath_isSpawnedWithTheArguments()
    {
        writeFakeNotifySend();
        Notifier notifier;
        QSignalSpy fallback(&notifier, &Notifier::fallbackRequested);

        notifier.notify(QStringLiteral("Left AirPod Low Battery"), QStringLiteral("10% remaining"));

        // The stub's redirect creates the file before printf fills it, so wait on the content.
        QTRY_VERIFY_WITH_TIMEOUT(readArgs().size() == kExpectedArgCount, 3000);
        const QStringList args = readArgs();
        QCOMPARE(args.value(0), QStringLiteral("-a"));
        QCOMPARE(args.value(1), QStringLiteral("AirPods"));
        QCOMPARE(args.value(2), QStringLiteral("-i"));
        QCOMPARE(args.value(3), Notifier::resolveIcon());
        QCOMPARE(args.value(4), QStringLiteral("Left AirPod Low Battery"));
        QCOMPARE(args.value(5), QStringLiteral("10% remaining"));
        // The tray fallback is for when notify-send is absent, so spawning it must not also fire.
        QCOMPARE(fallback.count(), 0);
    }

    void notifySendMissing_asksForTheTrayFallback()
    {
        Notifier notifier;
        QSignalSpy fallback(&notifier, &Notifier::fallbackRequested);

        notifier.notify(QStringLiteral("AirPods Disconnected"), QStringLiteral("bye"));

        QCOMPARE(fallback.count(), 1);
        QCOMPARE(fallback.first().at(0).toString(), QStringLiteral("AirPods Disconnected"));
        QCOMPARE(fallback.first().at(1).toString(), QStringLiteral("bye"));
    }

    void disabled_doesNeither()
    {
        writeFakeNotifySend();
        Notifier notifier;
        notifier.setEnabled(false);
        QSignalSpy fallback(&notifier, &Notifier::fallbackRequested);

        notifier.notify(QStringLiteral("Left AirPod Low Battery"), QStringLiteral("10% remaining"));

        QTest::qWait(300);
        QVERIFY(!QFile::exists(m_argsFile));
        QCOMPARE(fallback.count(), 0);
    }

    void enabledChanged_onlyFiresOnAChange()
    {
        Notifier notifier;
        QSignalSpy changed(&notifier, &Notifier::enabledChanged);

        notifier.setEnabled(true);
        QCOMPARE(changed.count(), 0);
        notifier.setEnabled(false);
        QCOMPARE(changed.count(), 1);
        notifier.setEnabled(false);
        QCOMPARE(changed.count(), 1);
    }

    void cleanup()
    {
        qunsetenv("PATH");
        m_dir.reset();
    }

private:
    void writeFakeNotifySend()
    {
        const QString path = m_dir->path() + QStringLiteral("/notify-send");
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"" + m_argsFile.toLocal8Bit() + "\"\n");
        f.close();
        QVERIFY(f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));
    }

    // One argument per line: "notification\nsend\n--app-name\nAirPods\n-g\n\uF025\nTitle\nMessage\n"
    QStringList readArgs()
    {
        QFile f(m_argsFile);
        if (!f.open(QIODevice::ReadOnly)) {
            return {};
        }
        return QString::fromUtf8(f.readAll()).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    }

    QScopedPointer<QTemporaryDir> m_dir;
    QString m_argsFile;
};

QTEST_GUILESS_MAIN(TestNotifier)
#include "tst_notifier.moc"
