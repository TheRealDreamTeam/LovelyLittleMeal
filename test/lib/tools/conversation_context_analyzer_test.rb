require "test_helper"
require_relative "../../../app/lib/tools/conversation_context_analyzer"

class ConversationContextAnalyzerTest < ActiveSupport::TestCase
  def setup
    @analyzer = Tools::ConversationContextAnalyzer.new
  end

  test "returns first message context when conversation history is empty" do
    result = @analyzer.execute(conversation_history: "")

    assert result[:is_first_message]
    assert_equal [], result[:previous_topics]
    assert_equal [], result[:recent_changes]
    assert_equal "friendly", result[:conversation_tone]
    assert result[:greeting_needed]
  end

  test "returns first message context when conversation history is nil" do
    result = @analyzer.execute(conversation_history: nil)

    assert result[:is_first_message]
    assert result[:greeting_needed]
  end

  test "builds analysis prompt correctly" do
    conversation_history = "User: I want chicken fajitas\nAssistant: Here's your recipe..."
    
    prompt = @analyzer.send(:build_analysis_prompt, conversation_history)

    assert_includes prompt, conversation_history
    assert_includes prompt, "Analyze the following conversation history"
  end

  test "parses analysis result with string keys" do
    response_hash = {
      "is_first_message" => false,
      "previous_topics" => ["recipe creation"],
      "recent_changes" => ["added salt"],
      "conversation_tone" => "friendly",
      "greeting_needed" => false
    }

    result = @analyzer.send(:parse_analysis_result, response_hash)

    assert_not result[:is_first_message]
    assert_includes result[:previous_topics], "recipe creation"
    assert_includes result[:recent_changes], "added salt"
    assert_equal "friendly", result[:conversation_tone]
    assert_not result[:greeting_needed]
  end

  test "parses analysis result with symbol keys" do
    response_hash = {
      is_first_message: false,
      previous_topics: ["greeting"],
      recent_changes: [],
      conversation_tone: "casual",
      greeting_needed: false
    }

    result = @analyzer.send(:parse_analysis_result, response_hash)

    assert_not result[:is_first_message]
    assert_equal "casual", result[:conversation_tone]
  end

  test "handles missing fields with defaults" do
    response_hash = {
      "is_first_message" => false
      # Missing other fields
    }

    result = @analyzer.send(:parse_analysis_result, response_hash)

    assert_equal [], result[:previous_topics]
    assert_equal [], result[:recent_changes]
    assert_equal "friendly", result[:conversation_tone]
    assert_equal false, result[:greeting_needed]
  end

  test "converts array fields to arrays" do
    response_hash = {
      "is_first_message" => false,
      "previous_topics" => "not an array", # Should be converted to array
      "recent_changes" => nil, # Should become empty array
      "conversation_tone" => "friendly",
      "greeting_needed" => false
    }

    result = @analyzer.send(:parse_analysis_result, response_hash)

    assert_kind_of Array, result[:previous_topics]
    assert_kind_of Array, result[:recent_changes]
  end
end

