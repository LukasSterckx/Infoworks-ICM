The following scripts were written as part of a project which aimed to size blue green measures--more specifically depaving and decoupling--to reduce combined sewer overflow (CSO) frequencies. The project used an Infoworks ICM database of the sewer network. Scripts 1-3 and 6 are run in Infoworks ICM using the Ruby API. Scripts 4 and 5 are run using python (e.g. sypder).
The following steps were carried out to map the sewer system:

1) Make a csv file with the CSO node IDs and custom labels
2) Label the CSO nodes in the Infoworks ICM database using "(1) Label nodes from csv.rb"
3) Map the CSO zones and mains connecting them using the script "(2) Map CSO zones.rb". The final zones and mains can be visualized in Infoworks ICM or for example by using QGIS.

Sizing depaving/decoupling projects was done for a single CSO. The following steps were carried out:
1) Run a simulation of the network using a composite storm
2) Determine the CSO catchment, this equals all subcatchments which contribute to the water depth at the CSO during a spill event and the conduits and nodes connecting them to the CSO node. 
3) Check if the CSO catchment contains external splits using "(3) Find upstream extrenal splits.rb". Consider if they play a big role--i.e. if a lot a water leaves the catchment via the external split. If yes, then this could cause problems in the rest of the analysis.
4) Run a simulation of the entire network using a long time-series.
5) Export the following results at every timestep to a csv file: the _volume_ in the CSO catchment conduits and nodes and the _ds_flow_ in the CSO conduit.
6) Use the "(4) Prepare data.py" and "(5) Determine depaving - CSO frequency relationship.py" scripts to prepare the data and determine the depavement/decoupling - CSO frequency relationship. The _effective runoff area_ needed in script (5) is outputed by script "(6) Reduce the effective runoff area of selection by a user defined factor.rb" (use temporarly a factor 1). 
7) Verify the result by virtualy depaving the catchment in Infoworks ICM using the "(6) Reduce the effective runoff area of selection by a user defined factor.rb" script. 
