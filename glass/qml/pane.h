// SPDX-FileCopyrightText: 2026 Justin Lee
// SPDX-License-Identifier: MIT

#pragma once

#include <QQuickItem>

namespace Ambrosia
{

// A pane of glass: an item that draws nothing and tells the compositor that
// what is behind it, inside its rounded outline, is to be seen through a
// material (ambrosia_glass_v1; Ambrosia's KWin effect draws it). The pane
// follows the item wherever it goes: its place in the window, what clips it,
// how far it has faded, whether it shows at all.
//
// Where the compositor has no such effect it does nothing, and whatever blur
// region the window asks for otherwise stands.
class GlassPane : public QQuickItem
{
    Q_OBJECT
    // One of the design's materials by name: thin, regular, thick, clear,
    // backdrop.
    Q_PROPERTY(QString material READ material WRITE setMaterial NOTIFY materialChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)

public:
    explicit GlassPane(QQuickItem *parent = nullptr);
    ~GlassPane() override;

    QString material() const;
    void setMaterial(const QString &material);
    qreal radius() const;
    void setRadius(qreal radius);

    /// The material's number in the protocol.
    int materialNumber() const;

Q_SIGNALS:
    void materialChanged();
    void radiusChanged();

protected:
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    void changed();

    QString m_material = QStringLiteral("regular");
    qreal m_radius = 0;
    QQuickWindow *m_window = nullptr;
};

} // namespace Ambrosia
