require "test_helper"
require_relative "../../../app/lib/tools/intent_classifier"

class IntentClassifierTest < ActiveSupport::TestCase
  def setup
    @classifier = Tools::IntentClassifier.new
  end

  test "extracts URL from https message" do
    user_message = "Check this out: https://allrecipes.com/recipe/12345"
    result = @classifier.send(:extract_url_from_message, user_message)
    assert_equal "https://allrecipes.com/recipe/12345", result
  end

  test "extracts URL from http message" do
    user_message = "Check this out: http://example.com/recipe"
    result = @classifier.send(:extract_url_from_message, user_message)
    assert_equal "http://example.com/recipe", result
  end

  test "extracts URL from www. message" do
    user_message = "www.example.com/recipe"
    result = @classifier.send(:extract_url_from_message, user_message)
    assert_equal "www.example.com/recipe", result
  end

  test "returns empty string when no URL found" do
    user_message = "I want chicken fajitas"
    result = @classifier.send(:extract_url_from_message, user_message)
    assert_equal "", result
  end

  test "builds classification prompt correctly" do
    user_message = "I want chicken fajitas"
    conversation_history = "Previous: Hello"
    current_recipe_state = "Title: Recipe"

    prompt = @classifier.send(:build_classification_prompt,
                              user_message: user_message,
                              conversation_history: conversation_history,
                              current_recipe_state: current_recipe_state)

    assert_includes prompt, user_message
    assert_includes prompt, conversation_history
    assert_includes prompt, current_recipe_state
  end

  test "builds classification prompt for first message" do
    user_message = "I want chicken fajitas"
    conversation_history = ""
    current_recipe_state = ""

    prompt = @classifier.send(:build_classification_prompt,
                              user_message: user_message,
                              conversation_history: conversation_history,
                              current_recipe_state: current_recipe_state)

    assert_includes prompt, "FIRST message"
    assert_includes prompt, "No recipe exists yet"
    assert_includes prompt, user_message
  end

  test "parses classification result correctly" do
    response_hash = {
      "intent" => "first_message_link",
      "confidence" => 0.95,
      "detected_url" => "",
      "reasoning" => "URL detected"
    }
    user_message = "https://example.com/recipe"

    result = @classifier.send(:parse_classification_result, response_hash, user_message)

    assert_equal "first_message_link", result[:intent]
    assert_equal 0.95, result[:confidence]
    assert_equal "https://example.com/recipe", result[:detected_url]
    assert_equal "URL detected", result[:reasoning]
  end

  test "parses classification result with symbol keys" do
    response_hash = {
      intent: "modification",
      confidence: 0.9,
      detected_url: "",
      reasoning: "User wants to modify"
    }
    user_message = "add salt"

    result = @classifier.send(:parse_classification_result, response_hash, user_message)

    assert_equal "modification", result[:intent]
    assert_equal 0.9, result[:confidence]
  end

  test "handles missing confidence in response" do
    response_hash = {
      "intent" => "question",
      "reasoning" => "User asked a question"
    }
    user_message = "How long?"

    result = @classifier.send(:parse_classification_result, response_hash, user_message)

    assert_equal "question", result[:intent]
    assert result[:confidence] > 0.0 # Should have default confidence
  end
end

