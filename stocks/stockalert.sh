#!/bin/bash

 

# Configuration, interval can be 1min, 5min, 15min, 30min, 60min

API_KEY="1AZPLJS9EN9CIAWI"

BASE_PATH="/home/michael/stocks"

STOCKS_FILE="$BASE_PATH/stocks.txt"

INTERVAL="15min"

HIGHEST_PRICES_FILE="$BASE_PATH/highest_prices.txt"

PREVIOUS_STOCKS_FILE="$BASE_PATH/previous_stocks.txt"

DEFAULT_STOP_PERCENT=8

PRINT_SCRIPT="/home/michael/discord/post.sh"

ERROR_LOG="$BASE_PATH/errors.log"

 

# Function to fetch the latest price of a stock

fetch_latest_price() {

  local stock_symbol=$1
  local URL="https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$stock_symbol&apikey=$API_KEY"
  # local response=$(curl -s https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=$stock_symbol&interval=$INTERVAL&apikey=$API_KEY)
  local response=$(curl -s $URL)
  local latest_price=$(echo $response | jq -r '.["Global Quote"]["05. price"]')
  #jq -r ".\"Time Series ($INTERVAL)\" | .[] | .\"4. close\"" | head -n 1)

  echo $latest_price

}

 

# Function to update the highest price for a stock

update_highest_price() {

  local stock_symbol=$1

  local latest_price=$2

  local highest_price=$3

  if (( $(echo "$latest_price > $highest_price" | bc -l) )); then

    highest_price=$latest_price

    echo $highest_price

  else

    echo $highest_price

  fi

}

 

ensureFilesExist() {

    # Initialize the highest prices file if it doesn't exist

    if [ ! -f "$HIGHEST_PRICES_FILE" ]; then

        touch "$HIGHEST_PRICES_FILE"

    fi

 

    # Initialize the previous stocks file if it doesn't exist

    if [ ! -f "$PREVIOUS_STOCKS_FILE" ]; then

        touch "$PREVIOUS_STOCKS_FILE"

    fi

}

 

# STOCK_SYMBOL, latest_price, stop_loss_price

echoAlert() {

    if [ ! -f "$PRINT_SCRIPT" ]; then

        $PRINT_SCRIPT "Alert: The price of $1 has dropped below the trailing stop loss. Current price: $2, Stop loss price: $3"

    else

        if [ ! -f "$ERROR_LOG" ]; then

            touch "$ERROR_LOG"

        fi

        echo "Error: Script to execute not found $PRINT_SCRIPT" > $ERROR_LOG

    fi

}

 

# Read the stock symbols and trailing stop percentages from the file

main() {

    while read -r line; do

        STOCK_SYMBOL=$(echo $line | awk '{print $1}')

        TRAILING_STOP_PERCENTAGE=$(echo $line | awk '{print $2}')

       

        # Ensure the stock symbol has an entry in the highest prices file

        if ! grep -q "^$STOCK_SYMBOL " "$HIGHEST_PRICES_FILE"; then

            echo "$STOCK_SYMBOL $DEFAULT_STOP_PERCENT" >> "$HIGHEST_PRICES_FILE"

        fi

       

        # Fetch the latest price

        latest_price=$(fetch_latest_price $STOCK_SYMBOL)

       

        # Read the highest price from the file

        highest_price=$(grep "^$STOCK_SYMBOL " "$HIGHEST_PRICES_FILE" | awk '{print $2}')

       

        # Update the highest price if necessary

        new_highest_price=$(update_highest_price $STOCK_SYMBOL $latest_price $highest_price)

       

        # Calculate the stop loss price

        stop_loss_price=$(echo "$new_highest_price * (1 - $TRAILING_STOP_PERCENTAGE / 100)" | bc -l)

       

        # Check if the latest price is below the stop loss price

        if (( $(echo "$latest_price < $stop_loss_price" | bc -l) )); then

           echoAlert $STOCK_SYMBOL $latest_price $stop_loss_price

        fi

       

        # Update the highest price in the file

        sed -i "s/^$STOCK_SYMBOL .*/$STOCK_SYMBOL $new_highest_price/" "$HIGHEST_PRICES_FILE"

   

    done < "$STOCKS_FILE"

 

    # Check for new stocks added since the last run

    mapfile -t current_stocks < <(awk '{print $1}' "$STOCKS_FILE")

    mapfile -t previous_stocks < "$PREVIOUS_STOCKS_FILE"

 

    for stock_symbol in "${current_stocks[@]}"; do

        if ! printf "%s\n" "${previous_stocks[@]}" | grep -qx "$stock_symbol"; then

            $PRINT_SCRIPT "Alert: New stock added to the watch list: $stock_symbol"

        fi

    done

 

    # Save the current stocks to the previous stocks file

    printf "%s\n" "${current_stocks[@]}" > "$PREVIOUS_STOCKS_FILE"

}
