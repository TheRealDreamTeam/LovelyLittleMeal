require "ruby_llm/tool"
require_relative "conversation_context_schema"

# Analyzes conversation history to determine message structure and context
# Uses GPT-4.1-nano for fast, cost-effective analysis
#
# Purpose:
# - Determines if greeting is needed (only on first message)
# - Tracks conversation flow for better context
# - Enables personalized follow-up messages
#
# Reference: https://rubyllm.com/tools/
module Tools
  class ConversationContextAnalyzer < RubyLLM::Tool
    description "Analyzes conversation history to determine message structure, context, and whether a greeting is needed"

    # Define parameters using params DSL (RubyLLM v1.9+)
    # Reference: https://rubyllm.com/tools/#params-dsl
    params do
      string :conversation_history, description: "Full conversation history formatted as text (user and assistant messages)"
    end

    # Execute the context analysis
    # Returns structured context analysis result
    def execute(conversation_history: "")
      # If no conversation history, this is clearly a first message
      if conversation_history.blank?
        return {
          is_first_message: true,
          previous_topics: [],
          recent_changes: [],
          conversation_tone: "friendly",
          greeting_needed: true
        }
      end

      # Build analysis prompt
      analysis_prompt = build_analysis_prompt(conversation_history)

      # Use GPT-4.1-nano for fast analysis
      # Reference: https://rubyllm.com/tools/
      chat = RubyLLM.chat(model: "gpt-4.1-nano")
                     .with_instructions(analysis_instructions)
                     .with_schema(ConversationContextSchema)

      # Ask for analysis
      response = chat.ask(analysis_prompt).content

      # Parse and return structured result
      parse_analysis_result(response)
    end

    private

    # Builds the analysis prompt from conversation history
    def build_analysis_prompt(conversation_history)
      <<~PROMPT
        Analyze the following conversation history and provide context metadata:

        Conversation History:
        #{conversation_history}

        Determine:
        1. Is this the first message? (true if no previous messages exist)
        2. What topics were discussed? (extract key topics from previous messages)
        3. What recent changes were made? (if any recipe modifications occurred)
        4. What is the conversation tone? (friendly, formal, casual, technical, or mixed)
        5. Is a greeting needed? (only true for first messages)
      PROMPT
    end

    # Instructions for the analysis LLM
    def analysis_instructions
      <<~INSTRUCTIONS
        You are a conversation context analyzer for a recipe generation application. Your job is to analyze conversation history and extract structured context metadata.

        **Analysis Rules:**

        1. **is_first_message**: 
           - Set to `true` ONLY if there are no previous messages in the conversation
           - If any messages exist before the current one, set to `false`

        2. **previous_topics**:
           - Extract key topics discussed in previous messages
           - Examples: "recipe creation", "ingredient modification", "cooking questions", "allergy concerns", "appliance compatibility"
           - Return as an array of strings
           - If no previous messages, return empty array

        3. **recent_changes**:
           - List any recipe modifications mentioned in the conversation
           - Examples: "added salt", "removed dairy", "made vegetarian", "reduced cooking time"
           - Return as an array of strings
           - If no changes mentioned, return empty array

        4. **conversation_tone**:
           - Analyze the overall tone of the conversation
           - Options: "friendly", "formal", "casual", "technical", "mixed"
           - Default to "friendly" if uncertain
           - Consider both user and assistant messages

        5. **greeting_needed**:
           - Set to `true` ONLY if this is the first message (is_first_message is true)
           - Set to `false` for all follow-up messages
           - This prevents repetitive greetings in ongoing conversations

        **Output Requirements:**
        - Return all fields as specified in the schema
        - Be accurate and concise
        - Focus on actionable context that helps generate appropriate responses
      INSTRUCTIONS
    end

    # Parses the LLM response into structured result
    def parse_analysis_result(response)
      result = response.is_a?(Hash) ? response : response.to_h

      {
        is_first_message: result["is_first_message"] || result[:is_first_message] || false,
        previous_topics: Array(result["previous_topics"] || result[:previous_topics] || []),
        recent_changes: Array(result["recent_changes"] || result[:recent_changes] || []),
        conversation_tone: result["conversation_tone"] || result[:conversation_tone] || "friendly",
        greeting_needed: result["greeting_needed"] || result[:greeting_needed] || false
      }
    end
  end
end

