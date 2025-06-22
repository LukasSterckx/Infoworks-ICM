# Adapted from: https://github.com/innovyze/Open-Source-Support/tree/main/01%20InfoWorks%20ICM/01%20Ruby/01%20InfoWorks/0039%20-%20Calculate%20subcatchment%20areas%20in%20all%20nodes%20upstream%20a%20node

# The following scripts is used for mapping the zones upstream of each CSO and the main conduits connecting them. 
# Start by selecting all CSO nodes (use e.g. script "label nodes from csv").
# The script traces upstream from every CSO node (stopping when it encouters another CSO node) and labels all nodes and links in field user_text_9 with the label of the CSO node (user_text_8).
# It then traces down from every CSO node and labels all conduits as 'main' conduits in the user_text_10 field.

# variables
$net = WSApplication.current_network
$ro = $net.row_objects_selection('hw_node')

# Start a transaction to edit the data
$net.transaction_begin

# Warning if less than 1 node is selected
if $ro.length() < 1
    puts "Error: no nodes were selected"
end

$unprocessed_links_us = Array.new
$unprocessed_combined_links_ds = Array.new
$seen_objects = Array.new
$splits = Array.new

# Marks the given object as selected and seen, and adds it to the seen objects list
def mark(object)
  if object
    #object.selected = true
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

# Adds all downstream links of the given node that have not been seen AND are combined or foul to the unprocessed links list and marks them as seen
def unprocessed_combined_links_ds(node)
  node.ds_links.each do |link|
    if !link._seen && is_combined_system(link)
      $unprocessed_combined_links_ds << link
      mark(link)
    end
  end
end

# Check if an object is combined (or foul) system type
def is_combined_system(object)
  case object.system_type when "Combined","combined","Foul","foul" then 
    return true
  end
  case object.system_type when "STORM","Storm","storm" then 
    return false
  end
  raise "object has system type of # {link.system_type}, not in the options"
end

# Check if a node is a split and add's it to the split hash
def is_split(node)
  if node.ds_links.length() > 1
    $splits << node
  end
end

# Check if a node is a split and has no upstream links
def is_top_split(node)
  node.ds_links.length() > 1 && node.us_links.length() == 0
end

# Label an object
def label(object, node_label)
  object.user_text_9 = node_label
  object.write
end

def label_subcatchments(object, node_label)
  object.navigate('subcatchments').each do |subs|
    subs.user_text_9 = node_label
    subs.write
  end
end

# Label an object as a main object
def label_as_main(object)
  object.user_text_10 = 'Main'
  object.write
end

# Traces upstream from the given node
def trace_us(node)
  node_label = node.user_text_8
  label(node, node_label)
  label_subcatchments(node, node_label)
  unprocessed_links_us(node)
  
  if $unprocessed_links_us.size == 0
    puts ""
    puts "#{node.node_id} has no upstream links"   
  end
  
  while $unprocessed_links_us.size > 0
    working_link = $unprocessed_links_us.shift
    label(working_link, node_label)
    label_subcatchments(working_link, node_label)
    working_node = working_link.us_node
    if working_node && !working_node._seen 
      if working_node._mouth
        is_split(working_node)
      else
        unprocessed_links_us(working_node)
        mark(working_node)
        label(working_node, node_label)
        label_subcatchments(working_node, node_label)
        is_split(working_node)
      end
    end
  end
  
  header_printed = false
  puts ""
  puts "CSO node = #{node.user_text_8}   (#{node.node_id})"
  
  $splits.each do |split|
    split.ds_links.each do |link|
      # Check if split is external split
      if link && !link._seen
        #split.selected = true
        
        # Check if split has no label (thus is not in csv)
        if split.user_text_8 == ""
          split.user_text_8 = "external split"
          split.write
        end
        
        # Check if split is an end split (has no upstream links)
        if split.us_links.length() ==0
          split.user_text_8 = "top split"
          split.write
         
        end
        if header_printed == false
            puts "  external split   |        label          |      link type"
            puts "-------------------|-----------------------|-----------------------"
            header_printed = true
        end
        puts "#{split.node_id.ljust(19)}| #{split.user_text_8.ljust(22)}| #{link.link_type}"
      end
    end
  end
  # unsee_all
  $splits = Array.new
end

def mark_main_conduits(node)
  
  unprocessed_combined_links_ds(node)
  
  while $unprocessed_combined_links_ds.size > 0
    working_link = $unprocessed_combined_links_ds.shift
    label_as_main(working_link)
    working_node = working_link.ds_node
    if working_node && !working_node._seen 
       unprocessed_combined_links_ds(working_node)
       mark(working_node)
    end
  end
end
 
# Mark each selected node as seen so it forms a border to the weirshed
$ro.each do |node|
  node._mouth = true
end

# Clean the User 10 table of all links, next trace down from every Outfall
$net.row_object_collection('_links').each do |link|
  link.user_text_10 = ''
  link.write
end

$ro.each do |node|
  mark_main_conduits(node)
end

# Executes the trace_us function on the initial node(s) to populate the 'most_upstream_nodes' array
$ro.each do |node|
  trace_us(node)
end

$net.transaction_commit
puts 'The nodes upstream of input node have been given a weirshed label in the user_text_8 field'
$net.commit 'The nodes upstream of input node have been given a weirshed label in the user_text_8 field'