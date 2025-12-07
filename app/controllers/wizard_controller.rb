# frozen_string_literal: true

# Controller for the user onboarding wizard
# Guides new users through setting up their profile in 4 steps:
# 1. Physical Basics (Age, Weight, Height, Gender)
# 2. Activity & Goals (Activity Level, Fitness Goal)
# 3. Dietary Needs (Allergies, Preferences)
# 4. Kitchen Equipment (Appliances)
class WizardController < ApplicationController
  before_action :authenticate_user!

  # Show wizard step (1-4)
  def show
    @user = current_user
    @step = params[:step].to_i
    @step = 1 if @step < 1 || @step > 4

    # Set defaults for activity_level and goal if not already set
    # This ensures the wizard shows the defaults as pre-selected in step 2
    # We set them in memory (not saved) so the form helpers will check the right radio buttons
    if @user.activity_level.nil?
      @user.activity_level = :lightly_active
    end
    if @user.goal.nil?
      @user.goal = :maintain_weight
    end

    # Don't redirect if we're actively going through the wizard
    # Allow user to see all steps even if some data is already filled
    # Only redirect if wizard is truly complete (all steps explicitly filled) AND user is trying to go back to step 1
    # This allows users to complete the wizard even if they have some defaults set
    if wizard_complete? && @step == 1
      redirect_to recipes_path
    end
  end

  # Update user data for current step and proceed to next step
  def update
    @user = current_user
    @step = params[:step].to_i
    @step = 1 if @step < 1 || @step > 4

    permitted = wizard_params_for_step(@step)

    # Handle appliances (stored as hash with boolean values)
    if permitted.key?(:appliances)
      appliances_hash = permitted[:appliances] || {}
      normalized_appliances = User::STANDARD_APPLIANCES.each_with_object({}) do |appliance, hash|
        value = appliances_hash[appliance] || appliances_hash[appliance.to_sym]
        hash[appliance] = [true, "true", "1", 1].include?(value)
      end
      permitted[:appliances] = normalized_appliances
    end

    # Handle allergies (stored as hash with boolean values)
    if permitted.key?(:allergies)
      allergies_hash = permitted[:allergies] || {}
      normalized_allergies = User::STANDARD_ALLERGIES.each_with_object({}) do |allergy, hash|
        value = allergies_hash[allergy] || allergies_hash[allergy.to_sym]
        hash[allergy] = [true, "true", "1", 1].include?(value)
      end
      permitted[:allergies] = normalized_allergies
    end

    if @user.update(permitted)
      # Determine next step or completion
      next_step = @step < 4 ? @step + 1 : nil

      if next_step
        redirect_to wizard_path(step: next_step), notice: "Step #{@step} saved!"
      else
        redirect_to recipes_path, notice: "Welcome! Your profile is complete."
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  # Skip current step and go to next
  def skip
    @step = params[:step].to_i
    @step = 1 if @step < 1 || @step > 4

    next_step = @step < 4 ? @step + 1 : nil

    if next_step
      redirect_to wizard_path(step: next_step), notice: "Step #{@step} skipped. You can complete it later in settings."
    else
      redirect_to recipes_path, notice: "Welcome! You can complete your profile later in settings."
    end
  end

  private

  # Check if wizard is complete (user has filled in some data for all steps)
  # Note: We check if user has explicitly filled in required fields, not just defaults
  def wizard_complete?
    user = current_user
    return false unless user

    # Step 1: Physical basics - all required fields must be filled
    step1_complete = user.age.present? && user.weight.present? && user.height.present? && user.gender.present?
    # Step 2: Activity & Goals - both must be set (defaults are fine, they count as "filled")
    step2_complete = user.activity_level.present? && user.goal.present?
    # Step 3: Dietary needs - at least one allergy selected OR preferences filled
    # Note: Empty allergies hash or nil counts as not filled (user hasn't explicitly set anything)
    step3_complete = (user.allergies.is_a?(Hash) && user.allergies.values.any?) || user.preferences.present?
    # Step 4: Kitchen equipment - at least one appliance selected
    # Note: Default appliances (stove, oven, kettle) count as "filled" since they're set on creation
    # But we still want to show step 4 so user can review/change them
    step4_complete = user.appliances.is_a?(Hash) && user.appliances.values.any?

    # Only return true if all steps are complete AND user has explicitly visited step 4
    # We check this by seeing if user has any non-default appliances or has explicitly set them
    # For now, we'll be lenient - if step 4 has appliances, we consider it complete
    # But we'll allow showing step 4 in the show action above
    step1_complete && step2_complete && step3_complete && step4_complete
  end

  # Get permitted params for specific wizard step
  def wizard_params_for_step(step)
    case step
    when 1
      # Step 1: Physical Basics
      params.require(:user).permit(:age, :weight, :height, :gender)
    when 2
      # Step 2: Activity & Goals
      params.require(:user).permit(:activity_level, :goal)
    when 3
      # Step 3: Dietary Needs
      base_params = params.require(:user).permit(:preferences)
      if params[:user] && params[:user][:allergies]
        allergies_hash = params[:user][:allergies].permit(User::STANDARD_ALLERGIES.map(&:to_sym))
        base_params[:allergies] = allergies_hash
      end
      base_params
    when 4
      # Step 4: Kitchen Equipment
      base_params = {}
      if params[:user] && params[:user][:appliances]
        appliances_hash = params[:user][:appliances].permit(User::STANDARD_APPLIANCES.map(&:to_sym))
        base_params[:appliances] = appliances_hash
      end
      base_params
    else
      {}
    end
  end
end

