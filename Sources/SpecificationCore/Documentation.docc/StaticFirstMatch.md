# ``SpecificationCore/StaticFirstMatch``

Compose a fixed set of one through ten decision rules into a typed first-match decision.

## Overview

`StaticFirstMatch` evaluates rules in their written order and returns the first non-`nil` result. Its result builder arranges the fixed rule set into nested binary decisions while retaining each rule's concrete type. A matching rule prevents later rules from running, including when the matched result itself is an optional value containing `nil`.

Use this API when the rule set is known at compile time. Use ``FirstMatchSpec`` when rules are assembled dynamically at runtime.

## Create a static decision

```swift
import SpecificationCore

struct IsPremium: Specification {
    func isSatisfiedBy(_ user: User) -> Bool { user.isPremium }
}

struct HasTrial: Specification {
    func isSatisfiedBy(_ user: User) -> Bool { user.hasTrial }
}

let accessLevel = StaticFirstMatch {
    IsPremium().returning("premium")
    HasTrial().returning("trial")
}

let access = accessLevel.decide(user) ?? "standard"
```

The builder accepts one through ten rules. Each rule must use the same context and result types. Rules retain their source order, and evaluation stops at the first match.
