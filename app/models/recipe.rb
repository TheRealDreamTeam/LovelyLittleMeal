class Recipe < ApplicationRecord
  has_one :chat, dependent: :destroy
  
  # Active Storage attachment for recipe image
  # Images are generated asynchronously via RecipeImageGenerationJob using RubyLLM.paint
  # The image is generated after the recipe is created/updated to ensure accuracy
  has_one_attached :image
end
