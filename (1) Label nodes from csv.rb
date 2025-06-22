# The following script takes a csv with node IDs and custom labels and writes the labels to the User_text_8 field of the corresponding node. 
# It further selects all nodes which were included in the csv.

require 'csv'

$net = WSApplication.current_network
$net.transaction_begin
$net.clear_selection
$ro = $net.row_object_collection('hw_node')

csv_file = 'C:/Users/lukas/Documents/GEOGRAFIE/5_master/Thesis/Data_en_resultaten/Ruby/nodes_labels.csv'

# Read the csv file and make a hash with the Node IDs and the corresponding custom label
def import_csv(csv_file)
  labels = {}
  CSV.foreach(csv_file, col_sep: ';', headers: true) do |row|
    id = row['Node ID for mapping']
    label = row['Label']
    labels[id] = label
  end
  labels
end


id_to_label = import_csv(csv_file)

# Iterate over nodes and assign the label if node_id matches, otherwise make User_text_8 blank
$ro.each do |node|
  node_id = node.node_id.to_s
  if id_to_label[node_id] # Ensure we match as strings
    node.user_text_8 = id_to_label[node_id]
    node.write
    puts "Node ID: #{node.node_id}, User Text 8: #{node.user_text_8}"
    id_to_label.delete(node_id)
    node.selected = true
  else
    node.user_text_8 = id_to_label[""]
    node.write
  end
end

#Check if all node IDs in the csv file were found in the Infoworks ICM database
id_to_label.keys.each do |key|
  puts "No node with Node ID: #{key} was found"
end

$net.transaction_commit
puts 'The nodes presented in the csv have been given a label in the user_text_8 field'
$net.commit 'The nodes presented in the csv have been given a label in the user_text_8 field'
