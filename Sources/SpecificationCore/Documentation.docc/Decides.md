# ``SpecificationCore/Decides``

A property wrapper that evaluates decision specifications and always returns a non-optional result with fallback.

## Overview

`@Decides` transforms decision-based specifications into declarative properties that always return a typed result. Unlike boolean specifications, decision specifications can return any type (strings, numbers, enums, custom types), making them perfect for routing, tier selection, and configuration management.

### Key Benefits

- **Always Non-Optional**: Guaranteed to return a value using fallback when no specification matches
- **Priority-Based**: Uses first-match-wins logic for clear precedence rules
- **Type-Safe Results**: Generic over both context and result types
- **Projected Value Access**: Check if a specification matched via `$propertyName`
- **Flexible Initialization**: Multiple patterns including arrays, builders, and custom logic
- **Composable**: Works with any ``DecisionSpec`` implementation

### When to Use @Decides

Use `@Decides` when you need to:
- Determine user tier, subscription level, or feature access
- Select routing paths, content variants, or UI themes
- Calculate discounts, pricing, or reward values
- Choose configuration based on multiple conditions
- Make priority-based decisions with guaranteed results

## Quick Example

```swift
import SpecificationCore

// Determine user tier with fallback
@Decides([
    (PremiumMemberSpec(), "premium"),
    (StandardMemberSpec(), "standard")
], or: "basic")
var userTier: String

// Usage
let features = getFeatures(for: userTier)  // Always returns a value
```

## Creating @Decides

### With Specification-Result Pairs

```swift
// Array of (Specification, Result) pairs
@Decides([
    (PremiumUserSpec(), 25.0),      // 25% discount
    (LoyalCustomerSpec(), 15.0),    // 15% discount
    (FirstTimeUserSpec(), 10.0)     // 10% discount
], or: 0.0)                          // No discount
var discountPercentage: Double
```

### With DecisionSpec Instance

```swift
let routingSpec = FirstMatchSpec([
    (MobileUserSpec(), "mobile_route"),
    (TabletUserSpec(), "tablet_route")
])

@Decides(using: routingSpec, or: "desktop_route")
var navigationRoute: String
```

### With Builder Pattern

```swift
@Decides(build: { builder in
    builder
        .add(VIPUserSpec(), result: "vip_content")
        .add(PremiumUserSpec(), result: "premium_content")
        .add(TrialUserSpec(), result: "trial_content")
}, or: "free_content")
var contentVariant: String
```

### With Custom Decision Logic

```swift
@Decides(decide: { context in
    let score = context.counter(for: "engagement_score")
    switch score {
    case 80...100: return "high_engagement"
    case 50...79: return "medium_engagement"
    case 20...49: return "low_engagement"
    default: return nil  // Will use fallback
    }
}, or: "no_engagement")
var engagementLevel: String
```

### With Default Value

```swift
// Using wrappedValue for default
@Decides(wrappedValue: "standard", [
    (PremiumUserSpec(), "premium"),
    (BetaUserSpec(), "beta")
])
var userType: String
```

## How It Works

The wrapper evaluates specifications in order and returns the first match:

```swift
@Decides([
    (Spec1(), "result1"),  // Checked first
    (Spec2(), "result2"),  // Checked second
    (Spec3(), "result3")   // Checked third
], or: "default")          // Used if none match

// Priority matters:
// 1. If Spec1 matches → returns "result1"
// 2. Else if Spec2 matches → returns "result2"
// 3. Else if Spec3 matches → returns "result3"
// 4. Else → returns "default"
```

## Usage Examples

### User Tier Selection

```swift
enum UserTier: String {
    case enterprise = "enterprise"
    case premium = "premium"
    case standard = "standard"
    case free = "free"
}

@Decides([
    (SubscriptionStatusSpec(status: .enterprise), UserTier.enterprise),
    (SubscriptionStatusSpec(status: .premium), UserTier.premium),
    (SubscriptionStatusSpec(status: .standard), UserTier.standard)
], or: .free)
var currentTier: UserTier

func getFeatureAccess() -> [Feature] {
    switch currentTier {
    case .enterprise:
        return .all
    case .premium:
        return .premiumFeatures
    case .standard:
        return .standardFeatures
    case .free:
        return .basicFeatures
    }
}
```

### Discount Calculation

```swift
@Decides([
    (BlackFridaySpec(), 50.0),           // 50% off during Black Friday
    (PremiumMemberSpec(), 25.0),         // 25% for premium members
    (LoyalCustomerSpec(), 15.0),         // 15% for loyal customers
    (FirstPurchaseSpec(), 10.0),         // 10% for first purchase
    (NewsletterSubscriberSpec(), 5.0)    // 5% for subscribers
], or: 0.0)
var discountPercentage: Double

func calculateFinalPrice(originalPrice: Double) -> Double {
    return originalPrice * (1.0 - discountPercentage / 100.0)
}
```

### Content Routing

```swift
@Decides([
    (ABTestVariantASpec(), "variant_a_content"),
    (ABTestVariantBSpec(), "variant_b_content"),
    (ABTestVariantCSpec(), "variant_c_content")
], or: "control_content")
var experimentContent: String

@Decides([
    (RegionSpec(region: "EU"), "eu_compliant_content"),
    (RegionSpec(region: "US"), "us_content"),
    (RegionSpec(region: "ASIA"), "asia_content")
], or: "global_content")
var regionalContent: String

func loadContent() {
    let experimentVariant = experimentContent
    let regionalVariant = regionalContent

    display(content: "\(regionalVariant)/\(experimentVariant)")
}
```

### Feature Tier Assignment

```swift
struct FeatureTierManager {
    enum Tier {
        case unlimited
        case professional
        case starter
        case free

        var maxProjects: Int {
            switch self {
            case .unlimited: return .max
            case .professional: return 100
            case .starter: return 10
            case .free: return 3
            }
        }

        var maxStorage: Int { // in GB
            switch self {
            case .unlimited: return 1000
            case .professional: return 100
            case .starter: return 10
            case .free: return 1
            }
        }
    }

    @Decides([
        (SubscriptionStatusSpec(status: .enterprise), Tier.unlimited),
        (SubscriptionStatusSpec(status: .professional), Tier.professional),
        (SubscriptionStatusSpec(status: .starter), Tier.starter)
    ], or: .free)
    var tier: Tier

    func canCreateProject(currentCount: Int) -> Bool {
        return currentCount < tier.maxProjects
    }

    func canUploadFile(currentStorage: Int, fileSize: Int) -> Bool {
        return (currentStorage + fileSize) <= (tier.maxStorage * 1_000_000_000)
    }
}
```

## Projected Value

The projected value provides access to the optional result without fallback:

```swift
@Decides([
    (PremiumUserSpec(), "premium"),
    (StandardUserSpec(), "standard")
], or: "free")
var userType: String

// Regular access always returns a value
print(userType)  // "premium", "standard", or "free"

// Projected value is nil if no specification matched
if let matchedType = $userType {
    print("Specification matched with: \(matchedType)")
    // matchedType is "premium" or "standard"
} else {
    print("No specification matched, using fallback")
    // Used the "free" fallback
}

// Useful for analytics or debugging
func trackUserType() {
    if let matched = $userType {
        analytics.track("user_type_matched", matched)
    } else {
        analytics.track("user_type_defaulted", userType)
    }
}
```

## Real-World Examples

### Pricing Strategy Manager

```swift
class PricingManager {
    enum PricingTier {
        case earlyBird
        case regular
        case lastMinute

        var multiplier: Double {
            switch self {
            case .earlyBird: return 0.7   // 30% off
            case .regular: return 1.0      // Full price
            case .lastMinute: return 1.2   // 20% markup
            }
        }
    }

    @Decides([
        (DateComparisonSpec(
            eventKey: "event_date",
            comparison: .before,
            date: Date().addingTimeInterval(-30 * 86400)  // 30 days before
        ), PricingTier.earlyBird),
        (DateComparisonSpec(
            eventKey: "event_date",
            comparison: .before,
            date: Date().addingTimeInterval(-3 * 86400)   // 3 days before
        ), PricingTier.regular)
    ], or: .lastMinute)
    var pricingTier: PricingTier

    func getPrice(basePrice: Double) -> Double {
        return basePrice * pricingTier.multiplier
    }
}
```

### API Rate Limit Selector

```swift
class APIRateLimitManager {
    struct RateLimit {
        let requestsPerMinute: Int
        let burstSize: Int

        static let free = RateLimit(requestsPerMinute: 10, burstSize: 2)
        static let basic = RateLimit(requestsPerMinute: 60, burstSize: 10)
        static let pro = RateLimit(requestsPerMinute: 600, burstSize: 50)
        static let enterprise = RateLimit(requestsPerMinute: 6000, burstSize: 500)
    }

    @Decides([
        (SubscriptionStatusSpec(status: .enterprise), RateLimit.enterprise),
        (SubscriptionStatusSpec(status: .professional), RateLimit.pro),
        (SubscriptionStatusSpec(status: .basic), RateLimit.basic)
    ], or: .free)
    var currentLimit: RateLimit

    func canMakeRequest() -> Bool {
        let provider = DefaultContextProvider.shared
        let requestsThisMinute = provider.currentContext()
            .counter(for: "requests_this_minute")

        return requestsThisMinute < currentLimit.requestsPerMinute
    }

    func canBurst(requestCount: Int) -> Bool {
        return requestCount <= currentLimit.burstSize
    }
}
```

### Theme Selection System

```swift
struct ThemeManager {
    enum Theme: String {
        case dark = "dark"
        case light = "light"
        case auto = "auto"
        case highContrast = "high_contrast"

        var colors: ColorScheme {
            // Return appropriate color scheme
            switch self {
            case .dark: return .darkColors
            case .light: return .lightColors
            case .auto: return .systemColors
            case .highContrast: return .highContrastColors
            }
        }
    }

    @Decides(decide: { context in
        // User preference takes priority
        if let userTheme = context.userData["theme_preference"] as? String,
           let theme = Theme(rawValue: userTheme) {
            return theme
        }

        // Accessibility setting
        if context.flag(for: "high_contrast_mode") {
            return .highContrast
        }

        // Time-based auto theme
        let hour = Calendar.current.component(.hour, from: context.currentDate)
        if hour >= 18 || hour < 6 {
            return .dark
        } else {
            return .light
        }
    }, or: .auto)
    var currentTheme: Theme

    func applyTheme() {
        UIApplication.shared.updateAppearance(currentTheme.colors)
    }
}
```

### Notification Priority Router

```swift
class NotificationRouter {
    enum Priority: Int {
        case critical = 4
        case high = 3
        case medium = 2
        case low = 1

        var deliveryChannel: [DeliveryChannel] {
            switch self {
            case .critical:
                return [.push, .sms, .email, .inApp]
            case .high:
                return [.push, .email, .inApp]
            case .medium:
                return [.push, .inApp]
            case .low:
                return [.inApp]
            }
        }

        var retryAttempts: Int {
            switch self {
            case .critical: return 5
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
    }

    @Decides(decide: { context in
        let notificationType = context.userData["notification_type"] as? String ?? ""

        switch notificationType {
        case "security_alert":
            return Priority.critical
        case "payment_required":
            return Priority.high
        case "feature_update":
            return Priority.medium
        case "newsletter":
            return Priority.low
        default:
            return nil  // Use fallback
        }
    }, or: .low)
    var notificationPriority: Priority

    func send(notification: Notification) {
        let channels = notificationPriority.deliveryChannel
        let retries = notificationPriority.retryAttempts

        deliver(notification, via: channels, retries: retries)
    }
}
```

## Builder Pattern Usage

Create complex decision logic with the builder API:

```swift
// Build specification inline
@Decides(build: { builder in
    builder
        .add(VIPUserSpec(), result: "vip")
        .add(PremiumUserSpec(), result: "premium")
        .add(FreeUserSpec(), result: "free")
}, or: "guest")
var userCategory: String

// Separate builder construction
let contentBuilder = FirstMatchSpec<EvaluationContext, String>.builder()
contentBuilder
    .add(HolidaySeasonSpec(), result: "holiday_theme")
    .add(UserBirthdaySpec(), result: "birthday_theme")
    .add(NewUserSpec(), result: "welcome_theme")

@Decides(using: contentBuilder.fallback("default_theme").build(), or: "default_theme")
var themeVariant: String
```

## Testing

Test decision logic with ``MockContextProvider``:

```swift
func testTierSelection() {
    let provider = MockContextProvider()
        .withFlag("premium_subscription", value: true)

    @Decides(
        provider: provider,
        firstMatch: [
            (FeatureFlagSpec(flagKey: "enterprise_subscription"), "enterprise"),
            (FeatureFlagSpec(flagKey: "premium_subscription"), "premium")
        ],
        fallback: "free"
    )
    var tier: String

    XCTAssertEqual(tier, "premium")

    // Test fallback
    provider.setFlag("premium_subscription", to: false)
    XCTAssertEqual(tier, "free")

    // Test projected value
    provider.setFlag("premium_subscription", to: true)
    XCTAssertNotNil($tier)
    XCTAssertEqual($tier, "premium")
}

func testProjectedValue() {
    let provider = MockContextProvider()

    @Decides(
        provider: provider,
        firstMatch: [
            (FeatureFlagSpec(flagKey: "special_offer"), "special")
        ],
        fallback: "standard"
    )
    var offerType: String

    // No specification matches - using fallback
    XCTAssertEqual(offerType, "standard")
    XCTAssertNil($offerType)

    // Specification matches
    provider.setFlag("special_offer", to: true)
    XCTAssertEqual(offerType, "special")
    XCTAssertEqual($offerType, "special")
}
```

## Best Practices

### Order Specifications by Priority

```swift
// ✅ Good - most specific first
@Decides([
    (VIPMemberSpec(), "vip"),           // Most specific
    (PremiumMemberSpec(), "premium"),   // More specific
    (RegisteredUserSpec(), "registered") // Least specific
], or: "guest")
var userLevel: String

// ❌ Avoid - wrong order
@Decides([
    (RegisteredUserSpec(), "registered"), // Too broad, matches VIP/Premium too
    (PremiumMemberSpec(), "premium"),
    (VIPMemberSpec(), "vip")
], or: "guest")
var badUserLevel: String  // VIP users will get "registered"!
```

### Use Type-Safe Result Types

```swift
// ✅ Good - enum for type safety
enum AccessLevel {
    case admin, moderator, user, guest
}

@Decides([
    (AdminSpec(), AccessLevel.admin),
    (ModeratorSpec(), AccessLevel.moderator),
    (UserSpec(), AccessLevel.user)
], or: .guest)
var accessLevel: AccessLevel

// ❌ Avoid - stringly-typed
@Decides([
    (AdminSpec(), "admin"),
    (ModeratorSpec(), "moderator"),
    (UserSpec(), "user")
], or: "guest")
var accessString: String  // Typo-prone
```

### Provide Meaningful Fallbacks

```swift
// ✅ Good - sensible default
@Decides([
    (PremiumUserSpec(), 25.0),
    (StandardUserSpec(), 10.0)
], or: 0.0)  // No discount for others
var discount: Double

// ✅ Good - safe fallback
@Decides([
    (HighSecuritySpec(), .twoFactor),
    (MediumSecuritySpec(), .password)
], or: .passwordWithEmail)  // Reasonable security level
var authMethod: AuthMethod

// ❌ Avoid - unsafe fallback
@Decides([
    (AdminSpec(), .fullAccess),
    (UserSpec(), .limitedAccess)
], or: .fullAccess)  // Too permissive!
var access: AccessLevel
```

### Use Projected Value for Analytics

```swift
@Decides([
    (PromoCodeSpec(), "promo_price"),
    (MembershipSpec(), "member_price")
], or: "regular_price")
var pricingStrategy: String

func recordPurchase() {
    if let strategyUsed = $pricingStrategy {
        analytics.track("purchase_with_strategy", ["strategy": strategyUsed])
    } else {
        analytics.track("purchase_regular_price")
    }
}
```

## Performance Considerations

- **First-Match Evaluation**: Stops at first satisfied specification; order matters for performance
- **Specification Order**: Place most likely matches first for better performance
- **Fallback Overhead**: Minimal; fallback value is only used when needed
- **Context Fetching**: Context retrieved once per property access
- **No Caching**: Re-evaluates on each access; consider caching for expensive operations
- **Builder Overhead**: Builder pattern has slight overhead; use direct initialization for simple cases

## Topics

### Creating Property Wrappers

- ``init(provider:using:fallback:)``
- ``init(provider:firstMatch:fallback:)``
- ``init(provider:decide:fallback:)``

### Property Values

- ``wrappedValue``
- ``projectedValue``

## See Also

- <doc:Maybe>
- <doc:Satisfies>
- <doc:DecisionSpec>
- <doc:FirstMatchSpec>
- <doc:EvaluationContext>
