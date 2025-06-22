# Adapted from: https://github.com/innovyze/Open-Source-Support/tree/main/01%20InfoWorks%20ICM/01%20Ruby/01%20InfoWorks/0039%20-%20Calculate%20subcatchment%20areas%20in%20all%20nodes%20upstream%20a%20node

# The following script traces the network upstream of a node and verifies if this network has external splits. 
# It prints a overview of the external splits and selects them. 
# An external split is a node with two or more downstream links from which at least one doesn't flow towards the start node.
# This is used to map a CSO catchment and to check if the CSO catchment has external splits.

# variables
$net = WSApplication.current_network
$net.clear_selection
selection = WSApplication.choose_selection("Choose the Selection list containing the most downstream node of the catchment")
$net.load_selection(selection)
$ro = $net.row_objects_selection('hw_node')

$unprocessed_links_us = Array.new
$seen_objects = Array.new
$splits = Array.new

# Warning if more or less than 1 node is selected
if $ro.length() > 1
  puts "Warning: #{$ro.length()} nodes were selected"
end

if $ro.length() < 1
    puts "Error: no nodes were selected"
end

# Marks the given object as selected and seen, and adds it to the seen objects list
def mark(object)
  if object
    object._seen = true
    $seen_objects << object
  end
end

# Unmarks all seen objects as seen and clears the seen objects list
def unsee_all
  $seen_objects.each { |object| object._seen = false }
  $seen_objects = Array.new
end

# Adds all upstream links of the given node that have not been seen to the unprocessed links list and marks them as seen
def unprocessed_links_us(node)
  node.us_links.each do |link|
    if !link._seen
      $unprocessed_links_us << link
      mark(link)
    end
  end
end

# Check if a node is a split (has more than one downstream link)
def is_split(node)
  if node.ds_links.length() > 1
    $splits << node
  end
end

# Traces upstream from the given node
def trace_us(node)
  mark(node)
  unprocessed_links_us(node)
  
  while $unprocessed_links_us.size > 0
    working_link = $unprocessed_links_us.shift
    working_node = working_link.us_node
    if working_node && !working_node._seen
      unprocessed_links_us(working_node)
      mark(working_node)
      is_split(working_node)
    end
  end
  puts ""
  puts "Catchment node = #{node.user_text_8}   (#{node.node_id})"
  puts "  external split   |        label          |      link type"
  puts "-------------------|-----------------------|-----------------------"
  $splits.each do |split|
    split.ds_links.each do |link|
      if link && !link._seen
        # Split is a real split
        split.selected = true

        puts "#{split.node_id.ljust(19)}| #{split.user_text_8.ljust(22)}| #{link.link_type}"
      end
    end
  end
  unsee_all
  $splits = Array.new
end

# Print info on external splits
$ro.each do |node|
  trace_us(node)
end

