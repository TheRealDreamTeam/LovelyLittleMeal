require "test_helper"
require_relative "../../../app/lib/tools/recipe_link_extractor"

class RecipeLinkExtractorTest < ActiveSupport::TestCase
  def setup
    @extractor = Tools::RecipeLinkExtractor
  end

  test "normalizes URL by adding https://" do
    normalized = @extractor.send(:normalize_url, "example.com/recipe")
    assert_equal "https://example.com/recipe", normalized
  end

  test "keeps URL unchanged if protocol exists" do
    normalized = @extractor.send(:normalize_url, "https://example.com/recipe")
    assert_equal "https://example.com/recipe", normalized
  end

  test "keeps http:// URLs unchanged" do
    normalized = @extractor.send(:normalize_url, "http://example.com/recipe")
    assert_equal "http://example.com/recipe", normalized
  end

  test "extracts ingredients from array of strings" do
    data = ["200g flour", "100g sugar", "2 eggs"]
    result = @extractor.send(:extract_ingredients_from_structured, data)
    assert_equal data, result
  end

  test "extracts ingredients from array of hashes" do
    data = [
      { "text" => "200g flour" },
      { "name" => "100g sugar" },
      "2 eggs"
    ]
    result = @extractor.send(:extract_ingredients_from_structured, data)
    assert_equal ["200g flour", "100g sugar", "2 eggs"], result
  end

  test "extracts ingredients from single string" do
    data = "200g flour"
    result = @extractor.send(:extract_ingredients_from_structured, data)
    assert_equal [data], result
  end

  test "returns empty array for nil ingredients" do
    result = @extractor.send(:extract_ingredients_from_structured, nil)
    assert_equal [], result
  end

  test "extracts instructions from array of strings" do
    data = ["Step 1: Mix ingredients", "Step 2: Bake for 30 minutes"]
    result = @extractor.send(:extract_instructions_from_structured, data)
    assert_equal data, result
  end

  test "extracts instructions from array of hashes" do
    data = [
      { "text" => "Mix ingredients" },
      { "name" => "Bake for 30 minutes" },
      { "@value" => "Serve hot" }
    ]
    result = @extractor.send(:extract_instructions_from_structured, data)
    assert_equal ["Mix ingredients", "Bake for 30 minutes", "Serve hot"], result
  end

  test "normalizes recipe data with all fields" do
    data = {
      title: "Test Recipe",
      description: "A test recipe",
      ingredients: ["200g flour"],
      instructions: ["Mix and bake"]
    }
    result = @extractor.send(:normalize_recipe_data, data)
    assert_equal "Test Recipe", result[:title]
    assert_equal "A test recipe", result[:description]
    assert_equal ["200g flour"], result[:ingredients]
    assert_equal ["Mix and bake"], result[:instructions]
  end

  test "normalizes recipe data with missing fields" do
    data = {
      title: "Test Recipe"
    }
    result = @extractor.send(:normalize_recipe_data, data)
    assert_equal "Test Recipe", result[:title]
    assert_equal "", result[:description]
    assert_equal [], result[:ingredients]
    assert_equal [], result[:instructions]
  end

  test "normalizes recipe data with string keys" do
    data = {
      "title" => "Test Recipe",
      "ingredients" => ["200g flour"]
    }
    result = @extractor.send(:normalize_recipe_data, data)
    assert_equal "Test Recipe", result[:title]
    assert_equal ["200g flour"], result[:ingredients]
  end

  test "extracts from JSON-LD with Recipe schema" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
          {
            "@type": "Recipe",
            "name": "Chocolate Cake",
            "description": "A delicious chocolate cake",
            "recipeIngredient": ["200g flour", "100g sugar"],
            "recipeInstructions": [
              {"@type": "HowToStep", "text": "Mix ingredients"},
              {"@type": "HowToStep", "text": "Bake for 30 minutes"}
            ]
          }
          </script>
        </head>
      </html>
    HTML

    doc = Nokogiri::HTML(html)
    result = @extractor.send(:extract_from_json_ld, doc)

    assert_not_nil result
    assert_equal "Chocolate Cake", result[:title]
    assert_equal "A delicious chocolate cake", result[:description]
    assert_includes result[:ingredients], "200g flour"
    assert_includes result[:instructions], "Mix ingredients"
  end

  test "extracts from JSON-LD with array format" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
          [{
            "@type": "Recipe",
            "name": "Chocolate Cake",
            "recipeIngredient": ["200g flour"]
          }]
          </script>
        </head>
      </html>
    HTML

    doc = Nokogiri::HTML(html)
    result = @extractor.send(:extract_from_json_ld, doc)

    assert_not_nil result
    assert_equal "Chocolate Cake", result[:title]
  end

  test "extracts from microdata" do
    html = <<~HTML
      <html>
        <body>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">Chocolate Cake</h1>
            <p itemprop="description">A delicious cake</p>
            <ul>
              <li itemprop="recipeIngredient">200g flour</li>
              <li itemprop="recipeIngredient">100g sugar</li>
            </ul>
            <ol>
              <li itemprop="recipeInstructions">Mix ingredients</li>
              <li itemprop="recipeInstructions">Bake for 30 minutes</li>
            </ol>
          </div>
        </body>
      </html>
    HTML

    doc = Nokogiri::HTML(html)
    result = @extractor.send(:extract_from_microdata, doc)

    assert_not_nil result
    assert_equal "Chocolate Cake", result[:title]
    assert_includes result[:ingredients], "200g flour"
    assert_includes result[:instructions], "Mix ingredients"
  end

  test "extracts from common HTML patterns" do
    html = <<~HTML
      <html>
        <body>
          <h1>Chocolate Cake</h1>
          <div class="recipe-description">A delicious cake</div>
          <div class="ingredients">
            <p>200g flour</p>
            <p>100g sugar</p>
          </div>
          <div class="instructions">
            <p>Mix ingredients</p>
            <p>Bake for 30 minutes</p>
          </div>
        </body>
      </html>
    HTML

    doc = Nokogiri::HTML(html)
    result = @extractor.send(:extract_from_common_patterns, doc)

    assert_not_nil result
    assert_equal "Chocolate Cake", result[:title]
    assert_includes result[:ingredients], "200g flour"
    assert_includes result[:instructions], "Mix ingredients"
  end

  test "raises error for blank URL" do
    assert_raises(Tools::InvalidInputError) do
      @extractor.extract("")
    end
  end

  test "raises error for nil URL" do
    assert_raises(Tools::InvalidInputError) do
      @extractor.extract(nil)
    end
  end
end

