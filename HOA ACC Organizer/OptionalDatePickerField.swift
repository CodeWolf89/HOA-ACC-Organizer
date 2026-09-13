// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Date picker used for optional date-only fields throughout the app.
///
/// Editing uses `Date` values. Persistence converts them to canonical ISO-8601
/// strings through `ISODateStorage`, preventing free-form date text from being
/// stored in the database.
struct OptionalDatePickerField: View {
    /// The human-readable title displayed for this value.
    let title: String

    /// A two-way binding to selection supplied by the parent view.
    @Binding var selection: Date?

    /// Indicates whether allows clear.
    var allowsClear = true
    /// The date or timestamp associated with default date.
    var defaultDate = Date()

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        if selection != nil {
            ViewThatFits(
                in: .horizontal
            ) {
                horizontalDatePicker

                compactDatePicker
            }
        } else {
            ViewThatFits(
                in: .horizontal
            ) {
                HStack {
                    Text(title)

                    Spacer()

                    setDateButton
                }

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                    setDateButton
                }
            }
        }
    }

    /// The full-width optional-date control used when horizontal space is available.
    private var horizontalDatePicker:
        some View {
        HStack(
            spacing: 12
        ) {
            DatePicker(
                title,
                selection:
                    nonOptionalBinding,
                displayedComponents:
                    [.date]
            )

            clearButton
        }
    }

    /// The compact optional-date control used when horizontal space is limited.
    private var compactDatePicker:
        some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Spacer()

                clearButton
            }

            DatePicker(
                "",
                selection:
                    nonOptionalBinding,
                displayedComponents:
                    [.date]
            )
            .labelsHidden()
        }
    }

    /// The button that removes the currently selected optional date.
    @ViewBuilder
    private var clearButton:
        some View {
        if allowsClear {
            Button {
                selection = nil
            } label: {
                Image(
                    systemName:
                        "xmark.circle.fill"
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .buttonStyle(
                .borderless
            )
            .accessibilityLabel(
                "Clear \(title)"
            )
        }
    }

    /// The button that assigns the default date to an unset optional date.
    private var setDateButton:
        some View {
        Button("Set Date") {
            selection =
                Calendar.current
                    .startOfDay(
                        for:
                            defaultDate
                    )
        }
    }

    /// A binding adapter that lets `DatePicker` edit an optional date value.
    private var nonOptionalBinding:
        Binding<Date> {
        Binding(
            get: {
                selection
                ?? Calendar.current
                    .startOfDay(
                        for:
                            defaultDate
                    )
            },
            set: { value in
                selection =
                    Calendar.current
                        .startOfDay(
                            for: value
                        )
            }
        )
    }
}
