# ``SpecificationCore/Maybe``

A property wrapper that evaluates decision specifications and returns an optional result without requiring a fallback.

## Overview

`@Maybe` is the optional counterpart to ``Decides``. It evaluates decision specifications and returns the result if a specification is satisfied, or `nil` if no specification matches. This is ideal when you want to explicitly handle the "no match" case without providing a default value.

### Key Benefits

- **Optional Results**: Returns `nil` when no specification matches instead of requiring a fallback
- **Priority-Based**: Uses first-match-wins logic like ``Decides``
- **Type-Safe**: Generic over both context and result types
- **No Fallback Required**: Cleaner API when you want to handle `nil` explicitly
- **Flexible Patterns**: Supports arrays, decision specs, and custom logic
- **Builder Support**: Create complex decision trees with fluent API

### When to Use @Maybe

Use `@Maybe` when you need to:
- Detect when no specification matched (explicitly handle `nil`)
- Provide optional features or enhancements
- Conditionally apply logic only when criteria are met
- Distinguish between "no match" and a default value
- Implement optional routing or content variants

## Quick Example

```swift
import SpecificationCore

// Optional theme based on conditions
@Maybe([
    (PremiumUserSpec(), "premium_theme"),
    (HolidaySeasonSpec(), "holiday_theme"),
    (BetaUserSpec(), "experimental_theme")
])
var specialTheme: String?

// Usage
if let theme = specialTheme {
    applyTheme(theme)
} else {
    useDefaultTheme()
}
```

## Creating @Maybe

### With Specification-Result Pairs

```swift
// Array of (Specification, Result) pairs
@Maybe([
    (FirstTimeUserSpec(), 0.20),      // 20% for new users
    (VIPMemberSpec(), 0.15),          // 15% for VIP
    (FlashSaleSpec(), 0.10)           // 10% during flash sale
])
var discount: Double?

let finalPrice = originalPrice * (1.0 - (discount ?? 0.0))
```

### With DecisionSpec Instance

```swift
let personalizationSpec = FirstMatchSpec([
    (UserPreferenceSpec(theme: .dark), "dark_mode_content"),
    (TimeOfDaySpec(after: 18), "evening_content"),
    (WeatherConditionSpec(.rainy), "cozy_content")
])

@Maybe(using: personalizationSpec)
var personalizedContent: String?
```

### With Custom Decision Logic

```swift
@Maybe(decide: { context in
    let score = context.counter(for: "engagement_score")
    guard score > 0 else { return nil }

    switch score {
    case 90...100: return "gold_badge"
    case 70...89: return "silver_badge"
    case 50...69: return "bronze_badge"
    default: return nil
    }
})
var achievementBadge: String?
```

## How It Works

The wrapper evaluates specifications in order and returns the first match or `nil`:

```swift
@Maybe([
    (Spec1(), "result1"),  // Checked first
    (Spec2(), "result2"),  // Checked second
    (Spec3(), "result3")   // Checked third
])
var result: String?

// Evaluation logic:
// 1. If Spec1 matches → returns "result1"
// 2. Else if Spec2 matches → returns "result2"
// 3. Else if Spec3 matches → returns "result3"
// 4. Else → returns nil
```

## Usage Examples

### Optional Feature Selection

```swift
@Maybe([
    (ABTestVariantASpec(), "variant_a_feature"),
    (ABTestVariantBSpec(), "variant_b_feature")
])
var experimentalFeature: String?

func setupFeatures() {
    // Only enable if user is in experiment
    if let feature = experimentalFeature {
        enableFeature(feature)
    }
    // If nil, skip experimental features entirely
}
```

### Conditional Discounts

```swift
@Maybe([
    (LoyaltyRewardSpec(), 30.0),        // 30% loyalty reward
    (ReferralDiscountSpec(), 20.0),     // 20% referral
    (SeasonalPromotionSpec(), 15.0)     // 15% seasonal
])
var promotionalDiscount: Double?

func calculatePrice(basePrice: Double) -> Double {
    if let discount = promotionalDiscount {
        return basePrice * (1.0 - discount / 100.0)
    }
    return basePrice  // No discount applied
}
```

### Optional Content Routing

```swift
@Maybe([
    (RegionalContentSpec(region: "EU"), "eu_gdpr_content"),
    (RegionalContentSpec(region: "CA"), "canada_content"),
    (RegionalContentSpec(region: "UK"), "uk_content")
])
var regionalContent: String?

let contentToShow = regionalContent ?? standardGlobalContent
```

### Achievement System

```swift
@Maybe(decide: { context in
    let completedTasks = context.counter(for: "completed_tasks")
    let perfectScore = context.flag(for: "perfect_score")
    let speedBonus = context.flag(for: "speed_bonus")

    if perfectScore && speedBonus {
        return "legendary_achievement"
    } else if completedTasks >= 100 {
        return "master_achievement"
    } else if completedTasks >= 50 {
        return "expert_achievement"
    } else if completedTasks >= 10 {
        return "novice_achievement"
    }

    return nil  // No achievement yet
})
var currentAchievement: String?
```

### Personalization Engine

```swift
@Maybe([
    (UserSegmentSpec(segment: "power_user"), "advanced_dashboard"),
    (UserSegmentSpec(segment: "new_user"), "guided_dashboard"),
    (UserSegmentSpec(segment: "returning_user"), "quick_access_dashboard")
])
var customDashboard: String?

func loadDashboard() {
    if let dashboard = customDashboard {
        loadCustomDashboard(dashboard)
        analytics.track("custom_dashboard_loaded", ["type": dashboard])
    } else {
        loadStandardDashboard()
        analytics.track("standard_dashboard_loaded")
    }
}
```

## Comparison with @Decides

The key difference is how they handle "no match":

```swift
// @Maybe - returns nil when no specification matches
@Maybe([
    (PremiumUserSpec(), "premium_feature")
])
var optionalFeature: String?  // Can be nil

if let feature = optionalFeature {
    enableFeature(feature)  // Only runs if spec matched
}

// @Decides - always returns a value with fallback
@Decides([
    (PremiumUserSpec(), "premium_feature")
], or: "basic_feature")
var guaranteedFeature: String  // Never nil

let feature = guaranteedFeature  // Always has a value
enableFeature(feature)
```

When to use which:

- **Use @Maybe** when `nil` has meaning (feature disabled, no match, skip logic)
- **Use @Decides** when you always need a value (routing, tier selection, configuration)

## Real-World Examples

### Promotional Banner System

```swift
class BannerManager {
    @Maybe([
        (DateRangeSpec(start: blackFridayStart, end: blackFridayEnd), "black_friday_banner"),
        (DateRangeSpec(start: cyberMondayStart, end: cyberMondayEnd), "cyber_monday_banner"),
        (NewUserSpec(), "welcome_banner"),
        (InactiveUserSpec(), "comeback_banner")
    ])
    var activeBanner: String?

    func updateUI() {
        if let banner = activeBanner {
            showBanner(banner)
            trackBannerImpression(banner)
        } else {
            hideBannerArea()
        }
    }
}
```

### Feature Upgrade Prompt

```swift
struct UpgradePromptManager {
    enum PromptType {
        case urgentUpgrade
        case softUpsell
        case featureAwareness

        var message: String {
            switch self {
            case .urgentUpgrade:
                return "Upgrade now to continue using premium features"
            case .softUpsell:
                return "Unlock more features with premium"
            case .featureAwareness:
                return "Did you know premium users get..."
            }
        }

        var priority: Int {
            switch self {
            case .urgentUpgrade: return 3
            case .softUpsell: return 2
            case .featureAwareness: return 1
            }
        }
    }

    @Maybe(decide: { context in
        let isFreeTier = context.flag(for: "free_tier")
        let trialExpired = context.flag(for: "trial_expired")
        let usageCount = context.counter(for: "premium_feature_attempts")

        if trialExpired {
            return PromptType.urgentUpgrade
        } else if isFreeTier && usageCount >= 5 {
            return PromptType.softUpsell
        } else if isFreeTier && usageCount >= 2 {
            return PromptType.featureAwareness
        }

        return nil  // Don't show prompt
    })
    var upgradePrompt: PromptType?

    func checkAndShowPrompt() {
        guard let prompt = upgradePrompt else {
            return  // No prompt needed
        }

        showUpgradePrompt(message: prompt.message, priority: prompt.priority)
    }
}
```

### Contextual Help System

```swift
class HelpSystemManager {
    struct HelpContext {
        let screen: String
        let topic: String
        let priority: Int
    }

    @Maybe(decide: { context in
        let currentScreen = context.userData["current_screen"] as? String ?? ""
        let sessionDuration = context.timeSinceLaunch

        // Show help after 30 seconds on complex screens
        switch currentScreen {
        case "advanced_settings":
            if sessionDuration > 30 {
                return HelpContext(
                    screen: "advanced_settings",
                    topic: "settings_guide",
                    priority: 2
                )
            }
        case "first_time_setup":
            return HelpContext(
                screen: "first_time_setup",
                topic: "getting_started",
                priority: 3
            )
        case "payment_screen":
            if sessionDuration > 60 {
                return HelpContext(
                    screen: "payment",
                    topic: "payment_help",
                    priority: 3
                )
            }
        default:
            break
        }

        return nil  // No help needed
    })
    var contextualHelp: HelpContext?

    func updateHelpOverlay() {
        if let help = contextualHelp {
            showHelpButton(for: help.topic, priority: help.priority)
        } else {
            hideHelpButton()
        }
    }
}
```

### Email Notification Selector

```swift
class EmailNotificationManager {
    enum EmailTemplate {
        case welcomeSeries
        case productUpdate
        case specialOffer
        case reEngagement

        var templateId: String {
            switch self {
            case .welcomeSeries: return "welcome_email_v2"
            case .productUpdate: return "product_update_template"
            case .specialOffer: return "special_offer_template"
            case .reEngagement: return "re_engagement_email"
            }
        }

        var sendDelay: TimeInterval {
            switch self {
            case .welcomeSeries: return 0
            case .productUpdate: return 3600
            case .specialOffer: return 0
            case .reEngagement: return 86400
            }
        }
    }

    @Maybe([
        (TimeSinceEventSpec(eventKey: "user_registered", hours: 1), EmailTemplate.welcomeSeries),
        (FeatureFlagSpec(flagKey: "new_product_launch"), EmailTemplate.productUpdate),
        (DateRangeSpec(start: promotionStart, end: promotionEnd), EmailTemplate.specialOffer),
        (TimeSinceEventSpec(eventKey: "last_login", days: 30), EmailTemplate.reEngagement)
    ])
    var pendingEmail: EmailTemplate?

    func processEmailQueue() {
        guard let email = pendingEmail else {
            return  // No emails to send
        }

        scheduleEmail(
            template: email.templateId,
            delay: email.sendDelay
        )

        // Record that we sent this email
        DefaultContextProvider.shared
            .recordEvent("email_sent_\(email.templateId)")
    }
}
```

## Builder Pattern

Create complex optional decisions with the builder API:

```swift
let contentBuilder = Maybe<EvaluationContext, String>.builder(
    provider: DefaultContextProvider.shared
)

let wrappedValue = contentBuilder
    .with(HolidaySpec(), result: "holiday_content")
    .with(BirthdaySpec(), result: "birthday_content")
    .with(NewUserSpec(), result: "welcome_content")
    .build()

@Maybe(using: wrappedValue)
var specialContent: String?
```

## Projected Value

Both `wrappedValue` and `projectedValue` return the same optional result:

```swift
@Maybe([
    (SpecialEventSpec(), "special_event_theme")
])
var eventTheme: String?

// Both provide the same value
let theme1 = eventTheme
let theme2 = $eventTheme

// Both are nil if no spec matches
if theme1 == nil && theme2 == nil {
    print("No special theme active")
}
```

## Testing

Test optional decision logic with ``MockContextProvider``:

```swift
func testOptionalFeature() {
    let provider = MockContextProvider()

    @Maybe(
        provider: provider,
        firstMatch: [
            (FeatureFlagSpec(flagKey: "special_feature"), "special")
        ]
    )
    var feature: String?

    // No flag set - should be nil
    XCTAssertNil(feature)

    // Enable flag - should return result
    provider.setFlag("special_feature", to: true)
    XCTAssertEqual(feature, "special")

    // Disable flag - should be nil again
    provider.setFlag("special_feature", to: false)
    XCTAssertNil(feature)
}

func testDecisionPriority() {
    let provider = MockContextProvider()
        .withFlag("premium", value: true)
        .withFlag("beta", value: true)

    @Maybe(
        provider: provider,
        firstMatch: [
            (FeatureFlagSpec(flagKey: "premium"), "premium_content"),
            (FeatureFlagSpec(flagKey: "beta"), "beta_content")
        ]
    )
    var content: String?

    // Premium has priority over beta
    XCTAssertEqual(content, "premium_content")

    // Disable premium, beta should now match
    provider.setFlag("premium", to: false)
    XCTAssertEqual(content, "beta_content")

    // Disable both, should be nil
    provider.setFlag("beta", to: false)
    XCTAssertNil(content)
}

func testCustomDecision() {
    let provider = MockContextProvider()
        .withCounter("score", value: 85)

    @Maybe(
        provider: provider,
        decide: { context in
            let score = context.counter(for: "score")
            if score >= 90 {
                return "gold"
            } else if score >= 70 {
                return "silver"
            } else if score >= 50 {
                return "bronze"
            }
            return nil
        }
    )
    var badge: String?

    XCTAssertEqual(badge, "silver")

    provider.setCounter("score", to: 95)
    XCTAssertEqual(badge, "gold")

    provider.setCounter("score", to: 30)
    XCTAssertNil(badge)
}
```

## Best Practices

### Order Specifications Correctly

```swift
// ✅ Good - most specific first
@Maybe([
    (VIPEventSpec(), "exclusive_vip_content"),
    (PremiumEventSpec(), "premium_content"),
    (PublicEventSpec(), "public_content")
])
var eventContent: String?

// ❌ Avoid - wrong order
@Maybe([
    (PublicEventSpec(), "public_content"),  // Too broad
    (PremiumEventSpec(), "premium_content"),
    (VIPEventSpec(), "exclusive_vip_content")
])
var badContent: String?  // VIP users get public content!
```

### Handle Nil Appropriately

```swift
// ✅ Good - explicit nil handling
@Maybe([
    (PromoCodeSpec(), "promo_banner")
])
var banner: String?

if let bannerType = banner {
    showBanner(bannerType)
} else {
    // Explicitly handle no banner case
    hidePromotionalSection()
}

// ✅ Good - nil coalescing with default
let contentVariant = banner ?? "default_banner"

// ⚠️ Consider - force unwrapping risks
// let content = banner!  // Crashes if nil!
```

### Use Type-Safe Results

```swift
// ✅ Good - enum for type safety
enum BadgeLevel {
    case platinum, gold, silver, bronze
}

@Maybe([
    (HighScoreSpec(), BadgeLevel.platinum),
    (GoodScoreSpec(), BadgeLevel.gold),
    (AverageScoreSpec(), BadgeLevel.silver)
])
var earnedBadge: BadgeLevel?

// ❌ Avoid - error-prone strings
@Maybe([
    (HighScoreSpec(), "platinum"),
    (GoodScoreSpec(), "gold")
])
var badgeString: String?  // Typo-prone
```

### Distinguish from Fallback Scenarios

```swift
// Use @Maybe when nil means "don't do anything"
@Maybe([
    (SpecialEventSpec(), "event_theme")
])
var optionalTheme: String?

if let theme = optionalTheme {
    applyTheme(theme)
}
// If nil, don't apply any theme

// Use @Decides when you always need a value
@Decides([
    (SpecialEventSpec(), "event_theme")
], or: "default_theme")
var guaranteedTheme: String

applyTheme(guaranteedTheme)  // Always applies a theme
```

## Performance Considerations

- **First-Match Evaluation**: Stops at first satisfied specification
- **Order Matters**: Place most likely matches first for better performance
- **No Fallback Overhead**: Slightly faster than ``Decides`` (no fallback evaluation)
- **Context Fetching**: Context retrieved once per property access
- **Nil Check Cost**: Minimal overhead for optional handling
- **Re-Evaluation**: No caching; evaluates on each access

## Topics

### Creating Property Wrappers

- ``init(provider:using:)``
- ``init(provider:firstMatch:)``
- ``init(provider:decide:)``

### Convenience Initializers

- ``init(using:)``
- ``init(_:)``
- ``init(decide:)``

### Builder Pattern

- ``builder(provider:)``
- ``MaybeBuilder``

### Property Values

- ``wrappedValue``
- ``projectedValue``

## See Also

- <doc:Decides>
- <doc:Satisfies>
- <doc:DecisionSpec>
- <doc:FirstMatchSpec>
- <doc:EvaluationContext>
