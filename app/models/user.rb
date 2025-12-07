class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :chats
  has_many :recipes, through: :chats

  # Standard allergy list that must be asked when preparing food
  # Stored as a hash with boolean values: { "peanut" => true, "tree_nuts" => false, ... }
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

  # Standard appliance list
  # Stored as a hash with boolean values: { "stove" => true, "oven" => false, ... }
  # Note: stove implies pan, so pan is not in the list
  STANDARD_APPLIANCES = %w[
    stove
    oven
    microwave
    blender
    stick_blender
    mixer
    kettle
    toaster
    air_fryer
    pressure_cooker
  ].freeze

  # Treat jsonb appliances column as individual accessors
  store_accessor :appliances, *STANDARD_APPLIANCES

  # Gender enum: 0 = male, 1 = female, 2 = prefer_not_to_say
  enum gender: {
    male: 0,
    female: 1,
    prefer_not_to_say: 2
  }

  # Activity level enum: Based on exercise frequency and intensity
  enum activity_level: {
    sedentary: 0,           # Little or no exercise
    lightly_active: 1,      # Light exercise 1-3 days/week
    moderately_active: 2,   # Moderate exercise 3-5 days/week
    very_active: 3,         # Hard exercise 6-7 days/week
    extra_active: 4         # Very hard exercise, physical job
  }

  # Goal enum: Body composition and fitness goals
  enum goal: {
    lose_weight: 0,        # Weight loss / fat loss
    maintain_weight: 1,    # Maintain current weight
    gain_weight: 2,        # Weight gain
    build_muscle: 3,       # Muscle building / hypertrophy
    recomp: 4              # Body recomposition (lose fat, gain muscle)
  }

  # Initialize allergies and appliances with defaults
  # Run on create for new users
  before_validation :initialize_allergies, on: :create
  before_validation :initialize_appliances, on: :create

  # Get list of active allergies (where value is true)
  #
  # @return [Array<String>] Array of allergy keys that are active
  def active_allergies
    return [] unless allergies.is_a?(Hash)

    allergies.select { |_key, value| value == true }.keys
  end

  # Check if user has a specific allergy
  #
  # @param allergy_key [String] The allergy key to check (e.g., "peanut")
  # @return [Boolean] True if user has this allergy
  def has_allergy?(allergy_key)
    return false unless allergies.is_a?(Hash)

    allergies[allergy_key.to_s] == true
  end

  # Get human-readable allergy names for display
  #
  # @return [Array<String>] Array of formatted allergy names
  def allergy_names
    active_allergies.map { |key| format_allergy_name(key) }
  end

  # Get list of active appliances (where value is true)
  #
  # @return [Array<String>] Array of appliance keys that are active
  def active_appliances
    return [] unless appliances.is_a?(Hash)

    appliances.select { |_key, value| value == true }.keys
  end

  # Check if user has a specific appliance
  #
  # @param appliance_key [String] The appliance key to check (e.g., "stove")
  # @return [Boolean] True if user has this appliance
  def has_appliance?(appliance_key)
    return false unless appliances.is_a?(Hash)

    appliances[appliance_key.to_s] == true
  end

  # Get human-readable appliance names for display
  #
  # @return [Array<String>] Array of formatted appliance names
  def appliance_names
    active_appliances.map { |key| format_appliance_name(key) }
  end

  # Calculates Body Mass Index (BMI)
  # Formula: BMI = weight (kg) / height (m)²
  #
  # @return [Float, nil] BMI value, or nil if height or weight is missing
  def bmi
    return nil unless height.present? && weight.present? && height > 0 && weight > 0

    height_in_meters = height / 100.0
    (weight.to_f / (height_in_meters**2)).round(1)
  end

  # Calculates Basal Metabolic Rate (BMR) using Mifflin-St Jeor Equation
  # This is the number of calories your body burns at rest
  #
  # Formula:
  # - Men: BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age(years) + 5
  # - Women: BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age(years) - 161
  #
  # @return [Float, nil] BMR in calories per day, or nil if required data is missing
  def bmr
    return nil unless height.present? && weight.present? && age.present?
    return nil unless height > 0 && weight > 0 && age > 0

    base_bmr = (10 * weight) + (6.25 * height) - (5 * age)

    # Adjust based on gender (or use average if prefer_not_to_say)
    case gender
    when "male"
      base_bmr + 5
    when "female"
      base_bmr - 161
    else
      # Use average of male and female formulas if gender not specified
      ((base_bmr + 5) + (base_bmr - 161)) / 2.0
    end.round
  end

  # Calculates Total Daily Energy Expenditure (TDEE)
  # This is the total number of calories burned per day including activity
  # Formula: TDEE = BMR × Activity Multiplier
  #
  # Activity multipliers:
  # - Sedentary: 1.2
  # - Lightly active: 1.375
  # - Moderately active: 1.55
  # - Very active: 1.725
  # - Extra active: 1.9
  #
  # @return [Float, nil] TDEE in calories per day, or nil if BMR or activity_level is missing
  def tdee
    bmr_value = bmr
    return nil unless bmr_value.present? && activity_level.present?

    activity_multipliers = {
      "sedentary" => 1.2,
      "lightly_active" => 1.375,
      "moderately_active" => 1.55,
      "very_active" => 1.725,
      "extra_active" => 1.9
    }

    multiplier = activity_multipliers[activity_level] || 1.2
    (bmr_value * multiplier).round
  end

  # Gets human-readable BMI category
  #
  # @return [String, nil] BMI category or nil if BMI cannot be calculated
  def bmi_category
    bmi_value = bmi
    return nil unless bmi_value

    case bmi_value
    when 0...18.5
      "Underweight"
    when 18.5...25
      "Normal weight"
    when 25...30
      "Overweight"
    else
      "Obese"
    end
  end

  private

  # Initialize allergies hash with all standard allergies set to false
  def initialize_allergies
    return if allergies.present?

    self.allergies = STANDARD_ALLERGIES.each_with_object({}) do |allergy, hash|
      hash[allergy] = false
    end
  end

  # Initialize appliances hash with defaults: stove, oven, kettle set to true
  # Sets defaults for new users and existing users who haven't set appliances yet
  def initialize_appliances
    # Only set defaults if appliances is nil or empty (not if user has explicitly set values)
    return if appliances.present? && appliances.is_a?(Hash) && appliances.any?

    # Default appliances that most users have
    default_appliances = %w[stove oven kettle]

    self.appliances = STANDARD_APPLIANCES.each_with_object({}) do |appliance, hash|
      hash[appliance] = default_appliances.include?(appliance)
    end
  end

  # Format allergy key to human-readable name
  #
  # @param key [String] Allergy key (e.g., "tree_nuts")
  # @return [String] Formatted name (e.g., "Tree nuts")
  def format_allergy_name(key)
    key.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  # Format appliance key to human-readable name
  #
  # @param key [String] Appliance key (e.g., "stick_blender")
  # @return [String] Formatted name (e.g., "Stick blender")
  def format_appliance_name(key)
    key.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end
end
