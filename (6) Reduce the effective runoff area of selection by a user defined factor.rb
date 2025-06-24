# The following script creates a new scenario were the effective runoff area (ERA) of selection of subcatchments is reduced by a user defined (depavement) factor. 
# First the user is asked for a selection list containing all contributing subcatchments and a depavement factor
# The script next applies the depavement factor to all subcatchments in the selection list

# The script considers that some land uses can be depaved and others not. 
# 1) flexi - paved surfaces which can potentially be depaved (e.g. street surfaces)
# 2) fixed - paved surfaces which cannot be depaved (e.g. roofs)
# 3) pervious - pervious surfaces 
#
# First, the new flexi effective runoff area is calculated by substracting the fixed effective runoff area from the new total effective runoff area (coeff * total runoff)
# Next, next the new runoff from each flexi runoff surface is determined proportionally to the total runoff from the runoff surface
# Then, The new runoff area for each runoff surface within a subcatchment is determined, proportionally to the total area
# depaved areas area assumed to have a runoff factor to zero, this area is not added anywhere, the total runoff area (including pervious surfaces)
# from a subcatchments will thus decrease

# Define the runoff surfaces which can be depaved (flexible pervious surfaces)
$flexi = [110, 111, 112, 113, 114, 115, 116, 117, 118, 210, 211]
  
# variables
$net = WSApplication.current_network
$net.clear_selection
selection = WSApplication.choose_selection("Choose the Selection list containing the subcatchment")
$net.load_selection(selection)
$ro = $net.row_objects_selection('hw_subcatchment')

def check_scenario()
  run = true
  if $net.current_scenario == 'Base'
    run = false
    out = WSApplication.message_box(
    'You are currently editing the Base scenario, do you wish to continue?','OKCancel','Stop',false)
    if out == 'OK'
      run = true
    end
  end
  run
end

def make_scenario(factor)
  current_scenario = $net.current_scenario
  new_scenario = current_scenario + ' C' + factor.to_s
  
  $net.add_scenario(new_scenario,nil,'')
  $net.current_scenario = new_scenario
  new_scenario
end

def check_input(factor)
  run = true
  # Warning if less than 1 node is selected
  if $ro.length() < 1
        WSApplication.message_box('Warning: no subcatchments were selected, ending script','OK','!',false)
        run = false
  end

  if !(factor.is_a?(Float) && factor > 0 && factor < 1)
        WSApplication.message_box('Warning: the factor must be a float between 0 and 1','OK','!',false)
        run = false
  end
  run
end

def total_era()
  # This function determines the total and the flexible effective runoff area
  total_era = 0
  flexi_era = 0
  
  $ro.each do |subs|
    # Get land use id
    land_use_id = subs.land_use_id
    
    # Get the row corresponding to the Land Use ID
    land_use_table = $net.row_object('hw_land_use', land_use_id)
    
    # Itterate over all runoff surfaces and add area to group area  
    (1..12).each do |i|
      # Get runoff surface index from 12 runoff index columns in land use table
      runoff_index = land_use_table.send("runoff_index_#{i}")
      
      # Get Area and runoff factor for each runoff surface
      area = subs.send("area_absolute_#{i}")
      rc = $runoff_factor[runoff_index]
      
      # Add effective runoff area to total 
      if area && rc
        total_era += area * rc
      end
      
      # Add effective runoff area to flexi if runoff surface is flexi
      if area && rc && $flexi.include?(runoff_index)
        flexi_era += area * rc
      end 
    end
  end
  [total_era, flexi_era]
end

def depave_flexi_area(flexi_coeff)
  $ro.each do |subs|
    # Get land use id
    land_use_id = subs.land_use_id
    
    # Get the row corresponding to the Land Use ID
    land_use_table = $net.row_object('hw_land_use', land_use_id)
    
    # Itterate over all runoff surfaces and add area to group area  
    (1..12).each do |i|
      # Get runoff surface index from 12 runoff index columns in land use table
      runoff_index = land_use_table.send("runoff_index_#{i}")
      
      if $flexi.include?(runoff_index)
        area = subs.send("area_absolute_#{i}")   
        if area 
          new_area = area * flexi_coeff
          subs.send("area_absolute_#{i}=", new_area)
          subs.write
        end
      end
    end
  end
end

# Get factor from user
factor = Float(WSApplication.input_box("Define the depavement factor: ","Define a depavement factor between 0 and 1:",''))

# Check input and run script
if check_input(factor)
  
  #Make a new scenario
  new_scenario = make_scenario(factor)
  
  # Create runoff factor hash
  $runoff_factor = Hash.new
  $net.row_object_collection('hw_runoff_surface').each do |rs|
    $runoff_factor[rs.runoff_index] = rs.runoff_coefficient
  end
  
  # Start a transaction to edit the data
  $net.transaction_begin
  
  # Get total and flexi effective runoff area (era) and calculate new flexi constant
  total_era, flexi_era = total_era()
  flexi_coeff = 1 - (1 - factor)*total_era/flexi_era
  puts("Orginal effective runoff area = #{total_era}, original flexi effective runoff area = #{flexi_era}")
  
  # Depave Flexi area
  depave_flexi_area(flexi_coeff)
  new_total_era, = total_era()
  depaved_coeff = new_total_era / total_era
  puts("New effective runoff area = #{new_total_era}")
  puts("Depaved factor = #{depaved_coeff}")
  
  # Commit changes and inform user
  $net.validate(new_scenario)
  $net.clear_selection
  $net.transaction_commit
  
  output_text = "Added a new depaved scenario #{new_scenario}. \n The effective runoff area of the selected catchments has been reduced with a reduction factor of #{factor}"
  
  WSApplication.message_box(output_text,'OK','Information',false)
  $net.commit(output_text)
end
