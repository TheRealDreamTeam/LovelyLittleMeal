class UsersController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    permitted = user_params

    # Handle appliances (still stored as comma-separated string)
    permitted[:appliances] = Array(permitted[:appliances]).reject(&:blank?).join(", ") if permitted.key?(:appliances)

    # Handle allergies (stored as hash with boolean values)
    if permitted.key?(:allergies)
      allergies_hash = permitted[:allergies] || {}
      # Convert checkbox values (1/0 or true/false) to boolean hash
      # Initialize with all standard allergies set to false
      normalized_allergies = User::STANDARD_ALLERGIES.each_with_object({}) do |allergy, hash|
        value = allergies_hash[allergy] || allergies_hash[allergy.to_sym]
        # Convert string "1" or "true" to boolean true, everything else to false
        hash[allergy] = [true, "true", "1", 1].include?(value)
      end
      permitted[:allergies] = normalized_allergies
    end

    if @user.update(permitted)
      redirect_to recipes_path, notice: "Settings updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    # Permit allergies as a hash with string keys for each standard allergy
    # Rails strong parameters requires us to permit each key individually
    base_params = params.require(:user).permit(
      :preferences,
      :system_prompt,
      :age,
      :weight,
      :gender,
      appliances: []
    )

    # Permit allergies hash with all standard allergy keys
    if params[:user] && params[:user][:allergies]
      allergies_hash = params[:user][:allergies].permit(User::STANDARD_ALLERGIES.map(&:to_sym))
      base_params[:allergies] = allergies_hash
    end

    base_params
  end
end
