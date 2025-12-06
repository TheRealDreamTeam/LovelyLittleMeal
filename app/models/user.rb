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

  # Initialize allergies as empty hash if nil
  before_validation :initialize_allergies, on: :create

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

  private

  # Initialize allergies hash with all standard allergies set to false
  def initialize_allergies
    return if allergies.present?

    self.allergies = STANDARD_ALLERGIES.each_with_object({}) do |allergy, hash|
      hash[allergy] = false
    end
  end

  # Format allergy key to human-readable name
  #
  # @param key [String] Allergy key (e.g., "tree_nuts")
  # @return [String] Formatted name (e.g., "Tree nuts")
  def format_allergy_name(key)
    key.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end
end
