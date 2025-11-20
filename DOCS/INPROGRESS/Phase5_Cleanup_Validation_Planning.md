# Feature Planning: Documentation Cleanup and Validation

## Task Metadata
- **Created**: 2025-11-20
- **Priority**: P1
- **Estimated Scope**: Medium (3-4 hours)
- **Prerequisites**: Phase 3 complete (all 23 articles created)
- **Target Layers**: Documentation, CI/CD, Quality Assurance

## Feature Overview

Address all warnings and issues from the DocC build, improve documentation quality, validate cross-references, fix circular dependencies, and ensure documentation builds cleanly in CI/CD pipeline.

## Current Issues

### Build Warnings Summary (from `swift package generate-documentation`)

1. **Ambiguous Symbol References** (~10 warnings)
   - `init(_:)` disambiguation issues in AnySpecification, AsyncSpecification
   - `init(provider:using:)` disambiguation issues in AsyncSatisfies
   - `init(_:fallback:)` and `init(_:or:)` disambiguation in Decides

2. **Circular Reference Cycles** (~30 warnings)
   - Topics sections creating documentation hierarchy cycles
   - Most common: Protocol ↔ Type-Erased Wrapper cycles
   - Example: `Specification ↔ AnySpecification`
   - Example: `AsyncSpecification ↔ AsyncSatisfies`
   - Example: `ContextProviding ↔ EvaluationContext ↔ DefaultContextProvider`

3. **Extraneous Content Warnings** (~8 warnings)
   - Content after links in Topics list items
   - Example: `- ``init(_:)`` (from Specification)` needs cleanup

4. **Missing Symbols** (~5 warnings)
   - `AutoContext` macro not found (expected - it's in macros target)
   - `allSatisfied()` and `anySatisfied()` methods not found
   - Wrong symbol paths or typos

## Implementation Plan

### Phase 5.1: Fix Ambiguous Symbol References
**Goal**: Add proper disambiguation to all ambiguous symbol links

- [ ] **AnySpecification.md**
  - Fix `init(_:)` ambiguity - use proper hash suffixes
  - Remove extraneous content from Topics items
  - Test: Verify all init methods link correctly

- [ ] **AsyncSpecification.md**
  - Fix `AnyAsyncSpecification/init(_:)` ambiguity
  - Use correct disambiguation format
  - Test: Check bridging section links

- [ ] **AsyncSatisfies.md**
  - Fix `init(provider:using:)-29rld` (wrong hash)
  - Fix `init(provider:using:)-8c1q7` (wrong hash)
  - Find correct hashes from build output
  - Update Topics section
  - Test: Verify all initializer links work

- [ ] **Decides.md**
  - Fix `init(_:fallback:)` ambiguity
  - Fix `init(_:or:)` ambiguity
  - Add proper disambiguation suffixes
  - Test: Check all convenience initializers link

**How to Fix**:
```markdown
# Before (ambiguous)
- ``init(_:)``

# After (disambiguated) - use hash from build output
- ``init(_:)-5tl2e``

# Or use parameter types
- ``init(_:)-((T)->Bool)``
```

### Phase 5.2: Resolve Circular Reference Cycles
**Goal**: Remove circular dependencies in Topics sections

**Strategy**: Remove cross-references that create cycles. Keep references one-way:
- Concrete types can reference protocols
- Protocols should NOT reference concrete implementations in Topics
- Use "See Also" section for reverse references instead

- [ ] **Fix Protocol → Implementation Cycles**
  ```markdown
  # In Specification.md - REMOVE from Topics:
  - ``AnySpecification``  # Causes cycle
  - ``Satisfies``  # Causes cycle

  # Instead, keep in "See Also" section as <doc:> references
  ```

- [ ] **Fix AsyncSpecification.md**
  - Remove `Specification` from Topics (creates cycle)
  - Keep in "See Also" only

- [ ] **Fix AnySpecification.md**
  - Remove `Specification` from Topics
  - Keep only in "See Also"

- [ ] **Fix AsyncSatisfies.md**
  - Remove `AsyncSpecification` from Topics
  - Remove `Specification` from Topics
  - Remove `EvaluationContext` from Topics
  - Remove `ContextProviding` from Topics
  - Keep only wrapper-specific items in Topics
  - Move removed items to "See Also"

- [ ] **Fix ContextProviding.md**
  - Remove `EvaluationContext` from Topics
  - Remove `DefaultContextProvider` from Topics
  - Remove `MockContextProvider` from Topics
  - Keep protocol-level items only

- [ ] **Fix All Spec Articles** (CooldownIntervalSpec, DateComparisonSpec, etc.)
  - Remove `EvaluationContext` from Topics
  - Remove `DefaultContextProvider` from Topics
  - Remove `MockContextProvider` from Topics
  - These should only reference their own APIs in Topics

**Pattern to Follow**:
```markdown
## Topics

### [Type-Specific Content Only]
- ``myTypeMethod()``
- ``myTypeProperty``

### Related Types (if needed - use sparingly)
- ``DirectDependency``  # Only if this type directly depends on it

## See Also

- <doc:RelatedProtocol>  # Use doc references, not symbol links
- <doc:RelatedImplementation>
- <doc:RelatedWrapper>
```

### Phase 5.3: Clean Up Extraneous Content
**Goal**: Remove content after symbol links in Topics lists

- [ ] **AnySpecification.md**
  ```markdown
  # Before
  - ``init(_:)-swift.init`` (from Specification)

  # After
  - ``init(_:)-swift.init``
  ```

- [ ] **AsyncSpecification.md**
  - Remove "(from Specification)" annotations from Topics
  - Move explanatory text to description paragraphs

- [ ] **Apply Pattern Across All Files**
  - Topics lists should only contain symbol links
  - Explanatory text goes in section descriptions
  - Use code comments in examples for context

### Phase 5.4: Fix Missing Symbols
**Goal**: Correct symbol references that don't exist

- [ ] **AutoContextMacro.md**
  - File references `SpecificationCore/AutoContext` which doesn't exist
  - Should reference macro target symbol or remove symbol reference
  - Update title: `# @AutoContext Macro` or `# AutoContext`
  - Fix all `AutoContext` symbol links throughout

- [ ] **ContextProviding.md**
  - Remove invalid `AutoContext` references
  - Replace with text or doc references if needed

- [ ] **AnySpecification.md**
  - Fix `allSatisfied()` reference (doesn't exist)
  - Fix `anySatisfied()` reference (doesn't exist)
  - Use correct method names or remove if not applicable

### Phase 5.5: Validate Documentation Links
**Goal**: Ensure all cross-references work correctly

- [ ] Validate `<doc:>` references in "See Also" sections
- [ ] Check that referenced articles exist
- [ ] Verify article file names match references
- [ ] Test navigation between related docs

**Commands**:
```bash
# Find all doc references
grep -r "<doc:" Sources/SpecificationCore/Documentation.docc/*.md

# Verify target files exist
ls Sources/SpecificationCore/Documentation.docc/<DocName>.md
```

### Phase 5.6: Build and Test
**Goal**: Ensure documentation builds without warnings

- [ ] Build documentation locally
  ```bash
  swift package generate-documentation --target SpecificationCore
  ```

- [ ] Count warnings before and after fixes
- [ ] Verify all warnings are resolved
- [ ] Test documentation in browser
- [ ] Validate CI builds cleanly

### Phase 5.7: Quality Improvements
**Goal**: Enhance documentation consistency and quality

- [ ] **Consistency Check**
  - Verify all articles follow same structure
  - Check heading levels are consistent
  - Ensure code example formatting is uniform

- [ ] **Content Review**
  - Fix typos and grammar issues
  - Improve clarity of explanations
  - Add missing examples where needed

- [ ] **Cross-Reference Audit**
  - Ensure bidirectional links where appropriate
  - Add missing "See Also" references
  - Remove dead links

## Files to Modify

### High Priority (Many Warnings)
1. `AsyncSatisfies.md` (~8 warnings)
2. `AnySpecification.md` (~6 warnings)
3. `ContextProviding.md` (~6 warnings)
4. `CooldownIntervalSpec.md` (~4 warnings)
5. `DateComparisonSpec.md` (~4 warnings)

### Medium Priority
6. `AsyncSpecification.md` (~4 warnings)
7. `Decides.md` (~2 warnings)
8. `AutoContextMacro.md` (~1 warning)
9. Other spec articles with circular references

### All Articles (for consistency)
- All 23 .md files for final quality pass

## Test Strategy

### Before Fixes
```bash
# Capture baseline warnings
swift package generate-documentation --target SpecificationCore 2>&1 | grep "warning:" | wc -l
```

### After Each Fix
```bash
# Rebuild and check warning count
swift package generate-documentation --target SpecificationCore 2>&1 | grep "warning:"
```

### Final Validation
```bash
# Full clean build
rm -rf .build/plugins
swift package generate-documentation --target SpecificationCore

# Should output: "Build of target: 'SpecificationCore' complete!"
# With zero warnings
```

## Success Criteria

- [ ] Zero warnings from `swift package generate-documentation`
- [ ] All symbol links resolve correctly
- [ ] No circular references in documentation hierarchy
- [ ] All Topics sections follow proper structure
- [ ] Documentation builds successfully in CI
- [ ] All cross-references work in rendered docs
- [ ] Quality review complete (consistency, grammar, completeness)

## Warning Tracking

### Starting Count
- Total warnings: ~70
- Ambiguous symbols: ~10
- Circular references: ~30
- Extraneous content: ~8
- Missing symbols: ~5
- Other: ~17

### Target
- Total warnings: 0
- Build time: < 30 seconds
- Clean CI build: ✓

## Open Questions

- Should we document macro symbols differently?
- Should Topics sections be minimal (only type-specific items)?
- Should we create a documentation style guide?
- Should we add more cross-references or keep them minimal?

## Related Work

- Phase 3: All articles created
- Apple DocC documentation best practices
- Swift-DocC-Plugin documentation
- SpecificationKit documentation as reference

## Implementation Notes

### Disambiguation Format
DocC uses hash-based disambiguation:
```markdown
# Format: ``symbol-hash``
- ``init(_:)-5tl2e``  # Hash from build output

# Alternative: Parameter-based
- ``init(_:)-((T)->Bool)``
```

### Topics Best Practices
1. Keep Topics focused on the current type's API
2. Don't include parent protocols or implementations
3. Use "See Also" for broader relationships
4. Group related methods/properties logically

### Circular Reference Strategy
```
DO:     ConcreteType → Protocol
DON'T:  Protocol → ConcreteType (in Topics)
USE:    Protocol "See Also" → <doc:ConcreteType>
```

## Time Estimate Breakdown

- **5.1: Fix Ambiguous Symbols** (1 hour)
- **5.2: Resolve Circular References** (1.5 hours)
- **5.3: Clean Up Extraneous Content** (30 mins)
- **5.4: Fix Missing Symbols** (30 mins)
- **5.5: Validate Links** (30 mins)
- **5.6: Build and Test** (30 mins)
- **5.7: Quality Improvements** (1 hour)

**Total: 3-4 hours**

## Next Steps

1. Start with Phase 5.2 (circular references) - highest impact
2. Then Phase 5.1 (ambiguous symbols) - most numerous
3. Then cleanup and validation phases
4. Final build and CI validation
