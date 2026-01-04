require 'openai'

class OpenaiService
  def initialize
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def generate_professional_summary(profile_data, job_data)
    prompt = build_summary_prompt(profile_data, job_data)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 200,
        temperature: 0.7
      }
    )
    
    response.dig("choices", 0, "message", "content")&.strip || "Professional with proven expertise in delivering quality solutions."
  rescue => e
    Rails.logger.error "OpenAI Summary Error: #{e.message}"
    "Professional with proven expertise in delivering quality solutions."
  end

  def analyze_and_optimize_skills(user_skills, job_requirements)
    prompt = build_skills_prompt(user_skills, job_requirements)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 150,
        temperature: 0.3
      }
    )
    
    content = response.dig("choices", 0, "message", "content")&.strip
    parse_skills_response(content, user_skills)
  rescue => e
    Rails.logger.error "OpenAI Skills Error: #{e.message}"
    user_skills.take(8) # Fallback to first 8 skills
  end

  def rewrite_work_experience(experience, job_requirements)
    return experience['description'] if experience['description'].blank?
    
    prompt = build_experience_prompt(experience, job_requirements)
    
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 300,
        temperature: 0.6
      }
    )
    
    content = response.dig("choices", 0, "message", "content")&.strip
    content || experience['description']
  rescue => e
    Rails.logger.error "OpenAI Experience Error: #{e.message}"
    experience['description']
  end

  private

  def build_summary_prompt(profile_data, job_data)
    name = profile_data['name'] || profile_data[:name] || 'Professional'
    current_role = get_current_role(profile_data)
    company = job_data['company'] || job_data[:company] || 'the company'
    job_title = job_data['title'] || job_data[:title] || 'the role'
    
    <<~PROMPT
      Write a professional resume summary (2-3 sentences, max 50 words) for #{name}.
      
      Current role: #{current_role}
      Target job: #{job_title} at #{company}
      
      Requirements:
      - Highlight relevant experience and skills
      - Show enthusiasm for the target role
      - Use action words and quantifiable achievements where possible
      - Professional tone suitable for ATS systems
      
      Return only the summary text, no additional formatting.
    PROMPT
  end

  def build_skills_prompt(user_skills, job_requirements)
    <<~PROMPT
      Given the user's skills and job requirements, select and prioritize the most relevant skills.
      
      User's Skills: #{user_skills.join(', ')}
      Job Requirements: #{job_requirements}
      
      Instructions:
      1. Select 6-8 most relevant skills from user's skills that match job requirements
      2. Prioritize skills mentioned in job description
      3. Only return skills the user actually has
      4. Format as comma-separated list
      
      Return only the optimized skills list, nothing else.
    PROMPT
  end

  def build_experience_prompt(experience, job_requirements)
    <<~PROMPT
      Rewrite this work experience description to better match the job requirements:
      
      Current Role: #{experience['designation']} at #{experience['company']}
      Current Description: #{experience['description']}
      
      Job Requirements: #{job_requirements}
      
      Instructions:
      - Keep the same role and company
      - Rewrite responsibilities and achievements to highlight relevant skills
      - Use action verbs and quantify achievements where possible
      - Match keywords from job requirements
      - Keep it concise (3-4 bullet points max)
      - Make it ATS-friendly
      
      Return only the improved description, formatted as bullet points.
    PROMPT
  end

  def get_current_role(profile_data)
    work_exp = profile_data['workExperience'] || profile_data[:workExperience] || []
    current_job = work_exp.find { |job| job['current'] == true } || work_exp.first
    
    if current_job
      "#{current_job['designation']} at #{current_job['company']}"
    else
      "Experienced Professional"
    end
  end

  def parse_skills_response(content, fallback_skills)
    return fallback_skills.take(8) if content.blank?
    
    # Extract skills from response
    skills = content.split(',').map(&:strip).reject(&:blank?)
    
    # Ensure we have valid skills
    skills.any? ? skills.take(8) : fallback_skills.take(8)
  end
end