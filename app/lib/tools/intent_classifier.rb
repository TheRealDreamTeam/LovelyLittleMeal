require "ruby_llm/tool"
require_relative "intent_classification_schema"

# Classifies user intent to determine the correct execution path
# Uses GPT-4.1-nano for fast, cost-effective classification
#
# Classification categories:
# - first_message_link: User pasted a URL/link to a recipe
# - first_message_free_text: User provided free text recipe request
# - first_message_complete_recipe: User pasted complete recipe text
# - first_message_query: User asking a general question (no recipe yet)
# - question: User asking about existing recipe (no modifications)
# - modification: User requesting changes to existing recipe
# - clarification: User needs more information before proceeding
#
# Reference: https://rubyllm.com/tools/
module Tools
  class IntentClassifier < RubyLLM::Tool
    description "Classifies user intent to determine the correct execution path for recipe generation"

    # Define parameters using params DSL (RubyLLM v1.9+)
    # Reference: https://rubyllm.com/tools/#params-dsl
    params do
      string :user_message, description: "The current user message to classify"
      string :conversation_history,
             description: "Previous messages in the conversation (formatted as text), empty if first message"
      string :current_recipe_state,
             description: "Current recipe state if recipe exists (title, description), empty string if no recipe yet"
    end

    # Execute the classification
    # Returns structured classification result with intent, confidence, detected_url, and reasoning
    def execute(user_message:, conversation_history: "", current_recipe_state: "")
      # Build classification prompt
      classification_prompt = build_classification_prompt(
        user_message: user_message,
        conversation_history: conversation_history,
        current_recipe_state: current_recipe_state
      )

      # Use GPT-4.1-nano for fast classification
      # Reference: https://rubyllm.com/tools/
      chat = RubyLLM.chat(model: "gpt-4.1-nano")
                    .with_instructions(classification_instructions)
                    .with_schema(IntentClassificationSchema)

      # Ask for classification
      response = chat.ask(classification_prompt).content

      # Parse and return structured result
      parse_classification_result(response, user_message)
    end

    private

    # Builds the classification prompt from inputs
    def build_classification_prompt(user_message:, conversation_history:, current_recipe_state:)
      parts = []

      if conversation_history.present?
        parts << "Conversation history:\n#{conversation_history}"
      else
        parts << "This is the FIRST message in the conversation (no previous messages)"
      end

      if current_recipe_state.present?
        parts << "Current recipe state:\n#{current_recipe_state}"
      else
        parts << "No recipe exists yet"
      end

      parts << "User message to classify:\n#{user_message}"

      parts.join("\n\n")
    end

    # Instructions for the classification LLM
    def classification_instructions
      <<~INSTRUCTIONS
        You are an intent classifier for a recipe generation application. Your job is to accurately classify user messages into one of these categories:

        **Classification Categories:**

        1. **first_message_link**: User pasted a URL/link to a recipe website
           - Look for URLs (http://, https://, www.)
           - This is the FIRST message (no conversation history)
           - User wants to import a recipe from a link

        2. **first_message_free_text**: User provided free text recipe request
           - This is the FIRST message (no conversation history)
           - User describes what they want (e.g., "I want chicken fajitas", "Make me a pasta dish")
           - NOT a complete recipe, NOT a link, NOT just a question

        3. **first_message_complete_recipe**: User pasted complete recipe text
           - This is the FIRST message (no conversation history)
           - User pasted a full recipe with ingredients and instructions
           - Usually multiple lines, contains ingredient lists and steps

        4. **first_message_query**: User asking a general question (no recipe yet)
           - This is the FIRST message (no conversation history)
           - User is asking a question (e.g., "What can you do?", "How does this work?")
           - No recipe exists yet

        5. **question**: User asking about existing recipe (no modifications)
           - Recipe exists (current_recipe_state is not empty)
           - User is asking a question (e.g., "How long does this take?", "What can I substitute?")
           - User is NOT requesting changes

        6. **modification**: User requesting changes to existing recipe
           - Recipe exists (current_recipe_state is not empty)
           - User wants to modify the recipe (e.g., "add salt", "make it vegetarian", "reduce cooking time")
           - Uses action verbs: add, remove, change, reduce, increase, make, use, replace, etc.

        7. **clarification**: User needs more information before proceeding
           - User is asking for clarification or more context
           - Usually a follow-up question that needs more info

        **Rules:**
        - If conversation_history is empty AND current_recipe_state is empty → Must be first_message_* category
        - If current_recipe_state is present → Must be question, modification, or clarification
        - Look for URLs in user_message (http://, https://, www.) → first_message_link
        - Look for action verbs (add, remove, change, etc.) → modification
        - Look for question words (how, what, when, where, why, is, are, can, will, do, does) → question or first_message_query
        - If message is very long with ingredients and steps → first_message_complete_recipe

        **Output Requirements:**
        - intent: One of the 7 categories above (exact match required)
        - confidence: 0.0 to 1.0 (be honest about uncertainty)
        - detected_url: The URL if intent is first_message_link, otherwise empty string
        - reasoning: Brief explanation (1-2 sentences) of why this intent was chosen
      INSTRUCTIONS
    end

    # Parses the LLM response and extracts URL if present
    def parse_classification_result(response, user_message)
      result = response.is_a?(Hash) ? response : response.to_h

      # Extract URL from user message if intent is first_message_link
      detected_url = if result["intent"] == "first_message_link"
                       extract_url_from_message(user_message)
                     else
                       ""
                     end

      {
        intent: result["intent"] || result[:intent],
        confidence: (result["confidence"] || result[:confidence] || 0.8).to_f,
        detected_url: detected_url,
        reasoning: result["reasoning"] || result[:reasoning] || "Classification completed"
      }
    end

    # Extracts URL from user message using simple regex
    def extract_url_from_message(message)
      # Match http://, https://, or www. patterns
      url_pattern = %r{(https?://[^\s]+|www\.[^\s]+)}
      match = message.match(url_pattern)
      match ? match[0] : ""
    end
  end
end
