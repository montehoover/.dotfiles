#!/bin/bash

##################################
# Run multiple jobs concurrently #
##################################

# Lines that begin with #SBATCH specify commands to be used by SLURM for scheduling. They are not comments.
#SBATCH --qos=medium              
#SBATCH --array=1-5:1                                       # Iterations: <start>-<stop>:<step size>. 
                                                            # The "i" number can be accessed with ${SLURM_ARRAY_TASK_ID}.

# Run any commands necessary to setup your environment:
source /etc/profile.d/modules.sh                            # Use this to add module to the path of compute nodes.
module load Python3/3.9.6
source $(conda info --base)/etc/profile.d/conda.sh          # Use if conda is already on your path but you still need to run "conda init <shell_name>"       
conda activate base

# Use srun to run job steps.
srun bash -c "echo ${SLURM_ARRAY_TASK_ID}" 
