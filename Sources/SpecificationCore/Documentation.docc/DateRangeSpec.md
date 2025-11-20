# ``SpecificationCore/DateRangeSpec``

A specification that checks if the current date falls within an inclusive date range.

## Overview

`DateRangeSpec` evaluates to true when the current date in the ``EvaluationContext`` is within the specified start and end dates (inclusive). This is useful for implementing time-limited campaigns, seasonal features, or any functionality that should only be active during a specific time period.

### Key Benefits

- **Time-Limited Features**: Enable/disable features during specific periods
- **Campaign Management**: Control promotional campaigns with dates
- **Seasonal Content**: Show content only during relevant seasons
- **Event Windows**: Enforce event start and end times
- **Simple API**: Straightforward date range checking

### When to Use DateRangeSpec

Use `DateRangeSpec` when you need to:
- Run promotional campaigns during specific dates
- Enable seasonal features or content
- Restrict functionality to event windows
- Implement time-limited offers
- Show holiday-specific content

## Quick Example

```swift
import SpecificationCore

// Define campaign dates
let campaignStart = DateComponents(
    calendar: .current,
    year: 2025,
    month: 12,
    day: 1
).date!

let campaignEnd = DateComponents(
    calendar: .current,
    year: 2025,
    month: 12,
    day: 31
).date!

// Create spec for December campaign
let holidayCampaignSpec = DateRangeSpec(
    start: campaignStart,
    end: campaignEnd
)

// Use with context
let context = DefaultContextProvider.shared.currentContext()

if holidayCampaignSpec.isSatisfiedBy(context) {
    showHolidayPromotion()
}
```

## Creating DateRangeSpec

```swift
// Basic creation with start and end dates
let spec = DateRangeSpec(
    start: startDate,
    end: endDate
)

// The range is inclusive: start <= currentDate <= end
```

## How It Works

The specification checks if current date is within the range:

```swift
let start = Date(timeIntervalSince1970: 1000)
let end = Date(timeIntervalSince1970: 2000)
let spec = DateRangeSpec(start: start, end: end)

// Current date = 900: NOT satisfied ❌ (before start)
// Current date = 1000: satisfied ✅ (at start)
// Current date = 1500: satisfied ✅ (in middle)
// Current date = 2000: satisfied ✅ (at end)
// Current date = 2100: NOT satisfied ❌ (after end)
```

## Usage Examples

### Promotional Campaign

```swift
// Black Friday campaign: Nov 24-27, 2025
let blackFridayStart = DateComponents(
    calendar: .current,
    year: 2025,
    month: 11,
    day: 24,
    hour: 0,
    minute: 0
).date!

let blackFridayEnd = DateComponents(
    calendar: .current,
    year: 2025,
    month: 11,
    day: 27,
    hour: 23,
    minute: 59
).date!

let blackFridaySpec = DateRangeSpec(
    start: blackFridayStart,
    end: blackFridayEnd
)

@Satisfies(using: blackFridaySpec)
var isBlackFridayActive: Bool

if isBlackFridayActive {
    applyBlackFridayDiscounts()
}
```

### Seasonal Content

```swift
// Summer content: June 1 - August 31
let summerStart = DateComponents(
    calendar: .current,
    year: Calendar.current.component(.year, from: Date()),
    month: 6,
    day: 1
).date!

let summerEnd = DateComponents(
    calendar: .current,
    year: Calendar.current.component(.year, from: Date()),
    month: 8,
    day: 31,
    hour: 23,
    minute: 59
).date!

let summerSpec = DateRangeSpec(start: summerStart, end: summerEnd)

struct ContentView: View {
    @Satisfies(using: summerSpec)
    var isSummerSeason: Bool

    var body: some View {
        if isSummerSeason {
            SummerThemeView()
        } else {
            DefaultThemeView()
        }
    }
}
```

### Limited-Time Feature

```swift
// Beta feature available for 2 weeks
let betaStart = Date()
let betaEnd = Date().addingTimeInterval(14 * 86400)  // 14 days

let betaSpec = DateRangeSpec(start: betaStart, end: betaEnd)

@Satisfies(using: betaSpec)
var isBetaActive: Bool

func accessBetaFeature() {
    guard isBetaActive else {
        showExpiredMessage()
        return
    }

    showBetaFeature()
}
```

### Event Window

```swift
// Conference dates: March 15-17, 2025
let conferenceStart = DateComponents(
    calendar: .current,
    year: 2025,
    month: 3,
    day: 15,
    hour: 9,
    minute: 0
).date!

let conferenceEnd = DateComponents(
    calendar: .current,
    year: 2025,
    month: 3,
    day: 17,
    hour: 18,
    minute: 0
).date!

let conferenceSpec = DateRangeSpec(
    start: conferenceStart,
    end: conferenceEnd
)

@Satisfies(using: conferenceSpec)
var isConferenceActive: Bool

if isConferenceActive {
    enableLiveStreamFeatures()
}
```

## Real-World Examples

### Multi-Phase Campaign Manager

```swift
struct CampaignManager {
    enum Phase {
        case prelaunch
        case earlyBird
        case regular
        case lastChance
        case ended

        var spec: DateRangeSpec? {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: Date())

            switch self {
            case .prelaunch:
                return DateRangeSpec(
                    start: makeDate(year, 11, 1)!,
                    end: makeDate(year, 11, 14)!
                )
            case .earlyBird:
                return DateRangeSpec(
                    start: makeDate(year, 11, 15)!,
                    end: makeDate(year, 11, 20)!
                )
            case .regular:
                return DateRangeSpec(
                    start: makeDate(year, 11, 21)!,
                    end: makeDate(year, 11, 27)!
                )
            case .lastChance:
                return DateRangeSpec(
                    start: makeDate(year, 11, 28)!,
                    end: makeDate(year, 11, 30)!
                )
            case .ended:
                return nil
            }
        }

        private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date? {
            DateComponents(
                calendar: .current,
                year: year,
                month: month,
                day: day
            ).date
        }
    }

    func getCurrentPhase() -> Phase {
        let context = DefaultContextProvider.shared.currentContext()

        for phase in [Phase.prelaunch, .earlyBird, .regular, .lastChance] {
            if let spec = phase.spec, spec.isSatisfiedBy(context) {
                return phase
            }
        }

        return .ended
    }

    func getDiscount(for phase: Phase) -> Double {
        switch phase {
        case .prelaunch: return 0.30
        case .earlyBird: return 0.25
        case .regular: return 0.15
        case .lastChance: return 0.10
        case .ended: return 0.0
        }
    }
}
```

### Holiday Feature Manager

```swift
struct HolidayFeatureManager {
    struct Holiday {
        let name: String
        let spec: DateRangeSpec
        let theme: Theme
    }

    let holidays: [Holiday] = [
        Holiday(
            name: "Christmas",
            spec: DateRangeSpec(
                start: makeDate(12, 20)!,
                end: makeDate(12, 26)!
            ),
            theme: .christmas
        ),
        Holiday(
            name: "New Year",
            spec: DateRangeSpec(
                start: makeDate(12, 30)!,
                end: makeDate(1, 2)!
            ),
            theme: .newYear
        ),
        Holiday(
            name: "Valentine's Day",
            spec: DateRangeSpec(
                start: makeDate(2, 13)!,
                end: makeDate(2, 15)!
            ),
            theme: .valentines
        )
    ]

    func getCurrentHoliday() -> Holiday? {
        let context = DefaultContextProvider.shared.currentContext()

        return holidays.first { holiday in
            holiday.spec.isSatisfiedBy(context)
        }
    }

    func applyHolidayTheme() {
        if let holiday = getCurrentHoliday() {
            ThemeManager.apply(holiday.theme)
        } else {
            ThemeManager.apply(.default)
        }
    }

    private func makeDate(_ month: Int, _ day: Int) -> Date? {
        let year = Calendar.current.component(.year, from: Date())
        return DateComponents(
            calendar: .current,
            year: year,
            month: month,
            day: day
        ).date
    }
}
```

### Trial Period Manager

```swift
class TrialManager {
    func createTrialSpec(startDate: Date, durationDays: Int) -> DateRangeSpec {
        let endDate = startDate.addingTimeInterval(
            TimeInterval(durationDays * 86400)
        )

        return DateRangeSpec(start: startDate, end: endDate)
    }

    func checkTrialStatus(user: User) -> TrialStatus {
        let trialSpec = createTrialSpec(
            startDate: user.trialStartDate,
            durationDays: 14
        )

        let context = DefaultContextProvider.shared.currentContext()

        if trialSpec.isSatisfiedBy(context) {
            return .active
        } else {
            return .expired
        }
    }
}
```

## Testing

Test date range logic with ``MockContextProvider``:

```swift
func testWithinRange() {
    let start = Date(timeIntervalSince1970: 1000)
    let end = Date(timeIntervalSince1970: 2000)
    let current = Date(timeIntervalSince1970: 1500)

    let provider = MockContextProvider()
        .withCurrentDate(current)

    let spec = DateRangeSpec(start: start, end: end)

    // Should be satisfied (1500 is within 1000-2000)
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}

func testBeforeRange() {
    let start = Date(timeIntervalSince1970: 1000)
    let end = Date(timeIntervalSince1970: 2000)
    let current = Date(timeIntervalSince1970: 500)

    let provider = MockContextProvider()
        .withCurrentDate(current)

    let spec = DateRangeSpec(start: start, end: end)

    // Should NOT be satisfied (500 is before 1000)
    XCTAssertFalse(spec.isSatisfiedBy(provider.currentContext()))
}

func testAfterRange() {
    let start = Date(timeIntervalSince1970: 1000)
    let end = Date(timeIntervalSince1970: 2000)
    let current = Date(timeIntervalSince1970: 2500)

    let provider = MockContextProvider()
        .withCurrentDate(current)

    let spec = DateRangeSpec(start: start, end: end)

    // Should NOT be satisfied (2500 is after 2000)
    XCTAssertFalse(spec.isSatisfiedBy(provider.currentContext()))
}

func testAtBoundaries() {
    let start = Date(timeIntervalSince1970: 1000)
    let end = Date(timeIntervalSince1970: 2000)
    let spec = DateRangeSpec(start: start, end: end)

    // At start boundary
    let atStart = MockContextProvider()
        .withCurrentDate(start)
    XCTAssertTrue(spec.isSatisfiedBy(atStart.currentContext()))

    // At end boundary
    let atEnd = MockContextProvider()
        .withCurrentDate(end)
    XCTAssertTrue(spec.isSatisfiedBy(atEnd.currentContext()))
}
```

## Best Practices

### Use Specific Times for Precision

```swift
// ✅ Good - includes time components for exact boundaries
let start = DateComponents(
    calendar: .current,
    year: 2025,
    month: 12,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0
).date!

let end = DateComponents(
    calendar: .current,
    year: 2025,
    month: 12,
    day: 31,
    hour: 23,
    minute: 59,
    second: 59
).date!

// ❌ Avoid - ambiguous time boundaries
let start = DateComponents(
    calendar: .current,
    year: 2025,
    month: 12,
    day: 1
).date!  // Defaults to midnight, but not explicit
```

### Validate Date Order

```swift
// ✅ Good - validate that start is before end
func createDateRangeSpec(start: Date, end: Date) -> DateRangeSpec? {
    guard start < end else {
        print("Error: Start date must be before end date")
        return nil
    }
    return DateRangeSpec(start: start, end: end)
}

// ❌ Avoid - no validation
let spec = DateRangeSpec(start: endDate, end: startDate)  // Wrong order!
```

### Consider Time Zones

```swift
// ✅ Good - explicit time zone handling
var calendar = Calendar.current
calendar.timeZone = TimeZone(identifier: "America/New_York")!

let start = DateComponents(
    calendar: calendar,
    timeZone: TimeZone(identifier: "America/New_York"),
    year: 2025,
    month: 12,
    day: 1
).date!

// ❌ Avoid - assuming local time zone
let start = DateComponents(year: 2025, month: 12, day: 1).date!
```

## Performance Considerations

- **Simple Comparison**: Uses Date's comparable implementation
- **No Computation**: No complex date arithmetic
- **Inclusive Range**: Uses Swift's ClosedRange operator
- **Context Date**: Uses pre-calculated currentDate from context

## Topics

### Creating Specifications

- ``init(start:end:)``

### Related Types

- ``EvaluationContext``
- ``DateComparisonSpec``
- ``TimeSinceEventSpec``

## See Also

- <doc:DateComparisonSpec>
- <doc:TimeSinceEventSpec>
- <doc:EvaluationContext>
