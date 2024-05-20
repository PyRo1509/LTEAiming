#!/bin/sh

# Initialize variables to store RSSI values and static cell info
rssi_values=""
graph_lines=""
enodeb_id=""
band=""
frequency=""
serving_cell_id=""
iteration_counter=0
max_lines=30

# Function to extract the desired information from uqmi output
extract_info() {
    json_output="$1"

    # Update static cell info every 10 iterations
    if [ $((iteration_counter % 10)) -eq 0 ]; then
        enodeb_id=$(echo "$json_output" | grep -o '"enodeb_id":[^,]*' | head -n 1 | cut -d ':' -f 2 | tr -d ' ')
        band=$(echo "$json_output" | grep -o '"band":[^,]*' | head -n 1 | cut -d ':' -f 2 | tr -d ' ')
        frequency=$(echo "$json_output" | grep -o '"frequency":[^,]*' | head -n 1 | cut -d ':' -f 2 | tr -d ' ')
        serving_cell_id=$(echo "$json_output" | grep -o '"serving_cell_id":[^,]*' | head -n 1 | cut -d ':' -f 2 | tr -d ' ')
    fi

    rssi=$(echo "$json_output" | grep -o '"rssi":[^,]*' | head -n 1 | cut -d ':' -f 2 | tr -d ' ')

    # Use printf to concatenate all information into a single string and output it
    info="Current Cell Info:\n"
    info="$info eNodeB ID: $enodeb_id\n"
    info="$info Band: $band\n"
    info="$info Frequency: $frequency\n"
    info="$info Serving Cell ID: $serving_cell_id\n"
    info="$info RSSI: $rssi"
    printf "%b\n" "$info"
}

# Function to draw a single RSSI line
draw_rssi_line() {
    rssi="$1"
    min_rssi=-120
    max_rssi=-30
    range=$((max_rssi - min_rssi))

    rssi_int=$(printf "%.0f" "$rssi")
    if [ "$rssi_int" -ge "$min_rssi" ] && [ "$rssi_int" -le "$max_rssi" ]; then
        position=$(( (rssi_int - min_rssi) * 70 / range ))
        line=$(printf "%-${position}s" "-" | tr ' ' '-')"#"
        line=$(printf "%-70s" "$line" | tr ' ' '-')
        line="$line $rssi"
        echo "$line"
    else
        echo "Invalid RSSI value: $rssi"
    fi
}

# Function to update the graph buffer with the latest RSSI value
update_graph_buffer() {
    new_line=$(draw_rssi_line "$1")
    graph_lines=$(echo -e "$graph_lines\n$new_line" | tail -n $max_lines)
}

# Function to generate and print the separator and scale in one go
generate_separator_and_scale() {
    scale="-120   -110   -100    -90    -80    -70    -60    -50    -40    -30"
    separator=$(printf '%.0s-' $(seq 1 ${#scale}))
    printf "%s\n%s\n" "$separator" "$scale"
}

# Main loop to continuously fetch data every second
while true; do
    # Fetch cell location info
    output=$(uqmi -d /dev/cdc-wdm0 --get-cell-location-info)

    # Clear the screen
    clear

    # Extract and print the relevant information
    extract_info "$output"

    # Update the graph buffer with the latest RSSI value
    rssi=$(echo "$output" | grep -o '"rssi":[^,]*' | head -n 1 | cut -d ':' -f 2 | tr -d ' ')
    update_graph_buffer "$rssi"

    # Display the RSSI graph
    echo "RSSI over Time (last 30 seconds):"
    echo -e "$graph_lines"

    # Display the separator and scale
    generate_separator_and_scale

    # Increment the iteration counter
    iteration_counter=$((iteration_counter + 1))

    # Wait for 1 second before the next iteration
    sleep 1
done
