#!/bin/bash

#1      sed -i -e 's/\r$//' /lnx01_data2/shared/testdata/test_scripts/weeklyscript.sh
#2      chmod +x /lnx01_data2/shared/testdata/test_scripts/weeklyscript.sh
#3      scriptet kan nu køres når terminal åbnes ved input "source /weeklyscript.sh [date of the sequencing run 'YYMMDD']"



# script part which looks for a folder made today, if any start weekly script, else close terminal.    

#alternativt kan man starte ved at skrive en dato YYMMDD efter weeklyscript.sh i terminalen.


# Check if a date argument is provided, otherwise use today's date
if [ "$#" -eq 1 ]; then
    NUMBERS=$1  # Directly use provided date as YYMMDD
else
    current_year=$(date +"%Y")
    monitor_folder="/data/NGSruns/NovaSeq/${current_year}"
    new_folder_found=false

    today=$(date +"%y%m%d")  # Format date as YYMMDD for comparison
    echo "$today"
    # Check for a folder created today
    for folder in "${monitor_folder}"/*; do
        if [ -d "$folder" ]; then
            folder_name=$(basename "$folder")
            folder_date="${folder_name:0:6}"  # Extract YYMMDD from the start of the folder name

            if [ "$folder_date" == "$today" ]; then
                new_folder_found=true
                NUMBERS=$folder_date
                break  # Stop searching after the first match
            fi
        fi
    done

    # If no new folder is found, exit the script
    if [ "$new_folder_found" = false ]; then
        echo "No new folder found for today. Exiting script."
        exit 0
    fi
fi



# Initialize a flag to indicate whether the folder and samplesheet have been found
FOUND=0

while [ $FOUND -eq 0 ]; do

  # Define the base directory for folders and samplesheets
  CURRENT_YEAR=$(date +%Y)

  SAMPLE_SHEET_PATH="/data/NGSruns/NovaSeq/$CURRENT_YEAR/Samplesheet/"                                                          #base path til hvor samplesheet findes
  FOLDER_PATH="/data/NGSruns/NovaSeq/$CURRENT_YEAR"                                                                             #base path til hvor nova_runnet findes

  CRAM_FOLDER_PATH="/lnx01_data2/shared/dataArchive/lnx02/alignedData/hg38/novaRuns/$CURRENT_YEAR"                              #folder på lnx01_data3 "/lnx01_data3/storage/alignedData/hg38/novaRuns/$CURRENT_YEAR" #det er her hvor demultiplex gemmer filerne
  FASTQ_FOLDER_PATH="/lnx01_data2/shared/dataArchive/lnx02/fastqStorage/novaRuns" # fastq                                       #folder på lnx01_data3 "/lnx01_data3/storage/fastqStorage/novaRuns" #det er her hvor demultiplex gemmer filerne 
  
  BASE_DIR_AV1="/lnx01_data2/shared/patients/hg38/panels/$CURRENT_YEAR/"                                                        #base path hvor AV1 analyse startes
  BASE_DIR_MV1="/lnx01_data2/shared/patients/hg38/panels/MV1/"                                                                  #base path hvor MV1 analyse startes
  BASE_DIR_WGS_lnx02="/fast/data/WGS_weekly_out" #base path til lnx02/fast                                                      #base path hvor WGS_CNV analyse startes på lnx02
  BASE_DIR_WGS="/lnx01_data2/shared/patients/hg38/WGS_CNV"                                                                      #base path hvor WGS_CNV analyse startes på lnx01
  BASE_DIR_NGC_lnx02="/fast/data/NGC_WGS_local_novaRuns"
  BASE_DIR_WES_lnx02="/fast/data/WES" #base path til lnx02/fast                                                                 #base path hvor WES analyse startes
  Demulti_dir="/data/NGSruns/NovaSeq/$CURRENT_YEAR/Demultiplexing"                                                              #base path til folder hvor Demultiplexing starter fra

  # Find the directory and samplesheet that starts with the 6 numbers
  FOLDER=$(find $FOLDER_PATH -type d -name "${NUMBERS}*" -print -quit)
  SAMPLE_SHEET=$(find $SAMPLE_SHEET_PATH -type f -name "${NUMBERS}*.csv" -print -quit)

  #subdir 6 numbers corresponding to YYMMDD.
  SAMPLE_SHEET_NAME=$(basename "$SAMPLE_SHEET")
  SUBDIR_NAME="${SAMPLE_SHEET_NAME:0:6}"

  # Make directories from where the germlineNGS script starts (different for each NovaSeq run)
  NEW_DIR_AV1="${BASE_DIR_AV1}/${SUBDIR_NAME}"                                                                                  #unik mappe hvor AV1 analyse startes og gemmes
  NEW_DIR_MV1="${BASE_DIR_MV1}/${SUBDIR_NAME}"                                                                                  #unik mappe hvor MV1 analyse startes og gemmes
  NEW_DIR_WGS="${BASE_DIR_WGS}/${SUBDIR_NAME}"
  lnx02_DIR_WGS="${BASE_DIR_WGS_lnx02}/${SUBDIR_NAME}" # sted hvor WGS_CNV script eksekveres                                    #unik mappe hvor WGS_CNV analyse startes og gemmes på lnx02 serveren
  lnx02_DIR_NGC="${BASE_DIR_NGC_lnx02}/${SUBDIR_NAME}"
  lnx02_DIR_EV8_ALM_ONK="${BASE_DIR_WES_lnx02}/${SUBDIR_NAME}" #sted hvor WES script eksekveres                                 #unik mappe hvor WES analyse started og gemmes på lnx02 serveren


  # Initialize flags for found items
  FOLDER_FOUND=0
  SHEET_FOUND=0

  # Check if the folder was found
  if [[ -z "$FOLDER" ]]; then
    echo "Error: Unable to find folder starting with ${NUMBERS}"
  else
    echo "FOLDER found: $FOLDER"
    FOLDER_FOUND=1
  fi

  # Check if the samplesheet was found
  if [[ -z "$SAMPLE_SHEET" ]]; then
    echo "Error: Unable to find samplesheet starting with ${NUMBERS}"
  else
    echo "SAMPLE_SHEET found: $SAMPLE_SHEET"
    SHEET_FOUND=1
  fi

  # Check if both folder and samplesheet were found exit the loop
  if [ $FOLDER_FOUND -eq 1 ] && [ $SHEET_FOUND -eq 1 ]; then
    FOUND=1  # Set the FOUND flag to 1 to exit the loop
  else
    echo "Checking again in 30 minutes..."
    sleep 1800  # Wait for 30 minutes before retrying
  fi
done


############################################################################### ERRORS IN SAMPLESHEET ###############################################################################


if [ ! -d "$FOLDER" ] || [ ! -f "$SAMPLE_SHEET" ]; then
  echo "Error: Folder or Sample Sheet does not exist."
  exit 1
fi

# Find the line number where "Sample_ID" header is located
header_line_num=$(awk -F',' '/Sample_ID/{print NR; exit}' "$SAMPLE_SHEET")
((header_line_num++)) # Increment the header line number to start processing from the next line

# Check for space in 'Sample_ID' and 'Sample_Name' collumns
awk -v start_line="$header_line_num" -F ',' 'NR >= start_line {
  if ($1 ~ / /) {
    print "Space found in Sample_ID for sample: " $1
  }
  if ($2 ~ / /) {
    print "Space found in Sample_Name for sample: " $1
  }
}' "$SAMPLE_SHEET"

# Check if 'index' column has 8 or 10 characters for each entry
awk -v start_line="$header_line_num" -F ',' 'NR >= start_line {
  if (length($6) != 8 && length($6) != 10) {
    print "Invalid index length for sample: " $2 " Index: " $6
  }
}' "$SAMPLE_SHEET"

# Check for duplicate 'Sample_ID' entries
awk -v start_line="$header_line_num" -F ',' 'NR >= start_line {print $2}' "$SAMPLE_SHEET" | sort | uniq -d | while read -r sample_id; do
  echo "Duplicate Sample_ID found: $sample_id"
done

# Check for -A or -B before AV1
if grep -qE ".*-A-AV1.*|.*-B-AV1.*" "$SAMPLE_SHEET"; then
  echo "Error: Samplesheet contains invalid entries (-A-AV1 or -B-AV1)."
  exit 1
fi

########################################################### LOOP WHICH LOOKS FOR COPY COMPLETE FILE IN SEQUENCING FOLDER ###########################################################

echo "  "
# Initialize DNA and RNA flags as empty
DNA_FLAG=""
RNA_FLAG=""

# Check the samplesheet for "RV1" and "AV1"
if grep -q "RV1" "$SAMPLE_SHEET"; then
  DNA_FLAG="--RNA"
  echo "RNA found"
fi
if grep -Eq "AV1|WG4" "$SAMPLE_SHEET"; then
  RNA_FLAG="--DNA"
  echo "DNA found"
fi

WATCH_FILE="CopyComplete.txt"
FOUND=0
echo "  "
echo "Watching for ${WATCH_FILE} in the folder: ${FOLDER}"

# Loop for watching the CopyComplete.txt file
while [ $FOUND -eq 0 ]; do
  if [ -f "${FOLDER}/${WATCH_FILE}" ]; then
    echo "File: ${WATCH_FILE} found. Preparing to start Nextflow..."
    FOUND=1
  else
    echo "File: ${WATCH_FILE} not found in the folder. Last checked at $(date). Checking again in 30 minutes..."
    sleep 1800
  fi
done


# Now that the file is found, run demultiplexing with the optional flags



#on lnx01
#CMDDemulti="nextflow run KGVejle/demultiplex -r main --runfolder "${FOLDER}" --samplesheet "${SAMPLE_SHEET}" ${DNA_FLAG} ${RNA_FLAG}"
#export FOLDER SAMPLE_SHEET Demulti_dir CMDDemulti DNA_FLAG RNA_FLAG 
#gnome-terminal -- bash -c "source ~/.bashrc; cd ${Demulti_dir}; echo Running Nextflow...;  ${CMDDemulti}; exec bash"

#on lnx02
#REMOTE_DEMULTI_DIR="/fast/demultiplexing"
#CMDDemulti="nextflow run rasmuspausgaard/demultiplex -r main --runfolder '${FOLDER}' --samplesheet '${SAMPLE_SHEET}' ${DNA_FLAG} ${RNA_FLAG} --server lnx02 --keepwork"
#export FOLDER SAMPLE_SHEET REMOTE_DEMULTI_DIR CMDDemulti DNA_FLAG RNA_FLAG 
#gnome-terminal -- bash -c "source ~/.bashrc; cd ${REMOTE_DEMULTI_DIR}; ${CMDDemulti}; exec bash"

#on lnx02
REMOTE_DEMULTI_DIR="/fast/demultiplexing"
CMDDemulti="nextflow run KGVejle/demultiplex -r main --runfolder '${FOLDER}' --samplesheet '${SAMPLE_SHEET}' ${DNA_FLAG} ${RNA_FLAG} --keepwork --server lnx02"
export FOLDER SAMPLE_SHEET REMOTE_DEMULTI_DIR CMDDemulti DNA_FLAG RNA_FLAG 
gnome-terminal -- bash -c "source ~/.bashrc; cd ${REMOTE_DEMULTI_DIR}; ${CMDDemulti}"


#on lnx02
#REMOTE_DEMULTI_DIR="/fast/demultiplexing"
# Define the command to run remotely
#CMDDemulti="source ~/.bashrc; cd '$REMOTE_DEMULTI_DIR'; nextflow run KGVejle/demultiplex -r main --runfolder '${FOLDER}' --samplesheet '${SAMPLE_SHEET}' ${DNA_FLAG} ${RNA_FLAG} --server lnx02 --keepwork; exec bash"
#export FOLDER SAMPLE_SHEET CMDDemulti DNA_FLAG RNA_FLAG
#gnome-terminal -- ssh raspau@10.163.117.120 "$CMDDemulti"

############################################### CHECK CRAMFOLDER AND FASTQFOLDER USED IN NGS PIPELINE ###############################################

# Defines the first line after Sample Name
header_line_number=$(grep -n -m 1 "Sample_Name" "$SAMPLE_SHEET" | cut -d ':' -f 1)
data_line_num=$((header_line_number + 1))


# Function to check if a CRAM folder with the specified six-digit prefix exists
check_cram_folder() {
    # Ensure that a six-digit prefix is provided
    if ! [[ $NUMBERS =~ ^[0-9]{6}$ ]]; then
        echo "Invalid date prefix for cram folder: $NUMBERS. It must be a six-digit number."
        return 2 # Invalid prefix format
    fi

    folder=$(find "$CRAM_FOLDER_PATH" -type d -name "${NUMBERS}*" -print -quit)

    if [ -n "$folder" ]; then
        echo "Folder found: $folder"
        CRAM_FOLDER=$folder
        return 0 # Folder found
    else
        echo "Folder starting with $NUMBERS not found in $CRAM_FOLDER_PATH. Checking again in 15 minutes..."
        sleep 900
        return 1 # Folder not found
    fi
}

# Function to check if a FASTQ folder with the specified six-digit prefix exists
check_fastq_folder() {
    # Ensure that a six-digit prefix is provided
    if ! [[ $NUMBERS =~ ^[0-9]{6}$ ]]; then
        echo "Invalid date prefix for fastq folder: $NUMBERS. It must be a six-digit number."
        return 2 # Invalid prefix format
    fi

    fastq_folder=$(find "$FASTQ_FOLDER_PATH" -type d -name "${NUMBERS}*" -print -quit)

    if [ -n "$fastq_folder" ]; then 
        echo "Folder found: $fastq_folder"
        FASTQ_FOLDER=$fastq_folder
        return 0 # Folder found
    else
        echo "Folder starting with $NUMBERS not found in $FASTQ_FOLDER_PATH. Checking again in 15 minutes..."
        sleep 900
        return 1 # Folder not found
    fi
}


# Find the CRAM folder
until check_cram_folder; do : ; done
until check_fastq_folder; do : ; done

############################################################ germlineNGS loop ############################################################

# Create empty arrays for AV1, WG4, and MV1 samples
declare -a MV1_SAMPLES=()
declare -a AV1_SAMPLES=()
declare -a WG4_CNV_SAMPLES=()
declare -a EV8_ALM_ONK_SAMPLES=()
declare -a WG4_NGC_SAMPLES=()


# Read samples from the sample sheet and add them to the respective arrays
while IFS=, read -r full_sample_id other_columns; do
    # Use a regular expression to extract the unique identifier before the pipeline tag
    if [[ $full_sample_id =~ ^([^-]+)- ]]; then
        unique_identifier="${BASH_REMATCH[1]}"
    fi

    # Check if the full_sample_id contains AV1, WG4_CNV, MV1, or EV8_ALM/EV8_ONK and add it to the appropriate list
    if [[ "$full_sample_id" == *"MV1"* ]]; then
        MV1_SAMPLES+=("$unique_identifier")
    elif [[ "$full_sample_id" == *"AV1"* ]]; then
        AV1_SAMPLES+=("$unique_identifier")
    elif [[ "$full_sample_id" == *"WG4_CNV"* ]]; then
        WG4_CNV_SAMPLES+=("$unique_identifier")
    elif [[ "$full_sample_id" == *"WG4_NGC"* ]]; then
        WG4_NGC_SAMPLES+=("$unique_identifier")
    elif [[ "$full_sample_id" == *"EV8_ALM"* || "$full_sample_id" == *"EV8_ONK"* ]]; then
        EV8_ALM_ONK_SAMPLES+=("$unique_identifier")
    fi
done < <(tail -n +$data_line_num "$SAMPLE_SHEET")




# Function to check for .cram and .cram.crai files for AV1 and WG4_CNV samples
check_cram_crai_files() {
    sample=$1
    cram_file="${CRAM_FOLDER}/${sample}*.cram"
    crai_file="${CRAM_FOLDER}/${sample}*.cram.crai"

    if compgen -G "$cram_file" > /dev/null && compgen -G "$crai_file" > /dev/null; then
        return 0 # Both files exist
    else
        return 1 # One or both files are missing
    fi
}

# Function to check for R1 and R2 FASTQ files for MV1 samples
check_fastq_files() {
    sample=$1
    R1_files=($(compgen -G "${FASTQ_FOLDER}/${sample}*R1_001.fastq.gz"))
    R2_files=($(compgen -G "${FASTQ_FOLDER}/${sample}*R2_001.fastq.gz"))

    if [[ ${#R1_files[@]} -gt 0 && ${#R2_files[@]} -gt 0 ]]; then
        return 0 # Both files found
    else
        return 1 # One or both files are missing
    fi
}


# Function to execute the pipeline
execute_pipeline() {
    pipeline=$1
    case "$pipeline" in
        AV1)
            # Command to execute AV1 on lnx01
            CMDAV1="source ~/.bashrc; mkdir -p '$NEW_DIR_AV1'; cd '$NEW_DIR_AV1'; echo Running AV1 Nextflow pipeline...; nextflow run KGVejle/germlineNGS -r main --panel AV1 --cram ${CRAM_FOLDER} --server lnx01"
            export CRAM_FOLDER SAMPLE_SHEET CMDAV1 NEW_DIR_AV1
            gnome-terminal -- ssh raspau@10.163.117.64 "$CMDAV1" # Execute AV1 on lnx01 using SSH in a new GNOME terminal
            ;;
        WG4_CNV)
            # Execute locally on lnx02
            mkdir -p "$lnx02_DIR_WGS"
            CMDWGS="source ~/.bashrc; cd ${lnx02_DIR_WGS}; echo Running WGS_CNV Nextflow pipeline...; nextflow run KGVejle/germlineNGS -r main --panel WGS_CNV --cram ${CRAM_FOLDER} --server lnx02"
            export CRAM_FOLDER SAMPLE_SHEET CMDWGS lnx02_DIR_WGS
            gnome-terminal -- bash -c "$CMDWGS"
            ;;
        WG4_NGC) 
            # NGC samples locally on lnx02
            mkdir -p "$lnx02_DIR_NGC"
            CMDNGC="source ~/.bashrc; cd ${lnx02_DIR_NGC}; echo Running WGS_NGC Nextflow pipeline...; nextflow run rasmuspausgaard/germlineNGS -r main --panel NGC --cram ${CRAM_FOLDER} --server lnx02"
            export CRAM_FOLDER SAMPLE_SHEET CMDWGS lnx02_DIR_NGC
            gnome-terminal -- bash -c "$CMDNGC"
            ;;
        MV1)
            # Command to execute MV1 on lnx01
            CMDMV1="source ~/.bashrc; mkdir -p '$NEW_DIR_MV1'; cd '$NEW_DIR_MV1'; echo Running MV1 Nextflow pipeline...; nextflow run KGVejle/germlineNGS -r main --panel MV1 --fastq ${FASTQ_FOLDER} --fastqInput --server lnx01"
            export FASTQ_FOLDER SAMPLE_SHEET CMDMV1 NEW_DIR_MV1
            gnome-terminal -- ssh raspau@10.163.117.64 "$CMDMV1" # Execute MV1 on lnx01 using SSH in a new GNOME terminal
            ;;
        EV8_ALM_ONK)
            # Execute locally on lnx02
            mkdir -p "$lnx02_DIR_EV8_ALM_ONK"
            CMDEV8_ALM_ONK="source ~/.bashrc; cd ${lnx02_DIR_EV8_ALM_ONK}; echo Running EV8_ALM_ONK Nextflow pipeline...; nextflow run KGVejle/germlineNGS -r main --panel WES --cram ${CRAM_FOLDER} --server lnx02"
            export CRAM_FOLDER SAMPLE_SHEET CMDEV8_ALM_ONK lnx02_DIR_EV8_ALM_ONK
            gnome-terminal -- bash -c "$CMDEV8_ALM_ONK"
            ;;
    esac
}



# Flags to determine if the pipeline has already been run
av1_pipeline_run=false
wg4_cnv_pipeline_run=false
wg4_ngc_pipeline_run=false
mv1_pipeline_run=false
ev8_alm_onk_pipeline_run=false

# Main loop to check files for each sample type
while true; do
    all_av1_found=true
    all_wg4_found=true
    all_ngc_found=true
    all_mv1_found=true
    all_ev8_alm_onk_found=true
    
    for sample in "${AV1_SAMPLES[@]}"; do
        if ! check_cram_crai_files "$sample"; then
            all_av1_found=false
            break
        fi
    done
    
    for sample in "${WG4_CNV_SAMPLES[@]}"; do
        if ! check_cram_crai_files "$sample"; then
            all_wg4_found=false
            break
        fi
    done

    for sample in "${WG4_NGC_SAMPLES[@]}"; do
        if ! check_cram_crai_files "$sample"; then
            all_ngc_found=false
            break
        fi
    done
    
    for sample in "${MV1_SAMPLES[@]}"; do
        if ! check_fastq_files "$sample"; then
            all_mv1_found=false
            break
        fi
    done

    for sample in "${EV8_ALM_ONK_SAMPLES[@]}"; do
        if ! check_cram_crai_files "$sample"; then
            all_ev8_alm_onk_found=false
            break
        fi
    done
    
    # Execute pipelines if all samples are found and the pipeline has not been run yet
    if $all_av1_found && [[ ${#AV1_SAMPLES[@]} -gt 0 ]] && ! $av1_pipeline_run; then
        execute_pipeline "AV1"
        av1_pipeline_run=true
    fi
    
    if $all_wg4_found && [[ ${#WG4_CNV_SAMPLES[@]} -gt 0 ]] && ! $wg4_cnv_pipeline_run; then
        execute_pipeline "WG4_CNV"
        wg4_cnv_pipeline_run=true
    fi

    if $all_ngc_found && [[ ${#WG4_NGC_SAMPLES[@]} -gt 0 ]] && ! $wg4_ngc_pipeline_run; then
        execute_pipeline "WG4_NGC"
        wg4_ngc_pipeline_run=true
    fi
    
    if $all_mv1_found && [[ ${#MV1_SAMPLES[@]} -gt 0 ]] && ! $mv1_pipeline_run; then
        execute_pipeline "MV1"
        mv1_pipeline_run=true
    fi

    if $all_ev8_alm_onk_found && [[ ${#EV8_ALM_ONK_SAMPLES[@]} -gt 0 ]] && ! $ev8_alm_onk_pipeline_run; then
        execute_pipeline "EV8_ALM_ONK"
        ev8_alm_onk_pipeline_run=true
    fi
    
    # Exit the loop if all necessary pipelines have been executed or if the arrays are empty
    if ($av1_pipeline_run || [[ ${#AV1_SAMPLES[@]} -eq 0 ]]) &&
       ($wg4_cnv_pipeline_run || [[ ${#WG4_CNV_SAMPLES[@]} -eq 0 ]]) &&
       ($wg4_ngc_pipeline_run || [[ ${#WG4_NGC_SAMPLES[@]} -eq 0 ]]) &&
       ($mv1_pipeline_run || [[ ${#MV1_SAMPLES[@]} -eq 0 ]]) &&
       ($ev8_alm_onk_pipeline_run || [[ ${#EV8_ALM_ONK_SAMPLES[@]} -eq 0 ]]); then
        echo "All necessary pipelines have been executed."
        break
    fi

    echo "Not all files found. Waiting for 15 minutes before checking again..."
    sleep 900 # Wait for 15 minutes
done

exit 0


