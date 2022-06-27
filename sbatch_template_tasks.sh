#!/bin/bash

###################################
# Run multiple tasks concurrently #
# in a single sbatch job          #
###################################

# Lines that begin with #SBATCH specify commands to be used by SLURM for scheduling. They are not comments.
#SBATCH --qos=medium                 
#SBATCH --ntasks=3

# Run any commands necessary to setup your environment:
source /etc/profile.d/modules.sh                            # Use this to add module to the path of compute nodes.
module load Python3/3.9.6
source $(conda info --base)/etc/profile.d/conda.sh          # Use if conda is already on your path but you still need to run "conda init <shell_name>"       
conda activate base

# Use srun to add/override slurm args. Tasks can be run concurrently if you specify"--exclusive --ntasks=1". 
# "--exclusive" indicates each step should run on its own CPU and "--ntasks=1" is needed because otherwise srun inherits "--ntasks=3" from #SBATCH and using that
# in all the steps makes 9 total tasks when only 3 were allocated for our job. 
srun --exclusive --ntasks=1 bash -c "hostname; sleep 12; python3.9 --version;" &    # using an '&' will background the process allowing them to run concurrently.
srun --exclusive --ntasks=1 bash -c "hostname; sleep 10; python3 --version;" &     
srun --exclusive --ntasks=1 echo $CONDA_DEFAULT_ENV &                               # $CONDA_DEFAULT_ENV shows the activated env                  
wait                                                                                # Wait is required to allow any background processes to complete.
