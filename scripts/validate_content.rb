# frozen_string_literal: true

require "fastimage"
require "uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
ALLOWED_IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze
MAX_IMAGE_BYTES = 500 * 1024

errors = []

def check(errors, condition, message)
  errors << message unless condition
end

def load_yaml(path, errors)
  YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
rescue Psych::SyntaxError => e
  errors << "#{path.delete_prefix(ROOT + "/")}: invalid YAML (#{e.problem} at line #{e.line})"
  {}
end

def fetch_hash(parent, key, path, errors)
  value = parent[key]
  unless value.is_a?(Hash)
    errors << "#{path}.#{key}: must be an object"
    return {}
  end
  value
end

def required_text_value(value, label, errors, min: 1, max: nil)
  unless value.is_a?(String)
    errors << "#{label}: must be text"
    return ""
  end

  length = value.strip.length
  errors << "#{label}: is required" if length.zero?
  errors << "#{label}: must be at least #{min} characters" if length.positive? && length < min
  errors << "#{label}: must be no more than #{max} characters" if max && length > max
  value
end

def required_text(parent, key, path, errors, min: 1, max: nil)
  required_text_value(parent[key], "#{path}.#{key}", errors, min: min, max: max)
end

def optional_text(parent, key, path, errors, max: nil)
  value = parent[key]
  return "" if value.nil? || value == ""

  label = "#{path}.#{key}"
  unless value.is_a?(String)
    errors << "#{label}: must be text"
    return ""
  end

  errors << "#{label}: cannot contain only whitespace" if value.strip.empty?
  errors << "#{label}: must be no more than #{max} characters" if max && value.strip.length > max
  value
end

def fetch_array(parent, key, path, errors, length: nil)
  value = parent[key]
  unless value.is_a?(Array)
    errors << "#{path}.#{key}: must be a list"
    return []
  end
  errors << "#{path}.#{key}: must contain exactly #{length} items" if length && value.length != length
  value
end

def validate_image(path_value, label, errors, square: false, min_dimension: nil, max_dimension: nil)
  unless path_value.is_a?(String) && path_value.start_with?("/assets/uploads/")
    errors << "#{label}: must be stored below /assets/uploads/"
    return
  end

  relative_path = path_value.delete_prefix("/")
  absolute_path = File.join(ROOT, relative_path)
  extension = File.extname(relative_path).downcase
  check(errors, ALLOWED_IMAGE_EXTENSIONS.include?(extension), "#{label}: unsupported image extension #{extension}")

  unless File.file?(absolute_path)
    errors << "#{label}: file does not exist at #{relative_path}"
    return
  end

  size = File.size(absolute_path)
  errors << "#{label}: file is larger than 500 KB" if size > MAX_IMAGE_BYTES

  dimensions = FastImage.size(absolute_path)
  unless dimensions
    errors << "#{label}: image dimensions could not be read"
    return
  end

  width, height = dimensions
  errors << "#{label}: image must be square (found #{width}x#{height})" if square && width != height
  if min_dimension && [width, height].min < min_dimension
    errors << "#{label}: image must be at least #{min_dimension}x#{min_dimension} pixels"
  end
  if max_dimension && [width, height].max > max_dimension
    errors << "#{label}: image must be no larger than #{max_dimension}x#{max_dimension} pixels"
  end
end

site_path = File.join(ROOT, "_data/site.yml")
site = load_yaml(site_path, errors)

required_text(site, "language", "site", errors, max: 10)

seo = fetch_hash(site, "seo", "site", errors)
required_text(seo, "title", "site.seo", errors, min: 20, max: 70)
required_text(seo, "description", "site.seo", errors, min: 50, max: 170)
required_text(seo, "social_description", "site.seo", errors, min: 50, max: 200)
required_text(seo, "social_image_alt", "site.seo", errors, min: 5, max: 140)
validate_image(seo["social_image"], "site.seo.social_image", errors)
validate_image(seo["twitter_image"], "site.seo.twitter_image", errors)
check(errors, seo["social_image_width"].is_a?(Integer) && seo["social_image_width"].positive?, "site.seo.social_image_width: must be a positive whole number")
check(errors, seo["social_image_height"].is_a?(Integer) && seo["social_image_height"].positive?, "site.seo.social_image_height: must be a positive whole number")

navigation = fetch_hash(site, "navigation", "site", errors)
required_text(navigation, "contact_label", "site.navigation", errors, max: 24)

contact = fetch_hash(site, "contact", "site", errors)
required_text(contact, "name", "site.contact", errors, max: 80)
required_text(contact, "role", "site.contact", errors, max: 100)
email = required_text(contact, "email", "site.contact", errors, max: 254)
check(errors, email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/), "site.contact.email: must be a complete email address")
required_text(contact, "email_subject", "site.contact", errors, max: 100)

company = fetch_hash(site, "company", "site", errors)
required_text(company, "legal_name", "site.company", errors, max: 100)
required_text(company, "registration_country", "site.company", errors, max: 100)
company_number = required_text(company, "company_number", "site.company", errors, min: 6, max: 12)
check(errors, company_number.match?(/\A[A-Za-z0-9]+\z/), "site.company.company_number: use letters and numbers without spaces")
required_text(company, "registered_office", "site.company", errors, max: 250)

links = fetch_hash(site, "links", "site", errors)
linkedin = required_text(links, "linkedin", "site.links", errors, max: 300)
begin
  uri = URI.parse(linkedin)
  check(errors, uri.is_a?(URI::HTTPS) && ["linkedin.com", "www.linkedin.com"].include?(uri.host), "site.links.linkedin: must be a LinkedIn HTTPS URL")
rescue URI::InvalidURIError
  errors << "site.links.linkedin: must be a valid URL"
end

home_path = File.join(ROOT, "_data/home.yml")
home = load_yaml(home_path, errors)

hero = fetch_hash(home, "hero", "home", errors)
required_text(hero, "heading", "home.hero", errors, min: 10, max: 60)
required_text(hero, "cta_label", "home.hero", errors, max: 32)

sections = fetch_array(home, "sections", "home", errors)
check(errors, (1..12).cover?(sections.length), "home.sections: must contain between 1 and 12 sections")
allowed_section_types = %w[intro card-grid statement video people-grid].freeze
anchors = Hash.new { |hash, key| hash[key] = [] }
people_sections = Hash.new { |hash, key| hash[key] = [] }
navigation_section_count = 0

sections.each_with_index do |section, index|
  path = "home.sections[#{index}]"
  unless section.is_a?(Hash)
    errors << "#{path}: must be an object"
    next
  end

  section_type = required_text(section, "type", path, errors)
  check(errors, allowed_section_types.include?(section_type), "#{path}.type: unsupported section type #{section_type.inspect}")

  anchor = required_text(section, "anchor", path, errors, max: 50)
  check(errors, anchor.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/), "#{path}.anchor: use lowercase letters, numbers, and single hyphens")
  check(errors, !%w[top contact].include?(anchor), "#{path}.anchor: #{anchor.inspect} is reserved")
  anchors[anchor] << index unless anchor.empty?
  navigation_label = optional_text(section, "navigation_label", path, errors, max: 24)
  navigation_section_count += 1 unless navigation_label.strip.empty?

  theme = required_text(section, "theme", path, errors)
  check(errors, %w[neutral accent].include?(theme), "#{path}.theme: must be neutral or accent")

  case section_type
  when "intro"
    optional_text(section, "eyebrow", path, errors, max: 24)
    required_text(section, "heading", path, errors, min: 10, max: 80)
    optional_text(section, "lead", path, errors, max: 500)
    paragraphs = fetch_array(section, "paragraphs", path, errors)
    check(errors, (1..3).cover?(paragraphs.length), "#{path}.paragraphs: must contain between 1 and 3 paragraphs")
    paragraphs.each_with_index do |paragraph, paragraph_index|
      required_text_value(paragraph, "#{path}.paragraphs[#{paragraph_index}]", errors, min: 40, max: 700)
    end
  when "card-grid"
    optional_text(section, "eyebrow", path, errors, max: 24)
    optional_text(section, "heading", path, errors, max: 80)
    optional_text(section, "introduction", path, errors, max: 500)
    check(errors, [true, false].include?(section["numbered"]), "#{path}.numbered: must be true or false")
    cards = fetch_array(section, "cards", path, errors)
    check(errors, (2..4).cover?(cards.length), "#{path}.cards: must contain between 2 and 4 cards")
    cards.each_with_index do |card, card_index|
      card_path = "#{path}.cards[#{card_index}]"
      unless card.is_a?(Hash)
        errors << "#{card_path}: must be an object"
        next
      end
      required_text(card, "title", card_path, errors, min: 5, max: 60)
      required_text(card, "body", card_path, errors, min: 40, max: 500)
    end
    optional_text(section, "cta_label", path, errors, max: 32)
  when "statement"
    paragraphs = fetch_array(section, "paragraphs", path, errors)
    check(errors, (1..2).cover?(paragraphs.length), "#{path}.paragraphs: must contain 1 or 2 paragraphs")
    paragraphs.each_with_index do |paragraph, paragraph_index|
      required_text_value(paragraph, "#{path}.paragraphs[#{paragraph_index}]", errors, min: 40, max: 700)
    end
  when "video"
    required_text(section, "heading", path, errors, max: 60)
    optional_text(section, "introduction", path, errors, max: 500)
    youtube_id = required_text(section, "youtube_id", path, errors, min: 11, max: 11)
    check(errors, youtube_id.match?(/\A[A-Za-z0-9_-]{11}\z/), "#{path}.youtube_id: must be an 11-character YouTube video ID")
    required_text(section, "title", path, errors, min: 5, max: 100)
  when "people-grid"
    required_text(section, "heading", path, errors, max: 60)
    optional_text(section, "introduction", path, errors, max: 500)
    group = required_text(section, "group", path, errors)
    check(errors, %w[team advisor].include?(group), "#{path}.group: must be team or advisor")
    people_sections[group] << index if %w[team advisor].include?(group)
  end
end

check(errors, navigation_section_count <= 5, "home.sections: no more than 5 body sections may appear in the main navigation")
anchors.each do |anchor, indexes|
  errors << "home.sections: duplicate anchor #{anchor.inspect} in sections #{indexes.join(', ')}" if indexes.length > 1
end
people_sections.each do |group, indexes|
  errors << "home.sections: duplicate #{group} people grids in sections #{indexes.join(', ')}" if indexes.length > 1
end

home_contact = fetch_hash(home, "contact", "home", errors)
required_text(home_contact, "eyebrow", "home.contact", errors, max: 24)
required_text(home_contact, "heading", "home.contact", errors, max: 50)
required_text(home_contact, "body", "home.contact", errors, min: 40, max: 400)
required_text(home_contact, "cta_label", "home.contact", errors, max: 32)

orders = Hash.new { |hash, key| hash[key] = [] }
people_paths = Dir[File.join(ROOT, "_people/*.md")].sort
check(errors, people_paths.any?, "_people: must contain at least one profile")

people_paths.each do |path|
  relative_path = path.delete_prefix(ROOT + "/")
  contents = File.read(path)
  match = contents.match(/\A---\s*\n(.*?)\n---\s*\n?\z/m)
  unless match
    errors << "#{relative_path}: must contain YAML frontmatter and no body content"
    next
  end

  person = begin
    YAML.safe_load(match[1], permitted_classes: [], aliases: false) || {}
  rescue Psych::SyntaxError => e
    errors << "#{relative_path}: invalid frontmatter (#{e.problem} at line #{e.line})"
    next
  end

  required_text(person, "name", relative_path, errors, min: 2, max: 80)
  required_text(person, "role", relative_path, errors, min: 2, max: 100)
  group = required_text(person, "group", relative_path, errors)
  check(errors, %w[team advisor].include?(group), "#{relative_path}.group: must be team or advisor")

  order = person["order"]
  check(errors, order.is_a?(Integer) && order.positive?, "#{relative_path}.order: must be a positive whole number")
  orders[group] << [order, relative_path] if order.is_a?(Integer) && %w[team advisor].include?(group)

  check(errors, [true, false].include?(person["published"]), "#{relative_path}.published: must be true or false")
  image = required_text(person, "image", relative_path, errors)
  check(errors, image.start_with?("/assets/uploads/team/"), "#{relative_path}.image: must be stored below /assets/uploads/team/")
  validate_image(image, "#{relative_path}.image", errors, square: true, min_dimension: 240, max_dimension: 1200)
  required_text(person, "image_alt", relative_path, errors, min: 2, max: 140)
  required_text(person, "bio", relative_path, errors, min: 40, max: 600)
end

orders.each do |group, entries|
  entries.group_by(&:first).each do |order, duplicates|
    next if duplicates.length == 1
    errors << "_people: duplicate #{group} display order #{order} in #{duplicates.map(&:last).join(', ')}"
  end
end

if errors.empty?
  puts "Content validation passed for #{sections.length} homepage sections and #{people_paths.length} profiles."
else
  warn "Content validation failed with #{errors.length} error#{errors.length == 1 ? '' : 's'}:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end
