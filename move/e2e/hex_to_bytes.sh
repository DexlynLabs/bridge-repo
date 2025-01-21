#!/bin/bash

# Check if input is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <hex_string>"
  exit 1
fi

# Input hex string
hex_string=$1

# Remove "0x" prefix if it exists
if [[ $hex_string == 0x* ]]; then
  hex_string=${hex_string:2}
fi

# Validate that the input contains only hex characters
if ! [[ $hex_string =~ ^[0-9a-fA-F]+$ ]]; then
  echo "Error: Input is not a valid hex string."
  exit 1
fi

# Convert the hex string to a byte array
byte_array=()
for ((i=0; i<${#hex_string}; i+=2)); do
  byte=${hex_string:i:2}          # Extract two hex characters
  decimal=$((16#$byte))           # Convert hex to decimal
  byte_array+=($decimal)          # Append to the array
done

# Format the output as u8:[...]
output="[${byte_array[*]}]"
output=${output// /,}             # Replace spaces with commas
echo "$output"
