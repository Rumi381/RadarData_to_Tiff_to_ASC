#####################################################################################
####$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$####
####$$$                                                                       $$$####
####$$$ Function for processing radar data (ST4 .z files) to GSSHA Preci file $$$####
####$$$                                                                       $$$####
####$$$               Prepared by Md Jalal Uddin Rumi                         $$$####
####$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$####
#####################################################################################

### Load necessary libraries
### parallel and doSNOW will help to process the data using parallel processing if your PC has multiple processors, 
### this will greatly reduce the processing time.

library(raster)
library(rgdal)
library(XML)
library(data.table)
library(parallel)
library(doSNOW)
library(dplyr)

###############################
### INPUT VARIABLES by the User
###############################

# Set the working directory to be the same as the file location
setwd(dirname(rstudioapi::getSourceEditorContext()$path))  #### this sets the working directory to be the same as the file location

# Timeframe to be processed

start_year<- 2023   ## Start of the year 
end_year  <- 2023   ## End of the year. If processing multiple years, otherwise put both of them the same for only one year processing

# Root directory for the radar data
# The directory of the radar raw data files like "ST4.2008010101.01h.Z" or "ST4.2008010101.01h.gz" or "st4_conus.2020123107.01h.grb2".
# The data must be arranged according to their year as shown in the sample Data directory.

root_dir<- paste0(getwd(),"/RAW DATA/")
number_of_processors<- 8   # Number of processors that will be used for parallel processing


# Output pixel size in decimal degrees

pixelsize<- 0.04     ## in decimal degrees

# Directory of a shapefile of the AOI (Area of Interest)
shape_dir <- "Texas_State_Boundary"  # Directory of the shapefile
shp_mask <- readOGR(dsn = shape_dir, layer = "Texas_State_Boundary")  # Name of the shapefile inside the directory
shp_mask <- spTransform(shp_mask, CRS("+init=epsg:4326 +proj=longlat +ellps=WGS84"))
plot(shp_mask)

# XML file name for WCT Batch configuration
xlm_file_name <- "wctBatchConfig_updated.xml"

###############################
### END OF INPUT VARIABLES
###############################


###########$$$$$$$$$$$$$$$$$$$ DONOT CHANGE ANYTHING BELOW THIS LINE $$$$$$$$$$$$$$$$$$$$$$#####


###############################
### START of PROCESSING RADAR DATA
###############################

# start date (mm-dd hh:min)

start_date<- "01-01 00:00"  
end_date<-  "12-31 23:00"

# Loop through each year in the range
for (qq in start_year:end_year){
  year<- qq
  
  # Function to expand the extent of the raster
  expand_ext<- function(ras,amount=0.5){
    require(raster)
    old_ext<- extent(ras)
    old_ext@xmin<-old_ext@xmin-amount
    old_ext@xmax<-old_ext@xmax+amount
    old_ext@ymin<-old_ext@ymin-amount
    old_ext@ymax<-old_ext@ymax+amount
    return(old_ext)
    
  }
  
  ext_crop<- expand_ext(shp_mask, amount=0.03)
  
  minLat<- ext_crop@ymin
  maxLat<- ext_crop@ymax
  minLon<- ext_crop@xmin
  maxLon<- ext_crop@xmax
  
  
  # Editing the XML file to capture the spatial extent
  xmlfile<-xmlParse(xlm_file_name)
  xmltop =xmlRoot(xmlfile)
  class(xmltop)#"XMLInternalElementNode" "XMLInternalNode" "XMLAbstractNode"
  xmlName(xmltop) #give name of node, PubmedArticleSet
  xmlSize(xmltop) #how many children in node, 19
  #xmlName(xmltop[[6]]) #name of root's children
  
  # <!-- 
  #   <minLat> 35.0 </minLat> 
  #   <maxLat> 36.0 </maxLat> 
  #   <minLon>-90.0 </minLon> 
  #   <maxLon> -91.0 </maxLon>
  #   -->
  #xmlValue(xpathApply(xmlfile,"//wctExportBatchOptions/grid/gridFilter/minLat")[[1]])= 37.0
  path<-xpathApply(xmlfile,"//wctExportBatchOptions/grid/gridFilter/minLat")[[1]]
  xmlValue(path)<- minLat
  path<-xpathApply(xmlfile,"//wctExportBatchOptions/grid/gridFilter/maxLat")[[1]]
  xmlValue(path)<- maxLat
  path<-xpathApply(xmlfile,"//wctExportBatchOptions/grid/gridFilter/minLon")[[1]]
  xmlValue(path)<- minLon
  path<-xpathApply(xmlfile,"//wctExportBatchOptions/grid/gridFilter/maxLon")[[1]]
  xmlValue(path)<- maxLon
  path<-xpathApply(xmlfile,"//wctExportBatchOptions/exportGridOptions/gridCellResolution")[[1]]
  xmlValue(path)<- pixelsize
  
  
  XML::saveXML(xmlfile, file="wctBatchConfig_edited.xml")
  
  
  # Extracting files and subsetting the dates
  
  start_date_arr<- paste0(year,"-",substr( start_date,start=1, stop=5 ), substring(start_date, first = 6) )
  end_date_arr<- paste0(year,"-",substr( end_date,start=1, stop=5 ), substring(end_date, first = 6) )
  days_event<- seq(
    from=as.POSIXct(start_date_arr, tz="GMT"),
    to=as.POSIXct(end_date_arr,  tz="GMT"),
    by="60 min" ) 
  radar_names_1<- paste0("ST4.", substr( days_event, start= 1, stop=13), ".01h.Z")
  radar_names_2<- paste0("ST4.", substr( days_event, start= 1, stop=13), ".01h.gz")
  radar_names_3<- paste0("st4_conus.", substr( days_event, start= 1, stop=13), ".01h.grb2.gz")
  radar_names_1<- gsub("-| ","", radar_names_1)
  radar_names_2<- gsub("-| ","", radar_names_2)
  radar_names_3<- gsub("-| ","", radar_names_3)
  
  radar_names<- c(radar_names_1,radar_names_2, radar_names_3)
  
  files_to_be_processed<- paste0(root_dir, year, "/", radar_names)
  
  
  filename_unique<- paste0("folder_", as.integer(Sys.time()),"_", round(runif(1, min=1000000, max=9999999))) 
  
  dir.create( filename_unique)
  sum(file.copy(from=files_to_be_processed, to=filename_unique))
  
  
  ######################################################################
  ###### Converting the files to geotiff and process them ##############
  ######################################################################
  
  files_input<- list.files(paste0(getwd(), "/", filename_unique))
  filename_unique_out<- paste0("folder_", as.integer(Sys.time()),"_", round(runif(1, min=1000000, max=9999999)))
  dir.create( filename_unique_out)
  
  radar_geotif<- function(input){
    dir<- gsub("/", "\\\\", getwd())
    wct_name<- paste0(dir,'\\wct-4.2.0-win32\\wct-4.2.0\\wct-export')
    inputfile<- paste0(dir,'\\',filename_unique,'\\',input)
    outputfile<- paste0(dir,'\\',filename_unique_out,'\\',gsub("\\.", "", input),'.tif')
    output_format<- 'tif32'
    xml_file<- paste0(dir,'\\wctBatchConfig_edited.xml')
    to_be_send<- paste0( '"',wct_name,'" "',inputfile,'" "', outputfile, '" "',output_format,'" "', xml_file,'"' )
    system(to_be_send)
  }
  
  # Setting up cluster for parallel processing
  
  NumberOfCluster <- number_of_processors
  total_number<- detectCores(all.tests = FALSE, logical = TRUE)
  cl <- makeCluster(min(NumberOfCluster,total_number-1))
  registerDoSNOW(cl)
  junk <- clusterEvalQ(cl,library(raster))
  
  clusterExport(cl, c("filename_unique", "filename_unique_out"))
  
  # Convert the binary data to geotiff file using NOAA tool wct-4.2.0-win32 tool
  xxx<- parLapply(cl,files_input, radar_geotif)
  
  
  # This while loop will try to find any missing files that are not converted and try to convert them in 10 loops
  files_orig <- list.files( filename_unique)
  xxx_names<- substr(gsub("\\.", "", files_orig), start = 1, stop = 16)
  files_prod<- list.files( filename_unique_out)
  yyy_names<- substr(gsub("\\.", "", files_prod), start = 1, stop = 16)
  compa_in_out<- setdiff( xxx_names,yyy_names)
  iii=0
  while (length(compa_in_out)!=0 & iii!=10){
    
    files_missed<- paste0(substr(compa_in_out, start = 1, stop = 3),".", substr(compa_in_out, start = 4, stop = 13),".",
                          substr(compa_in_out, start = 14, stop = 16),rep(substring(files_orig[1], first=19),length(compa_in_out)))
    parLapply(cl,(paste0(getwd(), "/", files_missed)), radar_geotif)
    files_orig <- list.files( filename_unique)
    xxx_names<- substr(gsub("\\.", "", files_orig), start = 1, stop = 16)
    files_prod<- list.files( filename_unique_out)
    yyy_names<- substr(gsub("\\.", "", files_prod), start = 1, stop = 16)
    compa_in_out<- setdiff( xxx_names,yyy_names)
    iii= iii+1
  }
  
  
  
  # Stop the cluster
  stopCluster(cl)
  
  # Move processed files to the OUTPUT directory
  dir.create( paste0("OUTPUT/", qq))
  
  file.copy(from=list.files(filename_unique_out,full.names = T), to=paste0(getwd(),"/OUTPUT/", qq), overwrite = TRUE)
  
  # Clean up temporary directories
  unlink(paste0(getwd(),"/",filename_unique_out), recursive = T)
  unlink(paste0(getwd(),"/",filename_unique), recursive = T)
  
}


# ===========================================================================================================================
# ===========================================================================================================================
# ===========================================================================================================================


###################################################################################################
####$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$####
####$$$                                                                                     $$$####
####$$$                 Converting the .tiff files into .asc files                          $$$####
####$$$                                                                                     $$$####
####$$$ This script will create separate year-specific folders for .asc files and convert   $$$####
####$$$               the .tiff files to .asc format for each year.                         $$$####
####$$$                                                                                     $$$####
####$$$                Prepared by Md Jalal Uddin Rumi                                      $$$####
####$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$####
###################################################################################################

# Load the necessary packages
#library(raster)
library(tools)
library(future)
library(furrr)
library(purrr)

# Set up parallel processing
plan(multisession, workers = 2)

# Specify the directory containing the TIFF files
tiff_dir <- paste0(getwd(),"/OUTPUT/")  # Update to the directory where .tiff files are located

# Function to process each TIFF file
process_tiff <- function(tiff_file, asc_dir) {
  raster_data <- raster(tiff_file)
  asc_file <- file.path(asc_dir, paste0(tools::file_path_sans_ext(basename(tiff_file)), ".asc"))
  writeRaster(raster_data, filename = asc_file, format = "ascii")
  return(asc_file)
}

# Function to handle errors and log them
handle_error <- function(result, tiff_file, failed_files) {
  if (inherits(result, "error")) {
    cat("Error processing file:", tiff_file, "\n")
    cat("Error message:", result$error$message, "\n\n")
    failed_files <<- append(failed_files, tiff_file)
  }
}

# Initialize a list to store the names of files that could not be processed
failed_files <- list()

# List all subdirectories in the directory (each subdirectory represents a year)
year_dirs <- dir(tiff_dir, full.names = TRUE, recursive = FALSE)

# Iterate over each year-specific directory
for (year_dir in year_dirs) {
  year <- basename(year_dir)  # Extract the year from the directory name
  
  # Create a new directory to store the .asc files for the current year
  asc_dir <- file.path(tiff_dir, "ASC", year)
  dir.create(asc_dir, recursive = TRUE)
  
  # List all .tiff files in the year-specific directory
  tiff_files <- list.files(year_dir, pattern = "\\.tif$", full.names = TRUE)
  
  # Use future_map to apply the function in parallel with error handling
  results <- future_map(tiff_files, safely(process_tiff), asc_dir = asc_dir)
  
  # Handle errors and log failed files
  walk2(results, tiff_files, handle_error, failed_files = failed_files)
}

# Log the names of files that could not be processed at all
if (length(failed_files) > 0) {
  cat("The following files could not be processed:\n")
  walk(failed_files, cat)
} else {
  cat("All files were processed successfully!\n")
}
