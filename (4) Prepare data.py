# -*- coding: utf-8 -*-
"""
Created on Mon Apr  7 22:17:31 2025

@author: lukas
"""

#%%---------------------------------------------------------------------------
# INITIATE SCRIPT
#-----------------------------------------------------------------------------

import wizard as wz
import os
import time

start = time.time()

# ID (column name) of the column with the throughflow data in the ds_flow files
overflow_ID = 'LINK_ID'

#%%---------------------------------------------------------------------------
# IMPORT SIMULATION RESULTS
#-----------------------------------------------------------------------------

# In Infoworks do: Resultaten -> CSV export
#       Selection with all nodes, links and subs -> export volume
#       Selection with CSO link -> export ds_flow

# Folder path where CSV files are located
folder_path = 'INPUT_PATH'
output_path = 'OUTPUT_PATH'

## Get input and control values by summarizing hydrodynamic result files
volume = wz.summarize_series(folder_path, 'volume')
overflow = wz.summarize_series(folder_path, 'overflow', overflow_ID)

name = wz.get_clean_name(folder_path)

volume.to_csv(os.path.join(output_path, "volume " + name), index=False)
overflow.to_csv(os.path.join(output_path, "overflow " + name), index=False)

end = time.time()
print(f" The script took {end - start} seconds to run")