# Agentic Workflow Design for Recipe Generation

## Overview

This document outlines a new agentic workflow architecture that leverages RubyLLM's multi-agent capabilities, tool-based validation, and model routing to 
prove reliability and consistency of recipe generation responses.

## Core Principles

1. **Separation of Concerns**: Use specialized tools for specific tasks
2. **Model Routing**: Use faster models for simple tasks, GPT-5-mini for complex structured output
3. **Parallel Execution**: Run independent validations concurrently
4. **Validation Loop**: Ensure critical requirements are met before returning
5. **Reliability First**: Programmatic enforcement of critical rules

---

## Tool Definitions

### 1. IntentClassifier Tool
**Purpose**: Reliably classify user intent to determine execution path  
**Model**: `gpt-5-nano` (fast, cost-effective for classification)  
**Input**: User message, conversation history, current recipe state  
**Output**: Structured classification result

**Classification Categories**:
- `first_message_link`: No previous messages, user pasted a URL/link to a recipe
- `first_message_free_text`: No previous messages, user provided free text recipe request
- `first_message_complete_recipe`: No previous messages, user pasted complete recipe text
- `first_message_query`: No previous messages, user asking a general question (no recipe yet)
- `question`: User asking about existing recipe (no modifications)
- `modification`: User requesting changes to existing recipe
- `clarification`: User needs more information before proceeding

**Why This Tool**:
- Eliminates confusion about when to greet vs. not greet
- Ensures correct execution path (link extraction vs. free text vs. question handling)
- Different first message types require different processing (link needs web scraping, free text needs generation, etc.)
- Prevents misclassification that leads to wrong behavior

**Output Structure**:
```ruby
{
  intent: "first_message_link" | "first_message_free_text" | "first_message_complete_recipe" | 
          "first_message_query" | "question" | "modification" | "clarification",
  confidence: float,  # 0.0 to 1.0
  detected_url: string | nil,  # If intent is first_message_link
  reasoning: string  # Brief explanation of classification
}
```

---

### 2. ConversationContextAnalyzer Tool
**Purpose**: Analyze conversation history to determine message structure  
**Model**: `gpt-5-nano` (fast analysis)  
**Input**: Full conversation history  
**Output**: Context metadata

**Output Structure**:
```ruby
{
  is_first_message: boolean,
  previous_topics: array,
  recent_changes: array,
  conversation_tone: string,
  greeting_needed: boolean
}
```

**Why This Tool**:
- Determines if greeting is needed (only on first message)
- Tracks conversation flow for better context
- Enables personalized follow-up messages

---

### 3. AllergenWarningValidator Tool
**Purpose**: Validate allergen warnings are present and correctly formatted  
**Model**: None (pure Ruby validation)  
**Input**: Recipe description, user allergies, requested ingredients  
**Output**: Validation result with specific fixes if needed

**Validation Checks**:
- Warning emoji (⚠️) present in description
- Warning mentions specific allergen from user's list
- Warning is personalized (not generic)
- Warning appears prominently (beginning or early in description)

**Why This Tool**:
- **CRITICAL**: Addresses the current warning emoji issue
- Programmatic enforcement (100% reliable)
- Returns specific fix instructions if validation fails

---

### 4. ApplianceCompatibilityChecker Tool
**Purpose**: Verify recipe uses only available appliances  
**Model**: `gpt-5-nano` (fast analysis)  
**Input**: Recipe instructions, user's available appliances  
**Output**: List of violations with specific steps that need modification

**Why This Tool**:
- Ensures recipes are actually cookable with user's equipment
- Returns actionable feedback for fixes
- Prevents invalid recipes from being returned

---

### 5. IngredientAllergyChecker Tool
**Purpose**: Cross-reference ingredients against user allergies  
**Model**: None (pure Ruby validation with ingredient database)  
**Input**: Recipe ingredients, user allergies  
**Output**: Violations list with suggested substitutes

**Why This Tool**:
- Catches allergens before they reach the user
- Provides substitute suggestions
- Handles edge cases (e.g., "peanuts" vs "nuts" allergy)

---

### 6. MetricUnitValidator Tool
**Purpose**: Ensure all quantities use metric units  
**Model**: None (regex/pattern matching)  
**Input**: Recipe ingredients, shopping list  
**Output**: List of non-metric measurements with conversions

**Why This Tool**:
- Enforces consistency
- Fast (no LLM call needed)
- Provides automatic conversions

---

### 7. RecipeCompletenessChecker Tool
**Purpose**: Validate recipe has all required fields  
**Model**: `gpt-5-nano` (fast validation)  
**Input**: Recipe object  
**Output**: Completeness report

**Checks**:
- All required fields present
- Ingredients match instructions
- Shopping list matches ingredients
- Instructions are coherent and complete

---

### 8. PreferenceComplianceChecker Tool
**Purpose**: Verify recipe aligns with user preferences  
**Model**: `gpt-5-nano` (fast analysis)  
**Input**: Recipe, user preferences  
**Output**: Compliance report with violations

---

### 9. MessageFormatter Tool
**Purpose**: Generate properly structured response message  
**Model**: `gpt-5-nano` (fast, good for formatting)  
**Input**: Recipe changes, conversation context, validation results  
**Output**: Formatted message text

**Why This Tool**:
- Ensures consistent message structure
- Applies conversation context (no greeting on follow-ups)
- Formats based on what actually changed

---

### 10. RecipeLinkExtractor Tool
**Purpose**: Extract recipe content from URLs (web scraping)  
**Model**: None (web scraping + optional LLM for parsing)  
**Input**: URL string  
**Output**: Extracted recipe data (title, ingredients, instructions, etc.)

**Why This Tool**:
- GPT-5-mini cannot browse the internet or access external links
- Users frequently paste recipe URLs from cooking websites
- Needs to fetch, parse, and extract structured recipe data
- Critical for handling one of the most common first message types

**Implementation Approach**:
1. **Web Scraping**: Use HTTP client (Faraday/Net::HTTP) to fetch URL
2. **Content Extraction**: Use Nokogiri or similar to parse HTML
3. **Recipe Parsing**: 
   - Try structured data (JSON-LD, microdata) first
   - Fall back to pattern matching for common recipe sites
   - Use GPT-5-nano as fallback to extract from unstructured HTML
4. **Return**: Structured recipe data (title, ingredients, instructions, description)

**Error Handling**:
- Invalid URL: Return error
- Network failure: Return error with retry suggestion
- Unparseable content: Use GPT-5-nano to extract from raw HTML
- Rate limiting: Return error with suggestion to paste recipe text instead

---

### 11. RecipeModifier Tool (Optional)
**Purpose**: Handle specific recipe modifications programmatically  
**Model**: `gpt-5-mini` (for complex modifications)  
**Input**: Current recipe, modification request  
**Output**: Modified recipe structure

**Use Cases**:
- Simple additions (add ingredient)
- Quantity changes
- Ingredient substitutions

**Why Optional**:
- Current approach (LLM modifies in structured output) works
- Could be added for very specific, common modifications
- Lower priority than validation tools

---

### 12. ImageGenerationStarter Tool
**Purpose**: Trigger image generation asynchronously without blocking response  
**Model**: None (Ruby job trigger)  
**Input**: Validated recipe object  
**Output**: Job ID (for tracking, optional)

**Why This Tool**:
- Image generation takes 10-30 seconds
- Should not block user response
- Can start as soon as recipe is validated (before message formatting)
- Runs in parallel with message generation
- Improves perceived performance (image starts generating earlier)

**Implementation**:
- Triggers `RecipeImageGenerationJob` asynchronously
- Returns immediately (non-blocking)
- Job handles image generation, storage, and Turbo Stream broadcast
- Can be called as soon as recipe passes validation

---

## Model Routing Strategy

### GPT-5-mini (Main Model)
**Use For**:
- Final recipe generation with structured output (RecipeSchema)
- Complex recipe modifications
- Initial recipe creation from user input

**Why**: Good structured output reliability with faster response times. With our validation tools, we can ensure quality while using a faster model.

### GPT-5-nano (Fast Model)
**Use For**:
- Intent classification
- Conversation context analysis
- Quick validations (appliance checks, completeness)
- Message formatting
- Preference compliance checks

**Why**: 10x faster, 10x cheaper, sufficient for simpler tasks

### No Model (Pure Ruby)
**Use For**:
- Allergen warning validation (regex/string matching)
- Ingredient allergy checking (database lookup)
- Metric unit validation (regex/pattern matching)

**Why**: Fastest, most reliable, zero cost

---

## Parallelization Opportunities

### Phase 1: Initial Analysis (Parallel)
After user message received, run in parallel:
- `IntentClassifier` (determines path)
- `ConversationContextAnalyzer` (for message formatting)

**Benefit**: Both needed for execution, independent of each other

---

### Phase 2: Link Extraction (Conditional)
**Only if intent is `first_message_link`**:
- `RecipeLinkExtractor` (web scraping + optional LLM parsing)
- Cannot parallelize (must complete before recipe generation)

---

### Phase 3: Recipe Generation
- Single GPT-5-mini call with structured output (RecipeSchema)
- Input depends on intent:
  - `first_message_link`: Use extracted recipe data from link
  - `first_message_free_text`: Generate from free text
  - `first_message_complete_recipe`: Parse and structure pasted recipe
  - `modification`: Modify existing recipe
- Cannot parallelize (depends on user input)

---

### Phase 4: Validation (Parallel)
After recipe generated, run all validations in parallel:
- `AllergenWarningValidator` (pure Ruby - instant)
- `ApplianceCompatibilityChecker` (gpt-5-nano)
- `IngredientAllergyChecker` (pure Ruby - instant)
- `MetricUnitValidator` (pure Ruby - instant)
- `RecipeCompletenessChecker` (gpt-5-nano)
- `PreferenceComplianceChecker` (gpt-5-nano)

**Benefit**: All validations independent, run concurrently saves time

---

### Phase 5: Image Generation + Message Generation (Parallel)
After validations pass, run in parallel:
- `ImageGenerationStarter` (triggers async job - non-blocking)
- `MessageFormatter` (gpt-5-nano)

**Benefit**: 
- Image generation starts immediately after validation (earlier than current flow)
- Message formatting happens concurrently (doesn't wait for image)
- User gets response faster, image appears shortly after
- Image generation no longer blocks response (was already async, but now starts earlier)

---

## Complete Execution Flow

### Flow Diagram

```
User Message
    │
    ├─→ [PARALLEL] IntentClassifier + ConversationContextAnalyzer
    │
    ├─→ Route Based on Intent
    │
    ├─→ IF first_message_link:
    │   │
    │   ├─→ RecipeLinkExtractor: Fetch and parse URL
    │   │
    │   ├─→ GPT-5-mini: Structure extracted recipe (with RecipeSchema)
    │   │
    │   └─→ Continue to validation phase...
    │
    ├─→ IF first_message_free_text OR first_message_complete_recipe OR modification:
    │   │
    │   ├─→ GPT-5-mini: Generate/Modify Recipe (with RecipeSchema)
    │   │
    │   ├─→ [PARALLEL] Run All Validation Tools:
    │   │   ├─→ AllergenWarningValidator
    │   │   ├─→ ApplianceCompatibilityChecker
    │   │   ├─→ IngredientAllergyChecker
    │   │   ├─→ MetricUnitValidator
    │   │   ├─→ RecipeCompletenessChecker
    │   │   └─→ PreferenceComplianceChecker
    │   │
    │   ├─→ IF violations found:
    │   │   ├─→ Collect all violations
    │   │   ├─→ GPT-5-mini: Fix Recipe (with specific violation list)
    │   │   └─→ Re-run validations (loop until clean)
    │   │
    │   ├─→ [PARALLEL] After validation passes:
    │   │   ├─→ ImageGenerationStarter: Trigger async image generation
    │   │   └─→ MessageFormatter: Generate response message
    │   │
    │   └─→ Return recipe + message (image generating in background)
    │
    ├─→ IF first_message_query:
    │   │
    │   ├─→ GPT-5-nano: Answer general question
    │   │
    │   ├─→ MessageFormatter: Format answer
    │   │
    │   └─→ Return answer (no recipe created yet)
    │
    └─→ IF question:
        │
        ├─→ GPT-5-nano: Answer question about existing recipe
        │
        ├─→ MessageFormatter: Format answer
        │
        └─→ Return answer + unchanged recipe
```

### Detailed Step-by-Step Flow

#### Step 1: Receive User Message
- User sends message via form
- Message saved to database
- Trigger workflow

#### Step 2: Parallel Initial Analysis
**Execute concurrently**:
- `IntentClassifier` tool → determines: first_message_link, first_message_free_text, first_message_complete_recipe, first_message_query, question, or modification
- `ConversationContextAnalyzer` tool → determines: greeting needed, conversation context

**Models**: Both use `gpt-5-nano` (fast, parallel execution)

**Output**: 
- Intent classification (with detected URL if link)
- Conversation context metadata

#### Step 3: Route Based on Intent

##### Path A1: First Message with Link (`first_message_link`)
1. **Link Extraction**
   - Use `RecipeLinkExtractor` tool
   - Fetch URL content (web scraping)
   - Extract recipe data (structured data, HTML parsing, or LLM fallback)
   - Output: Raw recipe data (title, ingredients, instructions, etc.)

2. **Recipe Structuring**
   - Use `GPT-5-mini` with `RecipeSchema`
   - Input: Extracted recipe data + user preferences
   - System prompt: "Structure this extracted recipe according to user preferences"
   - Output: Structured recipe object
   - Continue to validation phase (Step 4)

##### Path A2: First Message Free Text or Complete Recipe (`first_message_free_text` or `first_message_complete_recipe`)
1. **Recipe Generation**
   - Use `GPT-5-mini` with `RecipeSchema`
   - System prompt: Core persona + user preferences + high-level workflow
   - Input: User message (free text request or pasted recipe)
   - Output: Structured recipe object
   - Continue to validation phase (Step 4)

##### Path A3: Modification (`modification`)
1. **Recipe Modification**
   - Use `GPT-5-mini` with `RecipeSchema`
   - System prompt: Core persona + user preferences + high-level workflow
   - Input: User message + current recipe + conversation history
   - Output: Modified structured recipe object
   - Continue to validation phase (Step 4)

##### Path A: Validation Phase (for all recipe generation paths)
2. **Parallel Validation**
   - Execute all 6 validation tools concurrently using `Async`:

2. **Parallel Validation Phase**
   - Execute all 6 validation tools concurrently using `Async`:
     - `AllergenWarningValidator` (pure Ruby)
     - `ApplianceCompatibilityChecker` (gpt-5-nano)
     - `IngredientAllergyChecker` (pure Ruby)
     - `MetricUnitValidator` (pure Ruby)
     - `RecipeCompletenessChecker` (gpt-5-nano)
     - `PreferenceComplianceChecker` (gpt-5-nano)

3. **Validation Results Aggregation**
   - Collect all violations from parallel validations
   - If no violations: proceed to message generation
   - If violations found: proceed to fix loop

4. **Fix Loop (if violations)**
   - Aggregate all violations into structured feedback
   - Send to `GPT-5-mini` with:
     - Current recipe
     - Specific violation list
     - Fix instructions for each violation
   - Generate fixed recipe
   - Re-run validations (parallel again)
   - Repeat until no violations (max 3 iterations to prevent loops)

5. **Parallel: Image Generation + Message Generation**
   - Execute concurrently using `Async`:
     - `ImageGenerationStarter` tool: Triggers `RecipeImageGenerationJob` asynchronously (non-blocking)
     - `MessageFormatter` tool (gpt-5-nano): Generates response message
   - Image generation starts immediately (earlier than current flow)
   - Message formatting happens concurrently (doesn't wait for image)
   - Both complete independently

6. **Return Result**
   - Recipe object (validated and fixed)
   - Message text
   - Save to database
   - Return to user
   - Image generation continues in background (appears via Turbo Stream when ready)

##### Path B1: First Message Query (`first_message_query`)
1. **General Question Answering**
   - Use `GPT-5-nano` (fast, sufficient for Q&A)
   - Input: Question (no recipe exists yet)
   - System prompt: "Answer the user's question helpfully as a cooking expert"
   - Output: Answer text

2. **Message Formatting**
   - Use `MessageFormatter` tool
   - Input: Answer + conversation context (is first message, greeting needed)
   - Output: Formatted response (with greeting)

3. **Return Result**
   - Answer message
   - No recipe created
   - Save to database
   - Return to user

##### Path B2: Question About Existing Recipe (`question`)
1. **Question Answering**
   - Use `GPT-5-nano` (fast, sufficient for Q&A)
   - Input: Question + current recipe + conversation history
   - System prompt: "Answer questions about the recipe helpfully"
   - Output: Answer text

2. **Message Formatting**
   - Use `MessageFormatter` tool
   - Input: Answer + conversation context (no greeting needed)
   - Output: Formatted response (no greeting)

3. **Return Result**
   - Answer message
   - Unchanged recipe (recipe_modified: false)
   - Save to database
   - Return to user

---

## Implementation Phases

### Phase 1: Critical Tools (Week 1)
**Priority**: Fix immediate reliability issues

1. **AllergenWarningValidator**
   - Pure Ruby validation
   - Addresses warning emoji issue
   - Highest ROI

2. **IntentClassifier**
   - Resolves greeting/execution path confusion
   - Classifies different first message types
   - Uses gpt-5-nano

3. **ConversationContextAnalyzer**
   - Determines greeting necessity
   - Uses gpt-5-nano

4. **RecipeLinkExtractor**
   - Enables link pasting functionality
   - Critical for common user workflow
   - Web scraping + optional LLM parsing

**Result**: Fixes warning emoji, greeting issues, and enables link handling

---

### Phase 2: Validation Suite (Week 2)
**Priority**: Comprehensive validation

4. **ApplianceCompatibilityChecker**
5. **IngredientAllergyChecker**
6. **MetricUnitValidator**
7. **RecipeCompletenessChecker**
8. **PreferenceComplianceChecker**

**Result**: All critical validations in place

---

### Phase 3: Optimization (Week 3)
**Priority**: Performance and polish

9. **MessageFormatter**
10. **ImageGenerationStarter**
    - Parallelize image generation with message formatting
    - Start image generation earlier in flow
11. Parallel execution implementation
12. Validation loop with fix mechanism
13. Model routing optimization

**Result**: Fast, reliable, comprehensive system with optimized image generation

---

## Benefits of This Approach

### Reliability
- **Programmatic Enforcement**: Critical rules enforced by code, not just prompts
- **Validation Loop**: Ensures quality before returning
- **Specific Feedback**: Violations include exact fix instructions

### Performance
- **Parallel Execution**: Validations run concurrently (6x faster)
- **Image Generation**: Starts immediately after validation (earlier than current flow)
- **Message + Image Parallel**: Message formatting and image generation run concurrently
- **Model Routing**: Fast models for simple tasks, GPT-5-mini for recipe generation
- **Pure Ruby Validations**: Instant checks for simple rules
- **Link Extraction**: Enables web recipe import (previously impossible)

### Cost Efficiency
- **GPT-5-nano**: 10x cheaper for classification/validation
- **Pure Ruby**: Zero cost for pattern matching
- **GPT-5-mini**: For recipe generation with structured output

### Maintainability
- **Separation of Concerns**: Each tool has single responsibility
- **Testable**: Tools can be unit tested independently
- **Debuggable**: Clear execution path, easy to trace issues

### Consistency
- **Intent Classification**: Reliable path selection
- **Validation**: Same rules applied every time
- **Message Formatting**: Consistent structure

---

## Example: Allergen Warning Flow

### Current Flow (Unreliable)
```
User: "add peanuts"
→ GPT-5-mini generates recipe
→ System prompt says "add warning"
→ Sometimes warning appears, sometimes doesn't ❌
```

### New Flow (Reliable)
```
User: "add peanuts"
→ IntentClassifier: "modification"
→ GPT-5-mini: Generate recipe with warning (attempt)
→ AllergenWarningValidator: Check description
→ IF warning missing:
   → Collect violation: "Missing ⚠️ emoji in description"
   → GPT-5-mini: Fix recipe (with specific instruction)
   → AllergenWarningValidator: Re-check
   → IF still missing: Loop (max 3 times)
→ MessageFormatter: Generate message
→ Return validated recipe ✅
```

**Result**: 100% reliability for critical requirements

---

## Model Usage Summary

### GPT-5-mini (Fast, Good Quality)
- Recipe generation with structured output: **1 call per request**
- Recipe fixes (if violations): **0-3 calls per request** (validation loop)

### GPT-5-nano (Fast, Cost-Effective)
- Intent classification: **1 call per request** (parallel)
- Conversation context: **1 call per request** (parallel)
- Appliance check: **1 call per request** (parallel validation)
- Completeness check: **1 call per request** (parallel validation)
- Preference check: **1 call per request** (parallel validation)
- Message formatting: **1 call per request**
- Question answering: **1 call per request** (if question path)

**Total**: 2-8 calls per request (many in parallel)

### Pure Ruby (Free, Instant)
- Allergen warning validation: **Instant**
- Ingredient allergy check: **Instant**
- Metric unit validation: **Instant**

---

## Async Execution Pattern

Based on [RubyLLM async documentation](https://rubyllm.com/async/):

```ruby
# Pseudo-code structure (not actual implementation)
Async do |task|
  # Phase 1: Parallel initial analysis
  intent = nil
  context = nil
  
  task.async { intent = IntentClassifier.execute(message) }
  task.async { context = ConversationContextAnalyzer.execute(history) }
  
  # Wait for both, then route
  # intent and context are now available
  
  # Phase 2: Link extraction (conditional, sequential)
  extracted_data = nil
  if intent[:intent] == "first_message_link"
    extracted_data = RecipeLinkExtractor.execute(intent[:detected_url])
  end
  
  # Phase 3: Recipe generation (sequential, depends on intent)
  recipe = case intent[:intent]
  when "first_message_link"
    GPT4o.structure_recipe(extracted_data, user_preferences)
  when "first_message_free_text", "first_message_complete_recipe"
    GPT4o.generate_recipe(message, user_preferences)
  when "modification"
    GPT4o.modify_recipe(current_recipe, message, conversation_history)
  end
  
  # Phase 4: Parallel validations
  violations = {}
  
  task.async { violations[:allergen] = AllergenWarningValidator.execute(recipe) }
  task.async { violations[:appliance] = ApplianceCompatibilityChecker.execute(recipe) }
  task.async { violations[:ingredient] = IngredientAllergyChecker.execute(recipe) }
  task.async { violations[:metric] = MetricUnitValidator.execute(recipe) }
  task.async { violations[:completeness] = RecipeCompletenessChecker.execute(recipe) }
  task.async { violations[:preference] = PreferenceComplianceChecker.execute(recipe) }
  
  # Wait for all validations
  all_violations = aggregate_violations(violations)
  
  # Phase 5: Fix loop if needed (sequential)
  max_fixes = 3
  fix_count = 0
  while all_violations.any? && fix_count < max_fixes
    recipe = GPT4o.fix_recipe(recipe, all_violations)
    
    # Re-run validations in parallel
    task.async { violations[:allergen] = AllergenWarningValidator.execute(recipe) }
    task.async { violations[:appliance] = ApplianceCompatibilityChecker.execute(recipe) }
    task.async { violations[:ingredient] = IngredientAllergyChecker.execute(recipe) }
    task.async { violations[:metric] = MetricUnitValidator.execute(recipe) }
    task.async { violations[:completeness] = RecipeCompletenessChecker.execute(recipe) }
    task.async { violations[:preference] = PreferenceComplianceChecker.execute(recipe) }
    
    all_violations = aggregate_violations(violations)
    fix_count += 1
  end
  
  # Phase 6: Parallel image generation + message formatting
  message = nil
  image_job_id = nil
  
  task.async { image_job_id = ImageGenerationStarter.execute(recipe) }
  task.async { message = MessageFormatter.execute(recipe, context, all_violations) }
  
  # Wait for message (image generation continues in background)
  # Image will appear via Turbo Stream when ready
  
  return {
    recipe: recipe,
    message: message,
    image_generating: image_job_id.present?
  }
end
```

---

## Migration Strategy

### Step 1: Add Tools Alongside Current System
- Implement tools
- Run validations after current flow
- Log violations (don't block yet)
- Measure improvement

### Step 2: Integrate Critical Tools
- Add AllergenWarningValidator to fix loop
- Add IntentClassifier for routing
- Keep current system as fallback

### Step 3: Full Migration
- Replace prompt-based logic with tools
- Implement parallel execution
- Simplify system prompt
- Remove old code

---

## Success Metrics

### Reliability Metrics
- **Allergen Warning Compliance**: 100% (currently ~20%)
- **Greeting Accuracy**: 100% (currently inconsistent)
- **Appliance Compliance**: 100% (currently unknown)

### Performance Metrics
- **Validation Time**: <2s (parallel vs. sequential)
- **Total Response Time**: Similar or faster (despite more checks)
- **Cost per Request**: Lower (more nano calls, GPT-5-mini for generation)

### Quality Metrics
- **Recipe Completeness**: 100%
- **Metric Unit Compliance**: 100%
- **Preference Alignment**: 100%

---

## Next Steps

1. **Review this design** with team
2. **Prioritize tools** based on current pain points
3. **Implement Phase 1** (critical tools)
4. **Test and measure** improvements
5. **Iterate** based on results

---

## References

- [RubyLLM Agentic Workflows](https://rubyllm.com/agentic-workflows/)
- [RubyLLM Tools Documentation](https://rubyllm.com/tools/)
- [RubyLLM Async Documentation](https://rubyllm.com/async/)
- [OpenAI GPT-5-mini Model Documentation](https://platform.openai.com/docs/models/gpt-5-mini)

