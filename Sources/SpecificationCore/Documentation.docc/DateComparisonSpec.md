# ``SpecificationCore/DateComparisonSpec``

A specification that compares a stored event date to a reference date.

## Overview

`DateComparisonSpec` checks whether an event occurred before or after a specific reference date. This is useful for determining if events happened within certain timeframes, validating chronological ordering, or implementing date-based eligibility rules.

### Key Benefits

- **Event Chronology**: Verify when events occurred relative to dates
- **Simple Comparisons**: Before/after logic with clear semantics
- **Event-Based**: Works with ``EvaluationContext`` event timestamps
- **Eligibility Checking**: Determine if events meet date requirements
- **Deadline Enforcement**: Check if events occurred before deadlines

### When to Use DateComparisonSpec

Use `DateComparisonSpec` when you need to:
- Check if an event occurred before a deadline
- Verify events happened after a start date
- Enforce chronological ordering of events
- Validate event timing for eligibility
- Compare event dates to milestones

## Quick Example

```swift
import SpecificationCore

// Record when user registered
let provider = DefaultContextProvider.shared
provider.recordEvent("user_registered")

// Check if registration was before a cutoff date
let cutoffDate = DateComponents(
    calendar: .current,
    year: 2025,
    month: 12,
    day: 31
).date!

let eligibilitySpec = DateComparisonSpec(
    eventKey: "user_registered",
    comparison: .before,
    date: cutoffDate
)

let context = provider.currentContext()

if eligibilitySpec.isSatisfiedBy(context) {
    grantEarlyAdopterBenefits()
}
```

## Creating DateComparisonSpec

```swift
// Check if event occurred before a date
let beforeSpec = DateComparisonSpec(
    eventKey: "action_taken",
    comparison: .before,
    date: referenceDate
)

// Check if event occurred after a date
let afterSpec = DateComparisonSpec(
    eventKey: "action_taken",
    comparison: .after,
    date: referenceDate
)
```

## Comparison Types

### Before Comparison

Event date must be strictly less than reference date:

```swift
let deadline = Date(timeIntervalSince1970: 2000)
let spec = DateComparisonSpec(
    eventKey: "submission",
    comparison: .before,
    date: deadline
)

// Event at 1500: satisfied ✅ (1500 < 2000)
// Event at 2000: NOT satisfied ❌ (2000 < 2000 is false)
// Event at 2500: NOT satisfied ❌ (2500 < 2000 is false)
```

### After Comparison

Event date must be strictly greater than reference date:

```swift
let startDate = Date(timeIntervalSince1970: 1000)
let spec = DateComparisonSpec(
    eventKey: "enrollment",
    comparison: .after,
    date: startDate
)

// Event at 500: NOT satisfied ❌ (500 > 1000 is false)
// Event at 1000: NOT satisfied ❌ (1000 > 1000 is false)
// Event at 1500: satisfied ✅ (1500 > 1000)
```

## Usage Examples

### Early Registration Benefit

```swift
// Give benefits to users who registered before Jan 1, 2025
let cutoffDate = DateComponents(
    calendar: .current,
    year: 2025,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0
).date!

let earlyUserSpec = DateComparisonSpec(
    eventKey: "user_registered",
    comparison: .before,
    date: cutoffDate
)

@Satisfies(using: earlyUserSpec)
var isEarlyAdopter: Bool

if isEarlyAdopter {
    grantLifetimeDiscount()
}
```

### Contest Deadline

```swift
// Check if submission was before contest deadline
let contestDeadline = DateComponents(
    calendar: .current,
    year: 2025,
    month: 6,
    day: 30,
    hour: 23,
    minute: 59
).date!

let validSubmissionSpec = DateComparisonSpec(
    eventKey: "contest_submission",
    comparison: .before,
    date: contestDeadline
)

func validateSubmission() -> Bool {
    let context = DefaultContextProvider.shared.currentContext()
    return validSubmissionSpec.isSatisfiedBy(context)
}
```

### Beta Access Gate

```swift
// Beta opened on a specific date - check if user enrolled after
let betaStartDate = DateComponents(
    calendar: .current,
    year: 2025,
    month: 3,
    day: 1
).date!

let betaEligibilitySpec = DateComparisonSpec(
    eventKey: "beta_enrollment",
    comparison: .after,
    date: betaStartDate
)

@Satisfies(using: betaEligibilitySpec)
var enrolledDuringBeta: Bool
```

### Milestone Verification

```swift
// Check if milestone was reached after launch date
let launchDate = DateComponents(
    calendar: .current,
    year: 2025,
    month: 1,
    day: 15
).date!

let postLaunchSpec = DateComparisonSpec(
    eventKey: "milestone_reached",
    comparison: .after,
    date: launchDate
)

func trackPostLaunchMilestone() {
    let context = DefaultContextProvider.shared.currentContext()

    if postLaunchSpec.isSatisfiedBy(context) {
        recordAsPostLaunchAchievement()
    }
}
```

## Real-World Examples

### Grandfathered Pricing

```swift
class PricingManager {
    let pricingChangeDate = DateComponents(
        calendar: .current,
        year: 2025,
        month: 7,
        day: 1
    ).date!

    // Users who subscribed before price change get old pricing
    lazy var grandfatheredSpec = DateComparisonSpec(
        eventKey: "subscription_started",
        comparison: .before,
        date: pricingChangeDate
    )

    func getMonthlyPrice(for user: User) -> Decimal {
        let context = DefaultContextProvider.shared.currentContext()

        if grandfatheredSpec.isSatisfiedBy(context) {
            return 9.99  // Old pricing
        } else {
            return 14.99  // New pricing
        }
    }
}
```

### Event Attendance Verification

```swift
struct ConferenceManager {
    let conferenceDate = DateComponents(
        calendar: .current,
        year: 2025,
        month: 9,
        day: 15
    ).date!

    // Check if user registered before conference
    lazy var preRegistrationSpec = DateComparisonSpec(
        eventKey: "conference_registration",
        comparison: .before,
        date: conferenceDate
    )

    // Check if user checked in after conference started
    lazy var attendanceSpec = DateComparisonSpec(
        eventKey: "conference_checkin",
        comparison: .after,
        date: conferenceDate
    )

    func getAttendanceStatus() -> AttendanceStatus {
        let context = DefaultContextProvider.shared.currentContext()

        let preRegistered = preRegistrationSpec.isSatisfiedBy(context)
        let checkedIn = attendanceSpec.isSatisfiedBy(context)

        if preRegistered && checkedIn {
            return .attended
        } else if preRegistered {
            return .registered
        } else {
            return .notRegistered
        }
    }
}
```

### Warranty Validation

```swift
class WarrantyManager {
    func createWarrantySpec(
        purchaseEventKey: String,
        warrantyMonths: Int
    ) -> DateComparisonSpec {
        let purchaseDate = DefaultContextProvider.shared
            .getEvent(purchaseEventKey) ?? Date()

        let expirationDate = Calendar.current.date(
            byAdding: .month,
            value: warrantyMonths,
            to: purchaseDate
        )!

        // Warranty valid if current date is before expiration
        return DateComparisonSpec(
            eventKey: purchaseEventKey,
            comparison: .before,
            date: expirationDate
        )
    }

    func isWarrantyValid(for product: Product) -> Bool {
        let spec = createWarrantySpec(
            purchaseEventKey: "purchase_\(product.id)",
            warrantyMonths: 12
        )

        let context = DefaultContextProvider.shared.currentContext()
        return spec.isSatisfiedBy(context)
    }
}
```

## Missing Event Behavior

If the event doesn't exist, the specification returns `false`:

```swift
let spec = DateComparisonSpec(
    eventKey: "never_recorded",
    comparison: .before,
    date: someDate
)

let context = DefaultContextProvider.shared.currentContext()

// Returns false because event doesn't exist
spec.isSatisfiedBy(context)  // false
```

## Testing

Test date comparisons with ``MockContextProvider``:

```swift
func testEventBefore() {
    let eventDate = Date(timeIntervalSince1970: 1000)
    let referenceDate = Date(timeIntervalSince1970: 2000)

    let provider = MockContextProvider()
        .withEvent("action", date: eventDate)
        .withCurrentDate(Date())

    let spec = DateComparisonSpec(
        eventKey: "action",
        comparison: .before,
        date: referenceDate
    )

    // Event at 1000 is before 2000
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}

func testEventAfter() {
    let eventDate = Date(timeIntervalSince1970: 2000)
    let referenceDate = Date(timeIntervalSince1970: 1000)

    let provider = MockContextProvider()
        .withEvent("action", date: eventDate)

    let spec = DateComparisonSpec(
        eventKey: "action",
        comparison: .after,
        date: referenceDate
    )

    // Event at 2000 is after 1000
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}

func testMissingEvent() {
    let provider = MockContextProvider()

    let spec = DateComparisonSpec(
        eventKey: "never_happened",
        comparison: .before,
        date: Date()
    )

    // Should return false (no event)
    XCTAssertFalse(spec.isSatisfiedBy(provider.currentContext()))
}

func testEventAtBoundary() {
    let date = Date(timeIntervalSince1970: 1000)

    let provider = MockContextProvider()
        .withEvent("action", date: date)

    // Before comparison with same date
    let beforeSpec = DateComparisonSpec(
        eventKey: "action",
        comparison: .before,
        date: date
    )
    XCTAssertFalse(beforeSpec.isSatisfiedBy(provider.currentContext()))

    // After comparison with same date
    let afterSpec = DateComparisonSpec(
        eventKey: "action",
        comparison: .after,
        date: date
    )
    XCTAssertFalse(afterSpec.isSatisfiedBy(provider.currentContext()))
}
```

## Best Practices

### Record Events at the Right Time

```swift
// ✅ Good - record event when it actually happens
func submitEntry() {
    performSubmission()
    DefaultContextProvider.shared.recordEvent("contest_submission")
}

// ❌ Avoid - recording before action completes
func submitEntry() {
    DefaultContextProvider.shared.recordEvent("contest_submission")
    performSubmission()  // Might fail
}
```

### Use Descriptive Event Keys

```swift
// ✅ Good - clear, specific keys
"user_registered"
"subscription_started"
"contest_submission"

// ❌ Avoid - ambiguous keys
"event1"
"date"
"timestamp"
```

### Consider Boundary Cases

```swift
// ✅ Good - handle exact equality explicitly
// Use .before for "must happen before deadline"
// Use .after for "must happen after start"

// ❌ Avoid - assuming equal dates satisfy spec
// Both .before and .after return false for equal dates
```

### Validate Event Exists

```swift
// ✅ Good - check if event exists first
let provider = DefaultContextProvider.shared

if provider.getEvent("important_event") != nil {
    let spec = DateComparisonSpec(
        eventKey: "important_event",
        comparison: .before,
        date: deadline
    )
    // Use spec
}

// Or handle false result appropriately
let result = spec.isSatisfiedBy(context)
if !result {
    // Could be false because event doesn't exist
    // Or because comparison failed
}
```

## Performance Considerations

- **Event Lookup**: O(1) dictionary access
- **Date Comparison**: Simple comparison operator
- **No Computation**: No complex date arithmetic
- **Missing Events**: Fast path returns false immediately

## Topics

### Creating Specifications

- ``init(eventKey:comparison:date:)``

### Comparison Types

- ``Comparison``

## See Also

- <doc:DateRangeSpec>
- <doc:TimeSinceEventSpec>
- <doc:EvaluationContext>
