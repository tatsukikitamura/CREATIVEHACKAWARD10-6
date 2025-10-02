# frozen_string_literal: true

module OpenaiParsers
  module_function

  def parse_single_question_response(response)
    Rails.logger.info 'Parsing single question OpenAI response...'
    content = response.dig('choices', 0, 'message', 'content')
    Rails.logger.info "Raw content from OpenAI: #{content}"

    return OpenaiFallbacks.generate_fallback_single_question('EI') unless content

    begin
      json_match = content.match(/\{.*\}/m)
      json_content = json_match ? json_match[0] : content
      Rails.logger.info "Extracted JSON content: #{json_content}"

      sanitized = json_content.dup
      sanitized.gsub!(/("optionB"\s*:\s*"[\s\S]*?")\s*\n\s*("dimension")/, "\\1,\n  \\2")

      question_data = JSON.parse(sanitized)
      Rails.logger.info "Successfully parsed JSON: #{question_data.inspect}"

      unless question_data['question'] && question_data['optionA'] &&
             question_data['optionB'] && question_data['dimension']
        Rails.logger.error "Missing required fields in question: #{question_data.inspect}"
        return OpenaiFallbacks.generate_fallback_single_question(question_data['dimension'] || 'EI')
      end

      MbtiQuestion.new(
        question: question_data['question'],
        options: [question_data['optionA'], question_data['optionB']],
        dimension: question_data['dimension']
      )
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      Rails.logger.error "Content that failed to parse: #{content}"
      OpenaiFallbacks.generate_fallback_single_question('EI')
    rescue StandardError => e
      Rails.logger.error "Unexpected error during parsing: #{e.message}"
      Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
      OpenaiFallbacks.generate_fallback_single_question('EI')
    end
  end

  def parse_questions_response(response)
    Rails.logger.info 'Parsing OpenAI response...'
    content = response.dig('choices', 0, 'message', 'content')
    Rails.logger.info "Raw content from OpenAI: #{content}"

    return OpenaiFallbacks.generate_fallback_questions unless content

    begin
      json_match = content.match(/\[.*\]/m)
      json_content = json_match ? json_match[0] : content
      Rails.logger.info "Extracted JSON content: #{json_content}"

      questions_data = JSON.parse(json_content)
      Rails.logger.info "Successfully parsed JSON: #{questions_data.inspect}"

      unless questions_data.is_a?(Array) && questions_data.length.positive?
        Rails.logger.error 'Invalid data structure: expected array with questions'
        return OpenaiFallbacks.generate_fallback_questions
      end

      parsed_questions = questions_data.map do |q|
        unless q['question'] && q['optionA'] && q['optionB'] && q['dimension']
          Rails.logger.error "Missing required fields in question: #{q.inspect}"
          next
        end

        MbtiQuestion.new(
          question: q['question'],
          options: [q['optionA'], q['optionB']],
          dimension: q['dimension']
        )
      end.compact

      return OpenaiFallbacks.generate_fallback_questions if parsed_questions.empty?
      Rails.logger.info "Successfully created #{parsed_questions.length} MbtiQuestion objects"
      parsed_questions
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      Rails.logger.error "Content that failed to parse: #{content}"
      OpenaiFallbacks.generate_fallback_questions
    rescue StandardError => e
      Rails.logger.error "Unexpected error during parsing: #{e.message}"
      Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
      OpenaiFallbacks.generate_fallback_questions
    end
  end
end


