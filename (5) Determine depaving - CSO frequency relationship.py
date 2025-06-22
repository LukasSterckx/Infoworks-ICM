# -*- coding: utf-8 -*-
"""
Created on Mon Apr  7 22:17:31 2025

@author: lukas
"""

#%%---------------------------------------------------------------------------
# INITIATE SCRIPT
#-----------------------------------------------------------------------------

import os
import wizard as wz
import results_plot as rp
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression

# ID (column name) of the column with the throughflow data in the ds_flow files
overflow_ID = 'NODE_ID_OVERFLOW'

# Define the start time of the simulation for plotting
start_simulation = '2024-04-01T00:00:00.000+02:00'

# Define thresholds for event separation
volume_threshold = 4000 # Minimum volume in CSO catchment for which an event is considered a storm. Depends on the catchment and should thus be adjusted
overflow_threshold = 0.001 # Minimum overflow discharge for which an event is considered an overflow event. Better keep a bit above 0 because of numerical instability

#Define catchment properties
effective_runoff_area = 101 #hectares # Equals the runoff area times the runoff coefficient 
runoff_coefficient = 0.8 

# Number of years simulated
n_years = 9 

#%%---------------------------------------------------------------------------
# IMPORT SIMULATION RESULTS
#-----------------------------------------------------------------------------

# Define Paths
folder_path = 'OUTPUT_PATH' # Use path to the output of script "(4) Prepare data.py"
rainfall_path = 'PATH_TO_RAINFALL_DATA' #Rainfall data only used for plotting

# Read output from script "(4) Prepare data.py"
volume = wz.read_data(folder_path, 'volume')
overflow = wz.read_data(folder_path, 'overflow')

# Read rainfall data
start = volume.index.min()
end = volume.index.max()
rainfall = wz.read_rainfall_Ukkel(rainfall_path, start, end)
# IMPORTANT, WHEN USING DRY WEATHER FLOW MODE IN INFOWORKS ICM, THE TIMESTEPS WILL NOT ALWAYS MATCH

#%%---------------------------------------------------------------------------
# DETERMINE DRY WEATHER FLOW
#-----------------------------------------------------------------------------

DWF = volume.median()

# Check if Dry Weather Flow is given by the median
plt.boxplot(volume)
plt.ylim(bottom = 0.5*DWF , top = 1.5*DWF)
plt.show()

#%%---------------------------------------------------------------------------
# DETERMINE CAPACITY VOLUME
#-----------------------------------------------------------------------------
time_frame = 3600 
rp.plot_storage_vs_rainfall(volume, overflow, rainfall, volume_threshold, overflow_threshold, time_frame)
stat_events = rp.plot_storage_vs_rainfall(volume, overflow, rainfall, volume_threshold, overflow_threshold, time_frame, mode = 'total rainfall')

# Plot overflow start, peak and end volume in function of max overflow discharge
end_storage = rp.plot_max_storage_continous(volume, overflow, volume_threshold, overflow_threshold)


#%%---------------------------------------------------------------------------
# CALCULATE DEPAVEMENT
#-----------------------------------------------------------------------------

# Sort Events and determine threshold volume and the Q5 and Q95 quantiles of the threshold volume. 
end_storage = end_storage.sort_values()[:n_years*2]
V_cap_min = end_storage.quantile(0.05)
V_capacity = end_storage.median()
V_cap_max = end_storage.quantile(0.95)

# Calculate the factor by which the volume peak should be reduced to not exceed the threshold volume.
overflow_events = stat_events[stat_events['max_overflow'] > overflow_threshold]
overflow_events['F'] = (V_capacity - DWF) / (overflow_events['max_volume'] - DWF)
overflow_events['Fmin'] = (V_cap_min - DWF) / (overflow_events['max_volume'] - DWF)
overflow_events['Fmax'] = (V_cap_max - DWF) / (overflow_events['max_volume'] - DWF)

# Calculate the depaved areas correspoding to these factors
overflow_events['dA'] = (1-overflow_events['F']) * effective_runoff_area / runoff_coefficient
overflow_events['dAmin'] = (1-overflow_events['Fmin']) * effective_runoff_area / runoff_coefficient
overflow_events['dAmax'] = (1-overflow_events['Fmax']) * effective_runoff_area / runoff_coefficient

# Sort Events by area size and add a new column for the CSO frequency
overflow_events.sort_values(by = ['dA'], inplace = True)
overflow_events["frequency"] = None

# Plot the depaved/decoupled area and the resulting CSO frequency
plt.figure(figsize=(0.6*8,0.6*7), dpi=300)
for i in range(len(overflow_events['dA'])):
    x = overflow_events['dA'].iloc[i]
    CI = [overflow_events['dAmin'].iloc[i], overflow_events['dAmax'].iloc[i]]
    y = (len(overflow_events['dA']) - i)/n_years
    overflow_events['frequency'].iloc[i] = y
    plt.plot(CI, [y, y], color = 'grey', label = "Q5 - Q95 interval")
    plt.scatter(x, y, color = 'blue', label = "V threshold")
plt.xlabel("Depaved or decoupled area (ha)")
plt.ylabel("Number of overflow events per year")

plt.show()

#%%---------------------------------------------------------------------------
# LINEAR REGRESSION
#-----------------------------------------------------------------------------

# Check the last figure for outliers and remove them
df_slope = overflow_events[1:-3] #no outliers

# Calculate the slope of the area--CSO frequency relationship (without outliers)
for dA in ['dAmin', 'dA', 'dAmax']:
    # Step 1: Prepare your data (X needs to be 2D for scikit-learn)
    X = df_slope['frequency'].values.reshape(-1, 1)  # Independent variable, reshaped to 2D
    Y = df_slope[dA].values  # Dependent variable
    
    # Step 2: Create a LinearRegression model
    model = LinearRegression()
    
    # Step 3: Fit the model
    model.fit(X, Y)
    
    # Step 4: Get the slope (coefficient) and R²
    slope = model.coef_[0]  # The slope of the line
    r_squared = model.score(X, Y)  # R² value
    
    # Display the results
    print(dA + f":   Slope: {slope},   R²: {r_squared}")
