import os
import shutil
import re

# Define the source folders and the destination folder
source_folders = ['mahbu1141503', 'Mahbu1149534', 'Mahbu1224557', 'Mahbu1267555']
# source_folders = ['A', 'B', 'C']
destination_folder = '2023'

def copyTargetFiles(source_folders, destination_folder):
    """
    Copies files matching a specific naming convention from multiple source folders to a destination folder.

    This function searches through the specified source folders for files that match the naming
    convention 'st4_conus.2023MMDDHH.01h.grb2.gz' where '2023MMDDHH' is any valid date and hour of 2023.
    Matched files are then copied to the destination folder.

    Parameters:
    - source_folders (list of str): List of source folder paths to search for files.
    - destination_folder (str): Path to the destination folder where matched files will be copied.

    Example Usage:
    --------------
    source_folders = ['A', 'B', 'C']
    destination_folder = 'F'
    copyTargetFiles(source_folders, destination_folder)
    """

    # Create the destination folder if it doesn't exist
    if not os.path.exists(destination_folder):
        os.makedirs(destination_folder)

    # Define the regex pattern for the naming convention
    pattern = re.compile(r'^st4_conus\.2023\d{6}\.01h\.grb2\.gz$')

    # Iterate over each source folder
    for folder in source_folders:
        print(f"Checking folder: {folder}")
        for filename in os.listdir(folder):
            print(f"Found file: {filename}")
            if pattern.match(filename):
                print(f"Matched file: {filename}")
                # Construct the full file paths
                source_file = os.path.join(folder, filename)
                destination_file = os.path.join(destination_folder, filename)
                print(f"Copying from {source_file} to {destination_file}")
                
                # Copy the file to the destination folder
                shutil.copy2(source_file, destination_file)

    print("Files copied successfully.")

# Example usage
copyTargetFiles(source_folders, destination_folder)