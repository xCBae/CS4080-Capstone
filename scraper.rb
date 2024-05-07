require 'nokogiri'
require 'httparty'
require 'json'
require 'gruff'

def clean_string(original_text)
  # Remove "Categories:", commas, and the word "Pokemon"
  cleaned_text = original_text.gsub(/Categories:|,|Pokemon|kg|Â£/i, '')
  
  # Remove extra spaces
  cleaned_text = cleaned_text.strip.squeeze(' ')
  
  cleaned_text
end

def scraper(page_number)
  url = "https://scrapeme.live/shop/page/#{page_number}"
  unparsed_page = HTTParty.get(url)
  parsed_page = Nokogiri::HTML(unparsed_page)

  products = []  # Stores product info

  items = parsed_page.css('main ul.products li.product')  # Gets each item

  if items.empty?
    puts "No items found on page #{page_number}"
  else
    items.each do |item|
      name = item.css('h2').text.strip  # Extract name
      price_string = item.css('span.price').text.strip  # Extract price
      
      # Second url to add quantity since it was on another page
      second_url = "https://scrapeme.live/shop/#{name}"
      unparsed_second_page = HTTParty.get(second_url)
      parsed_second_page = Nokogiri::HTML(unparsed_second_page)
      
      # Extract additional information from the second page
      quantity_string = parsed_second_page.css('div.summary p.stock').text.strip  # Extract quantity as string
      categories_string = parsed_second_page.css('div.summary span.posted_in').text.strip # Extract categories as string
      weight_string = parsed_second_page.css('div.woocommerce-tabs td.product_weight').text.strip # Extract weight as string
      dimensions = parsed_second_page.css('div.woocommerce-tabs td.product_dimensions').text.strip # Extract dimensions as string

      # Convert to integer
      quantity = quantity_string.scan(/\d+/).first.to_i 

      # Remove unwanted words from categories
      categories = clean_string(categories_string)

      # Remove unwanted words from weight
      weight = clean_string(weight_string)

      # Remove unwanted euro sign from price
      price = clean_string(price_string)

      product = { name: name, price: price, quantity: quantity, categories: categories, weight: weight, dimensions: dimensions}  # Create a hash representing the product
      products << product  # Add product to array
    end
  end

  products
end

# Scrape multiple pages and collect the data
all_products = []
(1..2).each do |page_number|
  all_products.concat(scraper(page_number))
end

# Convert the array of product hashes to JSON
json_data = JSON.pretty_generate(all_products)

# Write the JSON data to a file
File.open("output.json", "w") do |file|
  file.write(json_data)
end

# Load your JSON data
json_data = File.read("output.json")
products = JSON.parse(json_data)

# Extract relevant data for visualization
prices = products.map { |product| product["price"].gsub(/[^\d.]/, '').to_f }
quantities = products.map { |product| product["quantity"] }
weights = products.map { |product| product["weight"].to_f }

# Create graphs with specific labels
def generate_price_bar_chart(data, output_file)
    g = Gruff::Bar.new
    g.title = "Distribution of Product Prices"
    g.labels = {}
    g.data("Product Prices", data.map { |pair| pair[1] }) # Use product prices as data
    g.write(output_file)
  end  

def generate_quantity_line_chart(data, output_file)
  g = Gruff::Line.new
  g.title = "Product Quantity Variation"
  g.data("Quantities", data)
  g.write(output_file)
end

def generate_weight_bar_chart(data, output_file)
  g = Gruff::Bar.new
  g.title = "Product Weights"
  g.data("Weights", data)
  g.write(output_file)
end

def generate_pie_chart(data, title, output_file)
  g = Gruff::Pie.new
  g.title = title
  data.each { |label, value| g.data(label, value) }
  g.write(output_file)
end

# Modify how prices are extracted for visualization
prices_with_product_numbers = prices.each_with_index.map { |price, index| [index, price] }

# Generate specific graphs with appropriate labels and chart types
generate_price_bar_chart(prices_with_product_numbers, "price_bar_chart.png")
generate_quantity_line_chart(quantities, "quantity_line_chart.png")
generate_weight_bar_chart(weights, "weight_bar_chart.png")

# For pie chart, you might want to use categories
categories = products.map { |product| product["categories"] }.flatten
categories_counts = categories.each_with_object(Hash.new(0)) { |category, counts| counts[category] += 1 }
generate_pie_chart(categories_counts, "Product Categories", "categories_pie_chart.png")
