#pragma once

#include "hold.h"

#include <QAbstractAnimation>
#include <QGuiApplication>
#include <QList>
#include <QMouseEvent>
#include <QPointer>
#include <QVariant>
#include <QWheelEvent>

#include <cmath>
#include <utility>

// A trackpad's scrolling, as a Mac's (DESIGN, Motion): the list follows the
// fingers, glides on when they lift (its speed falling to 0.998 of itself
// each millisecond), and at an end gives like rubber: pulled past it the
// list follows less and less, `(1 − 1 / (x·0.55 / d + 1)) · d` for a pull of
// x in a view d long, and let go it springs home; a glide that reaches an
// end runs over it and comes back the same way.
//
// Qt Quick has none of it on Wayland: a Flickable follows a trackpad and
// stops dead with the fingers (the compositor sends no momentum, and Qt
// makes none), and ours all stop at their ends. So one filter for the whole
// app takes every wheel event that carries a phase (two fingers on a pad;
// a mouse's wheel has none and stays Qt's) before the Flickable it was on
// its way to, and moves that Flickable's content itself. Which Flickable is
// Qt's own choice: the event is taken as Qt hands it to the first one that
// can scroll the way the fingers went, and that one keeps the gesture to
// its end, as a Mac's scroll view does.
//
// Call kitScrolling(&app) once the application object is made. A scroll bar
// of Qt's on the Flickable is shown for as long as we move it; a Flickable
// with a `scrolling` property of its own has it set for the same time (its
// `moving` stays false: Qt isn't the one moving it).
//
// Apps that aren't ours get it too: our widget style calls kitScrolling for
// every Qt app that draws with it (style/src/style.cpp), and the shell by
// importing org.ambrosia.scrolling (style/scrolling). Whoever asks first
// installs it, once an app. A Qt Widgets view (a terminal, a tree, a page
// of text) can't be pulled past its end, but it glides: see
// KitWidgetScrolling below.
//
// AMBROSIA_SCROLLING=trace in the environment writes what it does to the
// log (which list took the fingers, the speed they left at, where the
// list was every tenth of a second after), for a look without a hand on a
// pad; =off leaves Qt's own scrolling.
//
// Fingers put down on the pad stop a glide where it is, as on a Mac: Qt
// hears nothing of fingers that don't move, so that comes by the hold
// gesture, listened for in hold.h. (A list on its way home from past an
// end goes on home.) So do the pointer moving, a click and a key.
class KitScrolling : public QAbstractAnimation
{
public:
    explicit KitScrolling(QGuiApplication *app)
        : QAbstractAnimation(app)
        , m_trace(qgetenv("AMBROSIA_SCROLLING") == "trace")
    {
        app->installEventFilter(this);
    }

    int duration() const override { return -1; }

    // Fingers at rest on the pad (hold.h).
    void held(int fingers)
    {
        if (m_trace)
            qInfo("scrolling: %d finger%s at rest%s", fingers, fingers == 1 ? "" : "s", state() == Running && !m_fingers ? "" : " (nothing gliding)");
        if (m_fingers || state() != Running || !m_owner)
            return;
        for (Axis *axis : {&m_x, &m_y}) {
            if (!axis->on)
                continue;
            const bool vertical = axis == &m_y;
            const Span span = spanOf(m_owner, vertical);
            const double at = placeOf(m_owner, vertical);
            if (at < span.low - 0.5 || at > span.high + 0.5)
                return;
        }
        settle();
    }

protected:
    bool eventFilter(QObject *to, QEvent *event) override
    {
        switch (event->type()) {
        case QEvent::Wheel:
            break;
        case QEvent::MouseMove:
            // A finger back on the pad: the glide ends where it is. (Not
            // for the pointer's twitch as two fingers lift one after the
            // other.)
            if (!m_fingers && state() == Running && to->isWindowType()) {
                if ((static_cast<QMouseEvent *>(event)->globalPosition() - m_pointer).manhattanLength() > 6)
                    settle();
            }
            return false;
        case QEvent::MouseButtonPress:
        case QEvent::KeyPress:
            if (!m_fingers && state() == Running && to->isWindowType())
                settle();
            return false;
        default:
            return false;
        }

        auto *wheel = static_cast<QWheelEvent *>(event);
        const Qt::ScrollPhase phase = wheel->phase();

        if (to->isWindowType()) {
            if (!to->inherits("QQuickWindow"))
                return false;
            switch (phase) {
            case Qt::NoScrollPhase:
                // A wheel's notch: Qt's, from inside the ends.
                if (m_owner)
                    settle();
                return false;
            case Qt::ScrollBegin:
                KitHold::look();
                m_fingers = true;
                m_seeking = true;
                m_samples.clear();
                // What glides goes on until these fingers are found to be
                // on it (take()) or on something else.
                return true;
            case Qt::ScrollUpdate:
                if (!m_fingers) {
                    m_fingers = true;
                    m_seeking = true;
                    m_samples.clear();
                }
                if (!m_seeking && m_owner && m_window == to) {
                    follow(wheel);
                    return true;
                }
                // Into the window, for Qt to say what is under the pointer.
                m_into = to;
                return false;
            case Qt::ScrollEnd:
                // Qt sends a beginning and an end twice over (one event
                // for each direction, as Qt 4 had them): the second end
                // goes the way of the first.
                if (!m_fingers)
                    return m_ours;
                m_fingers = false;
                m_ours = !m_seeking && m_owner;
                m_seeking = false;
                if (m_ours)
                    letGo(wheel);
                return m_ours;
            default:
                return false;
            }
        }

        if (phase == Qt::NoScrollPhase || !to->inherits("QQuickFlickable"))
            return false;
        QObject *list = to;
        if (phase == Qt::ScrollUpdate && m_seeking && takes(list, wheel)) {
            take(list);
            follow(wheel);
            wheel->accept();
            return true;
        }
        // Not this one's to scroll: on to whatever lies behind it. No
        // Flickable sees a trackpad's event itself.
        wheel->ignore();
        return true;
    }

    void updateCurrentTime(int now) override
    {
        if (!m_owner) {
            stop();
            return;
        }
        bool moving = false;
        for (Axis *axis : {&m_x, &m_y}) {
            if (!axis->on || axis->mode == Axis::Still)
                continue;
            const Span span = spanOf(m_owner, axis == &m_y);
            const double t = now - axis->since;
            if (axis->mode == Axis::Coast) {
                const double speed = axis->speed * std::exp(-Fade * t);
                double at = axis->from + axis->speed * (1.0 - std::exp(-Fade * t)) / Fade;
                if (at < span.low || at > span.high) {
                    // Over the end with what speed is left, and back.
                    const double end = at < span.low ? span.low : span.high;
                    axis->mode = Axis::Spring;
                    axis->low = at < span.low;
                    axis->from = at - end;
                    axis->speed = speed * Give;
                    axis->since = now;
                } else if (std::abs(speed) < Rest) {
                    axis->mode = Axis::Still;
                    at = std::round(at);
                }
                place(axis == &m_y, at);
            } else {
                // Critically damped, about the end it is past (or was).
                const double out = (axis->from + (axis->speed + Stiff * axis->from) * t) * std::exp(-Stiff * t);
                const double end = axis->low ? span.low : span.high;
                if (std::abs(out) < 0.5 && t > 30) {
                    axis->mode = Axis::Still;
                    place(axis == &m_y, end);
                } else {
                    place(axis == &m_y, end + out);
                }
            }
            moving = moving || axis->mode != Axis::Still;
        }
        if (m_trace && (now >= m_said + 100 || !moving)) {
            m_said = now;
            qInfo("scrolling: %4d ms at %.0f, %.0f%s", now, placeOf(m_owner, false), placeOf(m_owner, true), moving ? "" : " (rest)");
        }
        if (!moving)
            done();
    }

private:
    // Per millisecond: the glide's fading (−ln 0.998), the speed under which
    // it is over, the spring's stiffness (home in about half a second), and
    // how much of a glide's speed crosses an end (the rubber's first slope).
    static constexpr double Fade = 0.002002;
    static constexpr double Rest = 0.012;
    static constexpr double Stiff = 0.012;
    static constexpr double Give = 0.55;
    static constexpr double Fastest = 12.0;

    struct Axis {
        enum Mode { Still, Coast, Spring };
        bool on = false;
        // Where the fingers have taken the content, past an end or not.
        double raw = 0;
        Mode mode = Still;
        double from = 0;
        double speed = 0;
        double since = 0;
        bool low = false;
    };
    struct Span {
        double low = 0;
        double high = 0;
        double view = 1;
    };
    struct Sample {
        quint64 time;
        QPoint moved;
    };

    static Span spanOf(const QObject *list, bool vertical)
    {
        Span span;
        const double view = list->property(vertical ? "height" : "width").toDouble();
        // Flickable's flickableDirection: 1 is across only, 2 down only.
        const int way = list->property("flickableDirection").toInt();
        if (way == (vertical ? 1 : 2)) {
            span.low = span.high = placeOf(list, vertical);
            span.view = qMax(1.0, view);
            return span;
        }
        double content = list->property(vertical ? "contentHeight" : "contentWidth").toDouble();
        if (content < 0)
            content = view;
        const double origin = list->property(vertical ? "originY" : "originX").toDouble();
        span.low = origin - list->property(vertical ? "topMargin" : "leftMargin").toDouble();
        span.high = origin + content - view + list->property(vertical ? "bottomMargin" : "rightMargin").toDouble();
        if (span.high < span.low)
            span.high = span.low;
        span.view = qMax(1.0, view);
        return span;
    }

    static double band(double pull, double view) { return (1.0 - 1.0 / (pull * 0.55 / view + 1.0)) * view; }
    static double pullFor(double shown, double view)
    {
        shown = qMin(shown, view - 1.0);
        return shown * view / (0.55 * (view - shown));
    }
    static double shownFor(double raw, const Span &span)
    {
        if (raw < span.low)
            return span.low - band(span.low - raw, span.view);
        if (raw > span.high)
            return span.high + band(raw - span.high, span.view);
        return raw;
    }
    static double rawFor(double shown, const Span &span)
    {
        if (shown < span.low)
            return span.low - pullFor(span.low - shown, span.view);
        if (shown > span.high)
            return span.high + pullFor(shown - span.high, span.view);
        return shown;
    }

    static double placeOf(const QObject *list, bool vertical) { return list->property(vertical ? "contentY" : "contentX").toDouble(); }
    void place(bool vertical, double at)
    {
        // On whole pixels: text in a list stays sharp while it moves.
        m_owner->setProperty(vertical ? "contentY" : "contentX", std::round(at));
    }

    // Whether this Flickable has anything to scroll the way the fingers go.
    static bool takes(const QObject *list, const QWheelEvent *wheel)
    {
        if (!list->property("visible").toBool() || !list->property("enabled").toBool() || !list->property("interactive").toBool())
            return false;
        const QPoint moved = wheel->pixelDelta();
        if (moved.isNull())
            return false;
        const Span span = spanOf(list, std::abs(moved.y()) >= std::abs(moved.x()));
        return span.high > span.low + 0.5;
    }

    void take(QObject *list)
    {
        if (m_owner && m_owner != list)
            settle();
        stop();
        m_owner = list;
        m_window = m_into;
        m_seeking = false;
        if (m_trace) {
            const Span span = spanOf(list, true);
            qInfo("scrolling: took %s at %.0f in %.0f to %.0f, %.0f high", list->metaObject()->className(), placeOf(list, true), span.low, span.high,
                  span.view);
        }
        for (Axis *axis : {&m_x, &m_y}) {
            const Span span = spanOf(list, axis == &m_y);
            *axis = Axis();
            axis->on = span.high > span.low + 0.5;
            // Caught out past an end (on its way home): held there.
            axis->raw = rawFor(placeOf(list, axis == &m_y), span);
        }
        show(true);
    }

    void follow(const QWheelEvent *wheel)
    {
        const QPoint moved = wheel->pixelDelta();
        if (m_y.on) {
            m_y.raw -= moved.y();
            place(true, shownFor(m_y.raw, spanOf(m_owner, true)));
        }
        if (m_x.on) {
            m_x.raw -= moved.x();
            place(false, shownFor(m_x.raw, spanOf(m_owner, false)));
        }
        m_samples.append({wheel->timestamp(), moved});
        while (m_samples.size() > 1 && m_samples.constLast().time - m_samples.constFirst().time > 90)
            m_samples.removeFirst();
    }

    void letGo(const QWheelEvent *wheel)
    {
        // The fingers' speed over their last tenth of a second; none if
        // they had stopped before lifting.
        QPointF speed;
        if (m_samples.size() > 1 && wheel->timestamp() - m_samples.constLast().time < 60) {
            QPoint moved;
            for (qsizetype i = 1; i < m_samples.size(); ++i)
                moved += m_samples.at(i).moved;
            const double took = m_samples.constLast().time - m_samples.constFirst().time;
            if (took > 0)
                speed = QPointF(-moved.x() / took, -moved.y() / took);
        }
        m_samples.clear();

        bool moving = false;
        for (Axis *axis : {&m_x, &m_y}) {
            if (!axis->on)
                continue;
            const bool vertical = axis == &m_y;
            const Span span = spanOf(m_owner, vertical);
            const double fast = qBound(-Fastest, vertical ? speed.y() : speed.x(), Fastest);
            axis->since = 0;
            if (axis->raw < span.low || axis->raw > span.high) {
                const double end = axis->raw < span.low ? span.low : span.high;
                const double pull = std::abs(axis->raw - end);
                const double slope = 0.55 / std::pow(pull * 0.55 / span.view + 1.0, 2);
                axis->mode = Axis::Spring;
                axis->low = axis->raw < span.low;
                axis->from = shownFor(axis->raw, span) - end;
                axis->speed = fast * slope;
            } else if (std::abs(fast) > 0.05) {
                axis->mode = Axis::Coast;
                axis->from = axis->raw;
                axis->speed = fast;
            } else {
                axis->mode = Axis::Still;
            }
            moving = moving || axis->mode != Axis::Still;
        }
        if (m_trace)
            qInfo("scrolling: let go at %.0f, %.0f going %.2f, %.2f px/ms", placeOf(m_owner, false), placeOf(m_owner, true), speed.x(), speed.y());
        if (moving) {
            stop();
            m_pointer = wheel->globalPosition();
            m_said = -100;
            start();
        } else {
            done();
        }
    }

    // At once to where it would come to rest inside its ends.
    void settle()
    {
        stop();
        if (m_owner) {
            for (Axis *axis : {&m_x, &m_y}) {
                if (!axis->on)
                    continue;
                const bool vertical = axis == &m_y;
                const Span span = spanOf(m_owner, vertical);
                place(vertical, qBound(span.low, placeOf(m_owner, vertical), span.high));
            }
        }
        done();
    }

    void done()
    {
        stop();
        show(false);
        m_x = Axis();
        m_y = Axis();
        m_owner = nullptr;
    }

    void show(bool on)
    {
        if (!m_owner)
            return;
        // Qt's scroll bars, by the object `ScrollBar.vertical:` hangs on
        // the Flickable.
        const auto children = m_owner->children();
        for (QObject *child : children) {
            if (!child->inherits("QQuickScrollBarAttached"))
                continue;
            for (const char *side : {"vertical", "horizontal"}) {
                if (auto *bar = child->property(side).value<QObject *>())
                    bar->setProperty("active", on);
            }
        }
        if (m_owner->property("scrolling").isValid())
            m_owner->setProperty("scrolling", on);
    }

    // The Flickable that has the fingers or glides, and its window. Both
    // by their properties alone: nothing here needs Qt Quick to build, so
    // a plugin without it (our widget style) can bring the same scrolling
    // to an app that isn't ours.
    QPointer<QObject> m_owner;
    QPointer<QObject> m_window;
    QPointer<QObject> m_into;
    bool m_fingers = false;
    bool m_seeking = false;
    bool m_ours = false;
    QPointF m_pointer;
    const bool m_trace;
    int m_said = 0;
    Axis m_x;
    Axis m_y;
    QList<Sample> m_samples;
};

// The glide for a Qt Widgets app, whose views scroll by their scroll bars:
// while two fingers move, the scroll bars of the window that move with them
// are noted, and how far each goes for a pixel of the fingers' way (a
// terminal's goes a line for many, a page of text's one for one); when the
// fingers lift, each is carried on by the same fading speed as a list of
// ours. Nothing is taken from Qt here: the fingers' own events scroll as
// they always did, and a view stops at its end.
class KitWidgetScrolling : public QAbstractAnimation
{
public:
    explicit KitWidgetScrolling(QGuiApplication *app)
        : QAbstractAnimation(app)
        , m_trace(qgetenv("AMBROSIA_SCROLLING") == "trace")
    {
        app->installEventFilter(this);
    }

    int duration() const override { return -1; }

    // Fingers at rest on the pad (hold.h).
    void held()
    {
        if (!m_fingers && state() == Running)
            stop();
    }

protected:
    bool eventFilter(QObject *to, QEvent *event) override
    {
        switch (event->type()) {
        case QEvent::Wheel:
            break;
        case QEvent::MouseMove:
            if (state() == Running && to->isWindowType()
                && (static_cast<QMouseEvent *>(event)->globalPosition() - m_pointer).manhattanLength() > 6)
                stop();
            return false;
        case QEvent::MouseButtonPress:
        case QEvent::KeyPress:
            if (state() == Running && to->isWindowType())
                stop();
            return false;
        default:
            return false;
        }

        auto *wheel = static_cast<QWheelEvent *>(event);
        const Qt::ScrollPhase phase = wheel->phase();
        if (to->isWindowType()) {
            if (!to->inherits("QWidgetWindow"))
                return false;
            if (phase == Qt::ScrollBegin || phase == Qt::NoScrollPhase || (phase == Qt::ScrollUpdate && !m_fingers)) {
                if (phase == Qt::ScrollBegin)
                    KitHold::look();
                stop();
                m_fingers = phase != Qt::NoScrollPhase;
                m_looked = false;
                m_moved = QPoint();
                m_samples.clear();
                m_bars.clear();
            }
            if (phase == Qt::ScrollUpdate) {
                m_moved += wheel->pixelDelta();
                m_samples.append({wheel->timestamp(), wheel->pixelDelta()});
                while (m_samples.size() > 1 && m_samples.constLast().time - m_samples.constFirst().time > 90)
                    m_samples.removeFirst();
            } else if (phase == Qt::ScrollEnd && m_fingers) {
                // (The end comes twice, as the beginning does.)
                m_fingers = false;
                letGo(wheel);
            }
            return false;
        }

        // The first widget the fingers' first move is handed to: where its
        // window's scroll bars stand before any of it is done.
        if (m_fingers && !m_looked && phase == Qt::ScrollUpdate && to->isWidgetType()) {
            m_looked = true;
            QObject *top = to;
            while (top->parent() && top->parent()->isWidgetType())
                top = top->parent();
            const auto all = top->findChildren<QObject *>();
            // (Hidden ones too: a terminal told to show none still has it.)
            for (QObject *one : all) {
                if (one->inherits("QScrollBar"))
                    m_bars.append({one, one->property("value").toInt()});
            }
        }
        return false;
    }

    void updateCurrentTime(int now) override
    {
        const double gone = (1.0 - std::exp(-Fade * now)) / Fade;
        bool moving = false;
        for (Bar &bar : m_bars) {
            // (Moved by anything else since: no longer ours to carry.)
            if (!bar.bar || bar.over || bar.bar->property("value").toInt() != bar.set) {
                bar.over = true;
                continue;
            }
            const double to = bar.from + bar.each * bar.speed * gone;
            const int low = bar.bar->property("minimum").toInt();
            const int high = bar.bar->property("maximum").toInt();
            const int set = qBound(low, qRound(to), high);
            if (set != bar.set) {
                bar.bar->setProperty("value", set);
                bar.set = bar.bar->property("value").toInt();
            }
            bar.over = to < low || to > high || std::abs(bar.speed) * std::exp(-Fade * now) < Rest;
            moving = moving || !bar.over;
        }
        if (m_trace && (now >= m_said + 100 || !moving) && !m_bars.isEmpty()) {
            m_said = now;
            qInfo("scrolling: %4d ms a scroll bar at %d%s", now, m_bars.constFirst().set, moving ? "" : " (rest)");
        }
        if (!moving)
            stop();
    }

private:
    static constexpr double Fade = 0.002002;
    static constexpr double Rest = 0.012;
    static constexpr double Fastest = 12.0;

    struct Bar {
        QPointer<QObject> bar;
        // Where it stood when the fingers came, then where they left it.
        int from = 0;
        // What it moves for a pixel of the fingers' way, and their speed
        // along it when they lifted.
        double each = 0;
        double speed = 0;
        int set = 0;
        bool over = false;
    };
    struct Sample {
        quint64 time;
        QPoint moved;
    };

    void letGo(const QWheelEvent *wheel)
    {
        QPointF speed;
        if (m_samples.size() > 1 && wheel->timestamp() - m_samples.constLast().time < 60) {
            QPoint moved;
            for (qsizetype i = 1; i < m_samples.size(); ++i)
                moved += m_samples.at(i).moved;
            const double took = m_samples.constLast().time - m_samples.constFirst().time;
            if (took > 0)
                speed = QPointF(moved.x() / took, moved.y() / took);
        }
        m_samples.clear();

        QList<Bar> carried;
        for (Bar bar : std::as_const(m_bars)) {
            if (!bar.bar)
                continue;
            // Qt::Vertical is 2.
            const bool vertical = bar.bar->property("orientation").toInt() == 2;
            const double moved = vertical ? m_moved.y() : m_moved.x();
            const double fast = qBound(-Fastest, vertical ? speed.y() : speed.x(), Fastest);
            const int now = bar.bar->property("value").toInt();
            if (now == bar.from || std::abs(moved) < 8 || std::abs(fast) < 0.05)
                continue;
            bar.each = (now - bar.from) / moved;
            bar.speed = fast;
            bar.from = bar.set = now;
            carried.append(bar);
            if (m_trace)
                qInfo("scrolling: a %s let go at %d going %.2f px/ms, %.3f a pixel", bar.bar->metaObject()->className(), now, fast, bar.each);
        }
        m_bars = carried;
        if (!m_bars.isEmpty()) {
            m_pointer = wheel->globalPosition();
            m_said = -100;
            start();
        }
    }

    bool m_fingers = false;
    bool m_looked = false;
    QPoint m_moved;
    QPointF m_pointer;
    QList<Sample> m_samples;
    QList<Bar> m_bars;
    const bool m_trace;
    int m_said = 0;
};

inline void kitScrolling(QGuiApplication *app)
{
    // Once an app, whoever asks: its own main(), the widget style it draws
    // with, or a QML import. Only where a trackpad's events come with their
    // phases (Qt's Wayland), which also leaves the compositor itself alone.
    if (!app || app->property("_ambrosia_scrolling").toBool())
        return;
    app->setProperty("_ambrosia_scrolling", true);
    if (qgetenv("AMBROSIA_SCROLLING") == "off" || QGuiApplication::platformName() != QLatin1String("wayland"))
        return;
    auto *lists = new KitScrolling(app);
    auto *views = new KitWidgetScrolling(app);
    KitHold::listen([lists, views](int fingers) {
        lists->held(fingers);
        views->held();
    });
}
