#!/bin/bash
# Configuration
API_KEY="1AZPLJS9EN9CIAWI" 
STOCKS_FILE="stocks.txt" INTERVAL="5min" # Can be 1min, 
# 5min, 15min, 30min, 60min 
HIGHEST_PRICES_FILE="highest_prices.txt"
# Function to fetch the latest price of a stock
fetch_latest_price() { local stock_symbol=$1 local 
  response=$(curl -s 
  "https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=$stock_symbol&interval=$INTERVAL&apikey=$API_KEY") 
  local latest_price=$(echo $response | jq -r ".\"Time 
  Series ($INTERVAL)\" | .[] | .\"4. close\"" | head -n 
  1) echo $latest_price
}
# Function to update the highest price for a stock
update_highest_price() { 
local stock_symbol=$1 
local  latest_price=$2 
local highest_price=$3 
if (( $(echo "$latest_price > $highest_price" | bc -l) )); then
    highest_price=$latest_price echo $highest_price 
  else
    echo $highest_price 
  fi
}
# Initialize the highest prices file if it doesn't 
# exist
if [ ! -f "$HIGHEST_PRICES_FILE" ]; then 
touch "$HIGHEST_PRICES_FILE"
fi
# Read the stock symbols and trailing stop percentages 
# from the file
while read -r line; do 
STOCK_SYMBOL=$(echo $line | awk  '{print $1}') TRAILING_STOP_PERCENTAGE=$(echo $line | awk '{print $2}')
 
 # Ensure the stock symbol has an entry in the highest 
  # prices file
  if ! grep -q "^$STOCK_SYMBOL " "$HIGHEST_PRICES_FILE"; then
    echo "$STOCK_SYMBOL 0" >> "$HIGHEST_PRICES_FILE" 
fi
  
  # Fetch the latest price
  latest_price=$(fetch_latest_price $STOCK_SYMBOL)
  
  # Read the highest price from the file
  highest_price=$(grep "^$STOCK_SYMBOL " "$HIGHEST_PRICES_FILE" | awk '{print $2}')
  
  # Update the highest price if necessary
  new_highest_price=$(update_highest_price $STOCK_SYMBOL $latest_price $highest_price)
  /root/post.sh "Updating higest price of $STOCK_SYMBOL to $highest_price"
  # Calculate the stop loss price
  stop_loss_price=$(echo "$new_highest_price * (1 - $TRAILING_STOP_PERCENTAGE / 100)" | bc -l)
  
  # Check if the latest price is below the stop loss 
  # price
  if (( $(echo "$latest_price < $stop_loss_price" | bc -l) )); then
    /root/post.sh "Alert: The price of $STOCK_SYMBOL has dropped below the trailing stop loss. Current price:$latest_price, Stop loss price: $stop_loss_price"
  else 
echo "The price of $STOCK_SYMBOL is above the trailing stop loss. Current price: $latest_price, Highest price: $new_highest_price, Stop loss price: $stop_loss_price" > /dev/null
  fi
  
  # Update the highest price in the file
  sed -i "s/^$STOCK_SYMBOL .*/$STOCK_SYMBOL 
  $new_highest_price/" "$HIGHEST_PRICES_FILE"
done < "$STOCKS_FILE"
