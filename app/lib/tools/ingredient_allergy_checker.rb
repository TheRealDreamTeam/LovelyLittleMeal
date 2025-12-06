require_relative "base_tool"
require_relative "error_classes"

# Validates that recipe ingredients don't contain user allergens
# Cross-references all ingredients against user's allergy list
# Uses pure Ruby validation (no LLM call) for 100% reliability
#
# Validation checks:
# - All ingredients are checked against user's active allergies
# - Handles edge cases (peanuts vs tree_nuts, etc.)
# - Provides substitute suggestions for detected allergens
# - Distinguishes between explicitly requested allergens (which need warnings) vs unexpected allergens (which should be removed)
#
# Returns structured validation result with violations and substitute suggestions
module Tools
  class IngredientAllergyChecker
    include BaseTool

    # Mapping of allergens to common ingredient names/variations
    # Used for more accurate detection
    ALLERGEN_INGREDIENT_MAPPINGS = {
      "peanut" => %w[peanut peanuts peanutbutter peanut-butter peanut_butter],
      "tree_nuts" => %w[almond almonds walnut walnuts cashew cashews hazelnut hazelnuts pistachio pistachios macadamia macadamias brazil brazil-nut brazil_nut pecans pecan],
      "sesame" => %w[sesame tahini sesame-seed sesame_seed sesame-oil sesame_oil],
      "shellfish" => %w[shrimp prawn crab lobster crayfish crawfish mussel mussels clam clams oyster oysters scallop scallops],
      "milk" => %w[milk dairy butter cream cheese yogurt yoghurt whey casein lactose],
      "egg" => %w[egg eggs egg-white egg_white egg-white egg_white egg-yolk egg_yolk mayonnaise mayo],
      "fish" => %w[fish salmon tuna cod sardine sardines anchovy anchovies mackerel herring],
      "wheat" => %w[wheat flour bread pasta noodles couscous bulgur semolina spelt],
      "soy" => %w[soy soya soybean soybeans tofu tempeh miso soy-sauce soy_sauce tamari edamame],
      "kiwi" => %w[kiwi kiwifruit]
    }.freeze

    # Common substitutes for allergens
    ALLERGEN_SUBSTITUTES = {
      "peanut" => ["sunflower seed butter", "almond butter (if not allergic to tree nuts)", "soy butter (if not allergic to soy)"],
      "tree_nuts" => ["seeds (sunflower, pumpkin)", "oats (if not allergic to wheat)"],
      "sesame" => ["poppy seeds", "sunflower seeds"],
      "shellfish" => ["chicken", "tofu", "mushrooms"],
      "milk" => ["almond milk (if not allergic to tree nuts)", "oat milk", "coconut milk", "soy milk (if not allergic to soy)"],
      "egg" => ["flax egg (1 tbsp ground flaxseed + 3 tbsp water)", "chia egg (1 tbsp chia seeds + 3 tbsp water)", "applesauce", "banana"],
      "fish" => ["chicken", "tofu", "mushrooms"],
      "wheat" => ["gluten-free flour blend", "almond flour (if not allergic to tree nuts)", "rice flour", "oat flour (if not allergic to wheat)"],
      "soy" => ["coconut aminos", "tamari (if gluten-free)", "chickpeas", "lentils"],
      "kiwi" => ["strawberries", "mango", "pineapple"]
    }.freeze

    # Validates ingredients against user allergies
    #
    # @param ingredients [Array<String>] The recipe ingredients array to validate
    # @param user_allergies [Array<String>] List of user's active allergies (e.g., ["peanut", "tree_nuts"])
    # @param requested_ingredients [Array<String>] Ingredients that were explicitly requested by user (may contain allergens)
    # @return [ValidationResult] Validation result with violations and substitute suggestions
    def self.validate(ingredients:, user_allergies:, requested_ingredients: [])
      violations = []
      ingredients = Array(ingredients) # Ensure it's an array

      # Normalize user_allergies to array format
      user_allergies = normalize_allergies(user_allergies)

      # If no allergies, recipe is automatically valid
      return BaseTool.validation_result(valid: true, violations: []) if user_allergies.empty?

      # If no ingredients, can't validate
      return BaseTool.validation_result(
        valid: false,
        violations: [BaseTool.violation(
          type: :no_ingredients,
          message: "Recipe has no ingredients to validate",
          field: :ingredients,
          fix_instruction: "Add ingredients to the recipe"
        )],
        fix_instructions: "Recipe must have ingredients"
      ) if ingredients.empty?

      # Check each ingredient against user allergies
      detected_allergens = detect_allergens_in_ingredients(ingredients, user_allergies)

      # Separate explicitly requested allergens from unexpected ones
      requested_ingredients_lower = requested_ingredients.map(&:downcase)
      unexpected_allergens = []
      explicitly_requested_allergens = []

      detected_allergens.each do |allergen_info|
        ingredient_name = allergen_info[:ingredient]
        ingredient_lower = ingredient_name.downcase

        # Check if this ingredient was explicitly requested
        was_requested = requested_ingredients_lower.any? do |requested|
          ingredient_lower.include?(requested) || requested.include?(ingredient_lower)
        end

        if was_requested
          explicitly_requested_allergens << allergen_info
        else
          unexpected_allergens << allergen_info
        end
      end

      # Create violations for unexpected allergens (these should be removed/substituted)
      unexpected_allergens.each do |allergen_info|
        allergen_key = allergen_info[:allergen]
        ingredient_name = allergen_info[:ingredient]
        substitutes = get_substitutes(allergen_key, user_allergies)

        violations << BaseTool.violation(
          type: :unexpected_allergen,
          message: "Ingredient '#{ingredient_name}' contains allergen '#{format_allergen_name(allergen_key)}' which the user is allergic to",
          field: :ingredients,
          fix_instruction: "Remove '#{ingredient_name}' or substitute with: #{substitutes.join(', ')}"
        )
      end

      # Note: Explicitly requested allergens don't create violations here
      # They are handled by AllergenWarningValidator (which checks for warnings)

      # Generate fix instructions
      fix_instructions = generate_fix_instructions(unexpected_allergens, user_allergies)

      BaseTool.validation_result(
        valid: violations.empty?,
        violations: violations,
        fix_instructions: fix_instructions
      )
    end

    private

    # Detects allergens in ingredients list
    #
    # @param ingredients [Array<String>] Recipe ingredients
    # @param user_allergies [Array<String>] User's active allergies
    # @return [Array<Hash>] Array of { allergen: string, ingredient: string } hashes
    def self.detect_allergens_in_ingredients(ingredients, user_allergies)
      detected = []

      ingredients.each do |ingredient|
        ingredient_lower = ingredient.downcase.strip

        # Check each user allergy
        user_allergies.each do |allergy_key|
          # Check direct match
          next unless ingredient_contains_allergen?(ingredient_lower, allergy_key)

          detected << {
            allergen: allergy_key,
            ingredient: ingredient
          }
        end
      end

      detected.uniq
    end

    # Checks if an ingredient contains a specific allergen
    #
    # @param ingredient_lower [String] Ingredient name (lowercase)
    # @param allergy_key [String] Allergy key (e.g., "peanut")
    # @return [Boolean] True if ingredient contains allergen
    def self.ingredient_contains_allergen?(ingredient_lower, allergy_key)
      # Check direct match
      return true if ingredient_lower.include?(allergy_key)

      # Check mapped ingredient names
      mapped_ingredients = ALLERGEN_INGREDIENT_MAPPINGS[allergy_key] || []
      mapped_ingredients.any? { |mapped| ingredient_lower.include?(mapped) }
    end

    # Gets substitute suggestions for an allergen
    #
    # @param allergen_key [String] Allergy key
    # @param user_allergies [Array<String>] User's active allergies (to filter out substitutes that are also allergens)
    # @return [Array<String>] Array of substitute suggestions
    def self.get_substitutes(allergen_key, user_allergies)
      substitutes = ALLERGEN_SUBSTITUTES[allergen_key] || []
      user_allergies_lower = user_allergies.map(&:downcase)

      # Filter out substitutes that are also allergens for this user
      substitutes.reject do |substitute|
        substitute_lower = substitute.downcase
        user_allergies_lower.any? { |allergy| substitute_lower.include?(allergy) }
      end
    end

    # Generates fix instructions for violations
    #
    # @param unexpected_allergens [Array<Hash>] Detected unexpected allergens
    # @param user_allergies [Array<String>] User's active allergies
    # @return [String] Fix instructions
    def self.generate_fix_instructions(unexpected_allergens, user_allergies)
      return "No allergen violations found." if unexpected_allergens.empty?

      instructions = []
      instructions << "CRITICAL: The recipe contains allergens that the user is allergic to."
      instructions << ""
      instructions << "Detected allergens:"
      unexpected_allergens.each do |allergen_info|
        allergen_key = allergen_info[:allergen]
        ingredient_name = allergen_info[:ingredient]
        substitutes = get_substitutes(allergen_key, user_allergies)

        instructions << "  - #{ingredient_name} contains #{format_allergen_name(allergen_key)}"
        if substitutes.any?
          instructions << "    Suggested substitutes: #{substitutes.join(', ')}"
        end
      end
      instructions << ""
      instructions << "Fix instructions:"
      instructions << "1. Remove all ingredients containing detected allergens"
      instructions << "2. Substitute with allergen-free alternatives (see suggestions above)"
      instructions << "3. Ensure the recipe remains functional and tasty after substitutions"
      instructions << "4. Update ingredient list and instructions accordingly"

      instructions.join("\n")
    end

    # Normalizes user_allergies to array format
    #
    # @param user_allergies [Array<String>, String, Hash] User allergies in various formats
    # @return [Array<String>] Normalized array of allergy keys
    def self.normalize_allergies(user_allergies)
      case user_allergies
      when Array
        user_allergies.map(&:to_s).map(&:strip).reject(&:blank?)
      when String
        user_allergies.split(",").map(&:strip).reject(&:blank?)
      when Hash
        # Extract keys where value is true
        user_allergies.select { |_key, value| value == true }.keys.map(&:to_s)
      else
        []
      end
    end

    # Formats allergy key to human-readable name
    #
    # @param key [String] Allergy key (e.g., "tree_nuts")
    # @return [String] Formatted name (e.g., "Tree nuts")
    def self.format_allergen_name(key)
      key.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
    end
  end
end

