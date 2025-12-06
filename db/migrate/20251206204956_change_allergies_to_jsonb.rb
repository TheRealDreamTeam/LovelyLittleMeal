class ChangeAllergiesToJsonb < ActiveRecord::Migration[7.1]
  # Standard allergy list that must be asked when preparing food
  STANDARD_ALLERGIES = %w[
    peanut
    tree_nuts
    sesame
    shellfish
    milk
    egg
    fish
    wheat
    soy
    kiwi
  ].freeze

  def up
    # First, add a temporary column for jsonb
    add_column :users, :allergies_jsonb, :jsonb, default: {}

    # Migrate existing data: convert comma-separated strings to hash format
    User.reset_column_information
    User.find_each do |user|
      # Parse existing allergies (could be string or already hash)
      existing_allergies = if user.allergies.blank?
                             {}
                           elsif user.allergies.is_a?(Hash)
                             user.allergies
                           elsif user.allergies.is_a?(String)
                             # Convert comma-separated string to hash
                             allergy_array = user.allergies.split(",").map(&:strip).map(&:downcase)
                             allergy_array.each_with_object({}) do |allergy, hash|
                               # Map old allergy names to new standard names
                               mapped_allergy = map_old_allergy_to_new(allergy)
                               hash[mapped_allergy] = true if mapped_allergy
                             end
                           else
                             {}
                           end

      # Initialize hash with all standard allergies set to false
      new_allergies = STANDARD_ALLERGIES.each_with_object({}) do |allergy, hash|
        hash[allergy] = existing_allergies[allergy] || existing_allergies[allergy.to_sym] || false
      end

      user.update_column(:allergies_jsonb, new_allergies)
    end

    # Remove old column and rename new one
    remove_column :users, :allergies
    rename_column :users, :allergies_jsonb, :allergies

    # Add index for jsonb queries
    add_index :users, :allergies, using: :gin
  end

  def down
    # Remove index
    remove_index :users, :allergies if index_exists?(:users, :allergies)

    # Add temporary text column
    add_column :users, :allergies_text, :text

    # Convert hash back to comma-separated string
    User.reset_column_information
    User.find_each do |user|
      next unless user.allergies.is_a?(Hash)

      # Get all allergies that are true
      active_allergies = user.allergies.select { |_key, value| value == true }.keys
      user.update_column(:allergies_text, active_allergies.join(", "))
    end

    # Remove jsonb column and rename text column
    remove_column :users, :allergies
    rename_column :users, :allergies_text, :allergies
  end

  private

  # Maps old allergy names to new standard allergy names
  def map_old_allergy_to_new(old_allergy)
    old_lower = old_allergy.downcase.strip

    # Direct matches
    return old_lower if STANDARD_ALLERGIES.include?(old_lower)

    # Mapping for old allergy names
    mapping = {
      "gluten" => "wheat",
      "lactose" => "milk",
      "crustaceans" => "shellfish",
      "nuts" => "tree_nuts",
      "peanuts" => "peanut",
      "peanut" => "peanut",
      "tree nuts" => "tree_nuts",
      "tree_nuts" => "tree_nuts"
    }

    mapping[old_lower] || old_lower
  end
end
