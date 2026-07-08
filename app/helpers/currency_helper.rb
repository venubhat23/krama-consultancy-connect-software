module CurrencyHelper
  # Formats a number in Indian currency format with ₹ symbol
  # Examples:
  # indian_currency(1000) => "₹1,000"
  # indian_currency(100000) => "₹1,00,000"
  # indian_currency(1000000) => "₹10,00,000"
  # indian_currency(10000000) => "₹1,00,00,000"
  def indian_currency(amount, options = {})
    return "Rs. 0.00" if amount.nil? || amount == 0

    # Convert to float to handle both integers and strings
    amount = amount.to_f

    # Handle negative numbers
    negative = amount < 0
    amount = amount.abs if negative

    # Convert to string and split into integer and decimal parts
    amount_str = sprintf("%.2f", amount)
    integer_part, decimal_part = amount_str.split('.')

    # Format integer part in Indian numbering system
    formatted_integer = format_indian_number(integer_part)

    # Build the result — always show 2 decimal places
    result = "Rs. #{formatted_integer}.#{decimal_part}"

    # Add negative sign if needed
    result = "-#{result}" if negative

    result
  end

  # Converts a number to compact Indian words: 1 Crore, 50 Lakh, 5 Thousand, etc.
  # Examples:
  #   amount_in_words(10000000)  => "1 Crore"
  #   amount_in_words(15000000)  => "1.5 Crore"
  #   amount_in_words(500000)    => "5 Lakh"
  #   amount_in_words(750000)    => "7.5 Lakh"
  #   amount_in_words(5000)      => "5 Thousand"
  def amount_in_words(amount)
    return "0" if amount.nil? || amount == 0

    amount = amount.to_f

    if amount >= 10_000_000
      val = amount / 10_000_000.0
      "#{compact_number(val)} Crore"
    elsif amount >= 100_000
      val = amount / 100_000.0
      "#{compact_number(val)} Lakh"
    elsif amount >= 1_000
      val = amount / 1_000.0
      "#{compact_number(val)} Thousand"
    else
      amount.to_i.to_s
    end
  end

  # Formats just the number part without currency symbol
  def indian_number(amount)
    return "0.00" if amount.nil? || amount == 0

    amount = amount.to_f
    negative = amount < 0
    amount = amount.abs if negative

    amount_str = sprintf("%.2f", amount)
    integer_part, decimal_part = amount_str.split('.')

    formatted_integer = format_indian_number(integer_part)

    result = "#{formatted_integer}.#{decimal_part}"
    result = "-#{result}" if negative

    result
  end

  private

  # Formats a decimal, stripping trailing zeros: 1.50 => "1.5", 2.00 => "2", 1.25 => "1.25"
  def compact_number(val)
    sprintf("%.2f", val).sub(/\.?0+$/, '')
  end

  # Formats a number string according to Indian numbering system
  # 1,000 -> 1,000
  # 10,000 -> 10,000
  # 100,000 -> 1,00,000
  # 1,000,000 -> 10,00,000
  # 10,000,000 -> 1,00,00,000
  def format_indian_number(number_string)
    # Reverse the string for easier processing
    reversed = number_string.reverse

    # Add commas according to Indian system
    # First comma after 3 digits, then every 2 digits
    result = []

    reversed.chars.each_with_index do |char, index|
      result << char

      # Add comma after 3rd digit
      if index == 2 && reversed.length > 3
        result << ','
      # Add comma after every 2 digits beyond the first 3
      elsif index > 2 && (index - 2) % 2 == 0 && index < reversed.length - 1
        result << ','
      end
    end

    # Reverse back to get the final result
    result.reverse.join
  end
end