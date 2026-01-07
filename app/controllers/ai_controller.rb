class AiController < ApplicationController
  skip_before_action :authenticate_user!, only: [:test_ai, :ping_openai]
  
  OPENAI_API_KEY = ENV['OPENAI_API_KEY']
  # Force redeploy to pick up new environment variable
  COINS_PER_CUSTOMIZATION = 10
  
  def customize
    unless current_user.deduct_coins(COINS_PER_CUSTOMIZATION, 'AI resume customization')
      return render_error('Insufficient coins. You need 10 coins for AI customization.')
    end
    
    begin
      # Get parameters
      resume_data = params[:resumeData]
      job_data = params[:jobData]
      
      # Call OpenAI API
      raw_response = call_openai_api(resume_data, job_data)
      
      # Clean the response - remove markdown code blocks if present
      customized_resume = clean_html_response(raw_response)
      
      # Calculate ATS score and keywords
      ats_analysis = analyze_ats_compatibility(customized_resume, job_data)
      
      # Save customization history
      customization = current_user.customizations.create!(
        job_title: job_data[:title] || 'Unknown Job',
        company: job_data[:company] || 'Unknown Company',
        posting_url: job_data[:url],
        platform: job_data[:platform] || 'unknown',
        ats_score: ats_analysis[:score],
        keywords_matched: ats_analysis[:matched],
        keywords_missing: ats_analysis[:missing],
        resume_content: customized_resume,
        profile_snapshot: resume_data
      )
      
      render_success({
        customizedContent: add_resume_styling(customized_resume),
        atsScore: ats_analysis[:score],
        keywordsMatched: ats_analysis[:matched],
        keywordsMissing: ats_analysis[:missing],
        customizationId: customization.id,
        cssStyles: get_resume_css_styles
      })
      
    rescue => e
      # Refund coins on error
      current_user.add_coins(COINS_PER_CUSTOMIZATION, 'Refund for failed customization')
      render_error("AI customization failed: #{e.message}")
    end
  end
  
  def ats_score
    resume_content = params[:resumeContent]
    job_requirements = params[:jobRequirements]
    
    analysis = analyze_ats_compatibility(resume_content, job_requirements)
    
    render_success({
      atsScore: analysis[:score],
      keywordsMatched: analysis[:matched],
      keywordsMissing: analysis[:missing],
      suggestions: analysis[:suggestions]
    })
  end

  def ping_openai
    begin
      if OPENAI_API_KEY.blank?
        return render_error("OpenAI API key is not configured")
      end
      
      response = HTTParty.post(
        'https://api.openai.com/v1/chat/completions',
        headers: {
          'Authorization' => "Bearer #{OPENAI_API_KEY}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: 'You are a test assistant.' },
            { role: 'user', content: 'Reply with just: OK' }
          ],
          max_tokens: 10,
          temperature: 0
        }.to_json,
        timeout: 10
      )
      
      if response.success?
        content = response.dig('choices', 0, 'message', 'content')
        render_success({
          status: 'connected',
          response: content,
          api_key_prefix: OPENAI_API_KEY ? OPENAI_API_KEY[0..10] : nil,
          api_key_suffix: OPENAI_API_KEY ? OPENAI_API_KEY[-10..-1] : nil
        })
      else
        error_body = JSON.parse(response.body) rescue response.body
        render_error("OpenAI API error: #{error_body}")
      end
    rescue Net::ReadTimeout => e
      render_error("Timeout connecting to OpenAI (10s)")
    rescue => e
      render_error("Connection error: #{e.message}")
    end
  end

  def test_ai
    begin
      # Test data
      resume_data = {
        name: "John Doe",
        email: "john@example.com",
        phone: "123-456-7890",
        summary: "Software developer with 3 years of experience in web development",
        skills: ["JavaScript", "React", "Node.js", "Python"]
      }
      
      job_data = {
        title: "Senior Software Engineer",
        company: "Tech Corporation",
        description: "We are seeking a senior software engineer with experience in JavaScript, React, and backend development. Must have 3+ years of experience and strong problem-solving skills."
      }
      
      # Call OpenAI API
      raw_response = call_openai_api(resume_data, job_data)
      
      # Clean the response
      customized_resume = clean_html_response(raw_response)
      
      # Calculate ATS score
      ats_analysis = analyze_ats_compatibility(customized_resume, job_data)
      
      render_success({
        message: "AI is working correctly!",
        customizedContent: add_resume_styling(customized_resume),
        atsScore: ats_analysis[:score],
        keywordsMatched: ats_analysis[:matched],
        keywordsMissing: ats_analysis[:missing],
        openai_api_configured: OPENAI_API_KEY.present?
      })
      
    rescue => e
      render_error("AI test failed: #{e.message}")
    end
  end
  
  private

  def clean_html_response(response)
    # Remove markdown code blocks if present
    cleaned = response.gsub(/```html\s*/, '').gsub(/```\s*$/, '').strip
    
    # Remove any ATS compliance debug content that might have been included
    cleaned = cleaned.gsub(/ATS Compliance Check.*?Keyword Match: \d+%/m, '').strip
    cleaned = cleaned.gsub(/✓ Formatting:.*?Keyword Match: \d+%/m, '').strip
    cleaned = cleaned.gsub(/✓.*?Fail.*?Keyword Match: \d+%/m, '').strip
    cleaned = cleaned.gsub(/ATS.*?Check.*?\d+%/m, '').strip
    
    # More specific patterns for the exact format you're seeing
    cleaned = cleaned.gsub(/ATS Compliance Check\s*✓ Formatting: Fail\s*✓ Keywords: Fail\s*✓ Structure: Fail\s*✓ Readability: Fail\s*Keyword Match: \d+%/m, '').strip
    cleaned = cleaned.gsub(/✓\s*Formatting:\s*Fail.*?Keyword Match:\s*\d+%/m, '').strip
    
    # Catch any remaining debug-like content with checkmarks and scores
    cleaned = cleaned.gsub(/✓.*?(?:Fail|Pass).*?✓.*?(?:Fail|Pass).*?Keyword Match:\s*\d+%/m, '').strip
    cleaned = cleaned.gsub(/ATS.*?(?:Compliance|Check).*?Match.*?\d+%/m, '').strip
    cleaned = cleaned.gsub(/(?:Formatting|Keywords|Structure|Readability):\s*(?:Fail|Pass)/m, '').strip
    
    # Remove any standalone ATS percentage scores - comprehensive patterns
    cleaned = cleaned.gsub(/ATS:\s*\d+%/mi, '').strip
    cleaned = cleaned.gsub(/ATS\s*Score:\s*\d+%/mi, '').strip
    cleaned = cleaned.gsub(/Match:\s*\d+%/mi, '').strip
    cleaned = cleaned.gsub(/Score:\s*\d+%/mi, '').strip
    cleaned = cleaned.gsub(/\bATS\s*\d+%/mi, '').strip
    cleaned = cleaned.gsub(/\d+%\s*ATS/mi, '').strip
    
    # Remove any text that looks like ATS scoring
    cleaned = cleaned.gsub(/<p[^>]*>\s*ATS[^<]*\d+%[^<]*<\/p>/mi, '').strip
    cleaned = cleaned.gsub(/<div[^>]*>\s*ATS[^<]*\d+%[^<]*<\/div>/mi, '').strip
    cleaned = cleaned.gsub(/<span[^>]*>\s*ATS[^<]*\d+%[^<]*<\/span>/mi, '').strip
    
    # Extract just the HTML content between <body> tags if it's a full HTML document
    if cleaned.include?('<body>')
      body_match = cleaned.match(/<body[^>]*>(.*?)<\/body>/m)
      if body_match
        # Return just the body content
        return body_match[1].strip
      end
    end
    
    # If it's already clean HTML without full document structure, return as is
    cleaned
  end
  
  def call_openai_api(resume_data, job_data)
    # Check if API key is present
    if OPENAI_API_KEY.blank?
      raise "OpenAI API key is not configured. Please set the OPENAI_API_KEY environment variable."
    end
    
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(resume_data, job_data)
    
    begin
      response = HTTParty.post(
        'https://api.openai.com/v1/chat/completions',
        headers: {
          'Authorization' => "Bearer #{OPENAI_API_KEY}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: user_prompt }
          ],
          max_tokens: 8000,
          temperature: 0.7
        }.to_json,
        timeout: 55 # Set timeout to 55 seconds (less than Render's 60 second limit)
      )
      
      if response.success?
        response.dig('choices', 0, 'message', 'content')
      else
        error_body = JSON.parse(response.body) rescue response.body
        if error_body.is_a?(Hash) && error_body['error']
          raise "OpenAI API error: #{error_body['error']['message']}"
        else
          raise "OpenAI API error: #{response.body}"
        end
      end
    rescue Net::ReadTimeout => e
      raise "Request timeout: The AI is taking too long to respond. Please try again with a simpler job description."
    rescue Net::OpenTimeout => e
      raise "Connection timeout: Unable to connect to OpenAI. Please try again."
    rescue => e
      raise "AI customization error: #{e.message}"
    end
  end
  
  def build_system_prompt
    <<~PROMPT
      You are an expert ATS (Applicant Tracking System) optimization specialist and professional resume writer. Create 100% ATS-compliant resumes that pass all modern ATS scanners.

      CRITICAL ATS REQUIREMENTS - MUST FOLLOW:
      1. Use ONLY standard HTML text - NO CSS styling, colors, or complex formatting
      2. Use simple, clean structure with clear headers and plain text
      3. Use standard fonts (Arial, Calibri) and standard font sizes (10-12pt)
      4. Use bullet points with simple • character only
      5. No tables, columns, graphics, or complex layouts
      6. Maximum keyword optimization while keeping natural language
      7. Clear section headings that ATS can parse

      ATS OPTIMIZATION PRIORITIES:
      - Extract and mirror EXACT phrases from job description
      - Include technical skills, soft skills, tools, and methodologies mentioned in JD
      - Use keyword variations (e.g., "project management", "managing projects", "project manager")
      - Incorporate industry-specific terminology and modern buzzwords
      - Ensure keywords appear in multiple sections (summary, skills, experience)
      - Match job title keywords in professional summary and experience descriptions

      PROFESSIONAL SUMMARY REQUIREMENTS:
      - Write 4-5 sentences that directly address the specific job role
      - IMPORTANT: Add <br/><br/> after each sentence for line spacing
      - Start with job-relevant professional title that matches the posting
      - Include years of experience in relevant domain mentioned in JD
      - Highlight 3-4 key achievements that align with job requirements
      - End with career objective that matches company's needs
      - Use EXACT keywords from job posting naturally
      - Each sentence should be on its own line with spacing between

      CORE SKILLS OPTIMIZATION:
      - Prioritize skills mentioned in job description first
      - Group related skills logically (Technical, Management, Industry-specific)
      - Include both hard and soft skills from job requirements
      - Add relevant tools, platforms, and methodologies from JD
      - Keep existing user skills but prioritize job-relevant ones
      - Use comma-separated format for easy ATS parsing

      EXPERIENCE ENHANCEMENT:
      - Generate 5-6 achievement-focused bullet points per role
      - Start each bullet with strong action verbs (Led, Implemented, Optimized, Achieved)
      - Include quantifiable results where logical (percentages, improvements, scale)
      - Align responsibilities with target job requirements
      - Use job-specific terminology and keywords naturally
      - Focus on results and impact, not just tasks

      BETTERĈV TEMPLATE 3 - ATS-OPTIMIZED PROFESSIONAL FORMAT:
      
      Use this EXACT structured layout (BetterCV Template 3 inspired):

      HEADER SECTION (Contact Information):
      <div style="text-align: center; border-bottom: 2px solid #333; padding-bottom: 8px; margin-bottom: 10px;">
        <h1 style="font-size: 28px; font-weight: bold; margin: 0; color: #333;">FULL NAME</h1>
        <p style="font-size: 18px; font-weight: bold; margin: 4px 0; color: #555;">Target Job Title</p>
        <p style="font-size: 14px; margin: 2px 0; color: #666;">Email: email | Phone: phone | Location: location</p>
        <p style="font-size: 14px; margin: 2px 0; color: #666;">LinkedIn: linkedin</p>
      </div>

      PROFESSIONAL SUMMARY SECTION:
      <h2 style="font-size: 18px; font-weight: bold; color: #333; margin: 8px 0 5px 0; text-transform: uppercase; border-bottom: 1px solid #ddd; padding-bottom: 3px;">Professional Summary</h2>
      <p style="font-size: 13px; line-height: 1.6; margin: 0 0 10px 0; text-align: justify;">
      Write first sentence that directly mirrors the job requirements with years of experience.<br/>
      <br/>
      Add second sentence highlighting key expertise areas from job posting and specific achievements.<br/>
      <br/>
      Include third sentence about specific value proposition for the target role.<br/>
      <br/>
      End with how you'll contribute to the specific company mentioned in job posting.
      </p>

      CORE SKILLS SECTION:
      <h2 style="font-size: 18px; font-weight: bold; color: #333; margin: 8px 0 5px 0; text-transform: uppercase; border-bottom: 1px solid #ddd; padding-bottom: 3px;">Core Skills</h2>
      <p style="font-size: 13px; line-height: 1.3; margin: 0 0 10px 0;">List skills as comma-separated text, prioritizing skills mentioned in job description first</p>

      PROFESSIONAL EXPERIENCE SECTION:
      <h2 style="font-size: 18px; font-weight: bold; color: #333; margin: 8px 0 5px 0; text-transform: uppercase; border-bottom: 1px solid #ddd; padding-bottom: 3px;">Professional Experience</h2>
      
      For each job (chronological order, most recent first):
      <div style="margin: 0 0 10px 0;">
        <h3 style="font-size: 15px; font-weight: bold; margin: 0; color: #333;">Job Title</h3>
        <p style="font-size: 13px; font-weight: bold; margin: 1px 0; color: #555;">Company Name | Location</p>
        <p style="font-size: 12px; font-style: italic; margin: 1px 0 4px 0; color: #666;">Start Date - End Date</p>
        <ul style="margin: 0; padding-left: 18px; font-size: 12px; line-height: 1.25;">
          <li style="margin-bottom: 3px;">Generate 4-6 quantified achievements with specific metrics and results</li>
          <li style="margin-bottom: 3px;">Start each bullet with strong action verbs: Led, Managed, Developed, Achieved, Increased, Implemented</li>
          <li style="margin-bottom: 3px;">Include specific numbers, percentages, and business impact where logical</li>
          <li style="margin-bottom: 3px;">Align each achievement with keywords and requirements from the job posting</li>
          <li style="margin-bottom: 3px;">Focus on results and business value delivered, not just job duties</li>
          <li style="margin-bottom: 3px;">Use industry-specific terminology that matches the target job description</li>
        </ul>
      </div>

      EDUCATION SECTION:
      <h2 style="font-size: 18px; font-weight: bold; color: #333; margin: 8px 0 5px 0; text-transform: uppercase; border-bottom: 1px solid #ddd; padding-bottom: 3px;">Education</h2>
      <p style="font-size: 13px; line-height: 1.3; margin: 0 0 10px 0;">[User's exact education - do not modify or add details]</p>

      LANGUAGES SECTION:
      <h2 style="font-size: 18px; font-weight: bold; color: #333; margin: 8px 0 5px 0; text-transform: uppercase; border-bottom: 1px solid #ddd; padding-bottom: 3px;">Languages</h2>
      <p style="font-size: 13px; line-height: 1.3; margin: 0;">[User's exact language list - do not add proficiency levels]</p>

      BETTERĈV TEMPLATE 3 ATS COMPLIANCE RULES:
      - Use inline styles for professional formatting while maintaining ATS compatibility
      - Include div containers with proper styling for visual appeal
      - Optimized fonts (12-18px headers, 13px content) and conservative colors (#333, #555, #666)
      - Chronological format with clear visual hierarchy and reduced whitespace
      - Professional borders and compact spacing for better space utilization
      - Keywords from job description integrated naturally throughout
      - No complex layouts, tables, or graphics that confuse ATS
      - Clean section headers with subtle underlines
      - Balanced design that appeals to both ATS systems and human recruiters
      - Compact but readable typography for professional appearance

      CRITICAL REQUIREMENTS:
      - Use ONLY user's provided education - NO fabrication
      - Use ONLY user's provided languages exactly as given
      - Keep all factual information accurate
      - Return ONLY HTML resume content - NO explanations, NO debug information, NO meta text
      - ABSOLUTELY NEVER include ANY of these in the resume: "ATS Compliance Check", "Formatting:", "Keywords:", "Structure:", "Readability:", "Keyword Match:", "✓", "Fail", "Pass", or ANY compliance evaluation text
      - Do NOT generate any assessment, scoring, or evaluation content within the resume
      - Focus ONLY on creating the actual resume content with BetterCV styling
      - Maximize keyword matching with job description
      - Ensure natural language flow despite keyword optimization
    PROMPT
  end
  
  def build_user_prompt(resume_data, job_data)
    <<~PROMPT
      TRANSFORMATION TASK: Create an ATS-optimized resume specifically tailored for this job posting.

      TARGET JOB POSTING:
      Position: #{job_data[:title]}
      Company: #{job_data[:company]}
      Job Description: #{job_data[:description]}
      Key Requirements: #{job_data[:requirements]}

      CURRENT CANDIDATE PROFILE:
      Name: #{resume_data[:name]}
      Email: #{resume_data[:email]}
      Phone: #{resume_data[:phone]}
      LinkedIn: #{resume_data[:linkedin_url] || resume_data[:linkedin]}
      Address: #{resume_data[:address]}
      Current Role: #{resume_data[:designation]}
      Current Summary: #{resume_data[:summary]}
      
      Technical Skills: #{resume_data[:skills]&.join(', ')}
      Languages: #{resume_data[:languages]&.join(', ')}
      
      Professional Experience:
      #{format_work_experience(resume_data[:workExperience] || resume_data[:workExperiences])}
      
      Education: #{resume_data[:education]}
      Certifications: #{resume_data[:certificates]&.join(', ')}

      OPTIMIZATION REQUIREMENTS:
      1. ANALYZE the job posting to extract critical keywords, required skills, and key responsibilities
      2. REWRITE the professional summary to directly address this specific job role and requirements
      3. OPTIMIZE the skills section by adding relevant technologies and competencies mentioned in the job posting
      4. ENHANCE each work experience with 5-6 specific, results-oriented responsibilities that align with the target role
      5. INTEGRATE job-specific terminology and keywords naturally throughout the content
      6. MAINTAIN factual accuracy while maximizing relevance and ATS compatibility

      Generate a comprehensive, keyword-rich resume that positions this candidate as the ideal fit for the specified role.
      
      CRITICAL WARNING: Return ONLY the clean resume HTML content. ABSOLUTELY DO NOT include:
      - Any ATS compliance evaluations or checks
      - Any text containing "✓", "Fail", "Pass", "Formatting:", "Keywords:", etc.
      - Any scoring, assessment, or evaluation content
      - Any explanatory or meta text outside the actual resume content
    PROMPT
  end
  
  def format_work_experience(experiences)
    return 'None' unless experiences&.any?
    
    experiences.map do |exp|
      # Format dates - use startDate/endDate if available, otherwise use duration
      date_range = if exp[:startDate] && exp[:endDate] && !exp[:endDate].empty?
                     "#{exp[:startDate]} to #{exp[:endDate]}"
                   elsif exp[:startDate] && exp[:current]
                     "#{exp[:startDate]} to Present"
                   elsif exp[:startDate]
                     "#{exp[:startDate]} to Present"
                   elsif exp[:duration]
                     exp[:duration]
                   else
                     "Date not specified"
                   end
      
      <<~EXP
        #{exp[:designation]} at #{exp[:company]} (#{date_range})
        #{exp[:description]}
      EXP
    end.join("\n")
  end
  
  def analyze_ats_compatibility(resume_content, job_data)
    # Extract keywords from job posting
    job_keywords = extract_keywords_from_job(job_data)
    resume_text = strip_html(resume_content).downcase
    
    matched_keywords = []
    missing_keywords = []
    
    job_keywords.each do |keyword|
      if resume_text.include?(keyword.downcase)
        matched_keywords << keyword
      else
        missing_keywords << keyword
      end
    end
    
    # Calculate ATS score
    score = job_keywords.any? ? (matched_keywords.length.to_f / job_keywords.length * 100).round : 0
    
    {
      score: score,
      matched: matched_keywords,
      missing: missing_keywords.first(5), # Top 5 missing keywords
      suggestions: generate_suggestions(missing_keywords)
    }
  end
  
  def extract_keywords_from_job(job_data)
    # Combine all job text
    job_text = "#{job_data[:title]} #{job_data[:description]} #{job_data[:requirements]}".downcase
    
    # Enhanced ATS keywords categorized by domain with modern technologies
    technical_skills = %w[
      python javascript typescript react angular vue node express nextjs
      sql mysql postgresql mongodb redis elasticsearch dynamodb
      aws azure gcp docker kubernetes terraform ansible jenkins
      git github gitlab bitbucket ci/cd devops microservices serverless
      api rest graphql json xml html css sass bootstrap tailwind
      agile scrum kanban jira confluence slack trello asana
      machine-learning ai ml data-science analytics tableau powerbi looker
      linux unix windows bash shell powershell cmd
      java c# .net spring hibernate maven gradle npm yarn
      flutter react-native swift kotlin ios android mobile
      blockchain web3 cryptocurrency fintech payment-processing
      cybersecurity penetration-testing vulnerability-assessment
      automation testing selenium cypress jest mocha pytest
    ]
    
    business_skills = %w[
      management leadership team-lead director manager supervisor ceo cto
      operations strategy planning execution implementation coordination
      project-management stakeholder client customer vendor partner
      budget financial cost-optimization revenue growth profit margins
      process-improvement lean six-sigma automation efficiency optimization
      communication presentation negotiation collaboration cross-functional
      analytics kpi metrics dashboard reporting compliance audit
      risk-management quality-assurance testing documentation technical-writing
      training mentoring coaching development performance team-building
      sales marketing business-development client-relations customer-success
      product-management roadmap requirements gathering user-experience
      change-management digital-transformation innovation disruption
    ]
    
    industry_terms = %w[
      saas b2b b2c e-commerce fintech healthcare edtech proptech
      startup enterprise corporate consulting agency freelance
      remote distributed hybrid cross-functional international global
      scalable high-availability performance optimization fault-tolerant
      security compliance gdpr hipaa sox pci-dss iso27001
      innovation digital-transformation cloud-native cloud-first
      artificial-intelligence internet-of-things big-data real-time
      user-experience user-interface design-thinking customer-centric
      omnichannel multi-tenant multi-platform cross-platform
      sustainable green-technology renewable-energy esg
    ]
    
    soft_skills = %w[
      problem-solving critical-thinking analytical creative adaptable
      self-motivated proactive detail-oriented results-driven
      time-management multitasking prioritization organization
      interpersonal teamwork collaboration communication presentation
      leadership mentoring coaching conflict-resolution
      customer-focused client-oriented service-minded
      innovative forward-thinking strategic-thinking
    ]
    
    all_keywords = technical_skills + business_skills + industry_terms + soft_skills
    
    # Extract keywords present in job posting
    found_keywords = all_keywords.select { |keyword| 
      job_text.include?(keyword.tr('-', ' ')) || job_text.include?(keyword) 
    }
    
    # Extract job-specific phrases and exact matches from job description
    job_phrases = extract_job_phrases(job_text)
    exact_matches = extract_exact_job_terms(job_text)
    
    # Combine and prioritize most relevant keywords
    all_found = (found_keywords + job_phrases + exact_matches).uniq
    
    # Prioritize by frequency in job posting
    prioritized = all_found.sort_by { |keyword| 
      count = job_text.scan(/#{Regexp.escape(keyword.tr('-', ' ').downcase)}/).length
      -count # Sort in descending order
    }
    
    prioritized.first(20) # Top 20 most relevant keywords
  end
  
  def extract_job_phrases(job_text)
    # Extract meaningful 2-3 word phrases from job description
    words = job_text.split(/\W+/).reject { |w| w.length < 3 }
    phrases = []
    
    # Extract important business phrases
    (0..words.length-3).each do |i|
      phrase = words[i..i+2].join(' ')
      if phrase.match?(/\b(management|leadership|development|operations|strategy|analysis|implementation|optimization|improvement|experience|software|technical|business|product|team|project|data|customer|system|digital|cloud|application|platform|solution|framework|integration|security|performance|quality|process|service|support|innovation|transformation|architecture|infrastructure|engineering|design|analytics|automation|collaboration|communication|planning|execution)\b/)
        phrases << phrase
      end
    end
    
    phrases.uniq.first(12)
  end

  def extract_exact_job_terms(job_text)
    # Extract exact important terms from the job posting
    exact_terms = []
    
    # Look for years of experience patterns
    experience_matches = job_text.scan(/(\d+\+?\s*(?:years?|yrs?)\s*(?:of\s*)?(?:experience|exp)?)/i)
    experience_matches.each { |match| exact_terms << match.first.downcase }
    
    # Extract degree requirements
    degree_matches = job_text.scan(/\b(bachelor'?s?|master'?s?|phd|doctorate|mba|degree|certification|diploma)\b/i)
    degree_matches.each { |match| exact_terms << match.first.downcase }
    
    # Extract specific technologies mentioned with version numbers
    tech_versions = job_text.scan(/\b([a-z]+\s*\d+(?:\.\d+)*|[a-z]+\s*version\s*\d+)\b/i)
    tech_versions.each { |match| exact_terms << match.first.downcase }
    
    # Extract programming languages and frameworks mentioned explicitly
    languages = %w[python javascript typescript java c# php ruby go rust swift kotlin scala r matlab]
    frameworks = %w[react angular vue django flask spring laravel symfony rails express fastapi tensorflow pytorch]
    
    (languages + frameworks).each do |tech|
      if job_text.include?(tech)
        exact_terms << tech
      end
    end
    
    exact_terms.uniq.first(10)
  end
  
  def strip_html(html)
    html.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip
  end
  
  def generate_suggestions(missing_keywords)
    return [] if missing_keywords.empty?
    
    [
      "Consider adding these missing keywords: #{missing_keywords.first(3).join(', ')}",
      "Include relevant projects or experiences that demonstrate these skills",
      "Add these technologies to your skills section if you have experience with them"
    ]
  end

  def add_resume_styling(resume_content)
    # Wrap in professional container with no top padding
    <<~HTML
      <div style="max-width: 8.5in; margin: 0 auto; padding: 0 0.4in 0.2in 0.4in; font-family: Arial, sans-serif; font-size: 12px; line-height: 1.3; color: #333; background: white;">
        #{resume_content}
      </div>
    HTML
  end

  def get_resume_css_styles
    # Read the CSS file and return its contents
    css_file_path = Rails.root.join('app', 'assets', 'stylesheets', 'resume_templates.css')
    
    if File.exist?(css_file_path)
      File.read(css_file_path)
    else
      # Fallback inline styles if file not found
      <<~CSS
        .resume-container {
          font-family: Arial, sans-serif;
          font-size: 11pt;
          line-height: 1.4;
          color: #333;
          max-width: 8.5in;
          margin: 0 auto;
          padding: 0.5in;
          background: white;
        }
        .name {
          font-size: 24pt;
          font-weight: bold;
          color: #2c3e50;
          text-transform: uppercase;
          margin-bottom: 5px;
        }
        .section-title {
          font-size: 14pt;
          font-weight: bold;
          color: #2c3e50;
          text-transform: uppercase;
          border-bottom: 1px solid #34495e;
          margin-bottom: 10px;
        }
        .job-title {
          font-size: 12pt;
          font-weight: bold;
          color: #2c3e50;
        }
        .company {
          font-weight: 600;
          color: #34495e;
        }
        .achievements li {
          margin-bottom: 4px;
        }
      CSS
    end
  end
end