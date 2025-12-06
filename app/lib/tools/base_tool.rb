# Base module for all tools in the agentic workflow system
# Provides common functionality and patterns for tool implementation
#
# Tools can either:
# 1. Extend RubyLLM::Tool (for LLM-based tools)
# 2. Include this module (for pure Ruby tools)
# 3. Use this as a reference for common patterns
module Tools
  module BaseTool
    # Common validation result structure
    # All validation tools should return results in this format
    ValidationResult = Struct.new(
      :valid,           # boolean - whether validation passed
      :violations,      # array of violation hashes
      :fix_instructions # string - instructions for fixing violations
    ) do
      def valid?
        valid == true
      end

      def has_violations?
        violations.any?
      end
    end

    # Helper method to create a validation result
    def self.validation_result(valid:, violations: [], fix_instructions: nil)
      ValidationResult.new(valid, violations, fix_instructions)
    end

    # Helper method to create a violation hash
    def self.violation(type:, message:, field: nil, fix_instruction: nil)
      {
        type: type,
        message: message,
        field: field,
        fix_instruction: fix_instruction
      }
    end
  end
end

