#!/bin/bash

###########################
# Run a single sbatch job #
###########################

# Lines that begin with #SBATCH specify commands to be used by SLURM for scheduling. They are not comments.
# The defaults are all reasonable for small jobs and debugging except that they don't include a gpu. (See below)
#SBATCH --qos=medium                 

# Run any commands necessary to setup your environment:
source /etc/profile.d/modules.sh                            # Use this to add module to the path of compute nodes.
module load Python3/3.9.6
source $(conda info --base)/etc/profile.d/conda.sh          # Use if conda is already on your path but you still need to run "conda init <shell_name>"       
conda activate base

# Run the job steps.
hostname
python3.9 --version
echo $CONDA_DEFAULT_ENV                                     # $CONDA_DEFAULT_ENV shows the activated env
           
# Once the end of the batch script is reached your job allocation will be revoked (resources freed).
# Call this from a submission node with "sbatch sbatch_template.sh"

# To run this directly instead of using an sbatch script, use "srun":
# srun --qos=medium bash -c "hostname && python3.9 --version && echo $CONDA_DEFAULT_ENV"
# - or - to run interactively use "srun --pty":
# srun --pty --qos=medium bash

# SLURM defaults that you might want to change:
# #SBATCH --qos=default                 # The qos parameter doesn't actually have a default - you must specify it. See resources available for each qos below.
# #SBATCH --partition=dpart             # You must add "--partition=scavenger" if you choose "--qos=scavenger"
# #SBATCH --account=vulcan              # You must add "--account=<faculty name>" if you choose "--qos=high"
# #SBATCH --time=0-01:00:00             # Time to reserve for your job. If your job ends before this the resources will be freed. Format=d-hh:mm:ss
# #SBATCH --mem=8gb                     # For point2mesh runs I needed 32gb in the max cases.
# #SBATCH --gres=gpu:0                  # Specify how many GPUs and of why type. Ex: gpu:p6000:1, gpu:gtx1080ti:1, gpu:rtx2080ti:1, gpu:rtxa6000:1
# #SBATCH --ntasks=1                    # Use this to run concurrent commands. If you set "--ntasks=2" you must set "--ntasks=1" down below with srun.
# #SBATCH --array=1-1:1                 # Use this to run concurrent jobs.
# #SBATCH --job-name=sbatch_template    # Takes the name of this script as the job name by default.
# #SBATCH --output="slurm-%j.out"       # indicates a file to redirect STDOUT to; %j is the jobid. Must be set to a file instead of a directory or else submission will fail.
# #SBATCH --error="slurm-%j.out"        # indicates a file to redirect STDERR to; %j is the jobid. Must be set to a file instead of a directory or else submission will fail.

# $ show_qos
#             Name     MaxWall MaxJobs                        MaxTRES     MaxTRESPU   Priority
# ---------------- ----------- ------- ------------------------------ ------------- ----------
#           normal                                                                           0
#           medium  3-00:00:00       2       cpu=8,gres/gpu=2,mem=64G                        0
#             high  1-12:00:00       2     cpu=16,gres/gpu=4,mem=128G                        0
#          default  7-00:00:00       2       cpu=4,gres/gpu=1,mem=32G                        0
#        scavenger  3-00:00:00             cpu=32,gres/gpu=8,mem=256G                        0
#            janus  3-00:00:00            cpu=32,gres/gpu=10,mem=256G                        0
#           exempt  7-00:00:00       2     cpu=32,gres/gpu=8,mem=256G                        0
#            class    12:00:00       1       cpu=4,gres/gpu=1,mem=32G                        0
#              cpu  2-00:00:00       1                cpu=1024,mem=4T                        0
#        exclusive 30-00:00:00                                                               0
#           sailon  3-00:00:00             cpu=32,gres/gpu=8,mem=256G   gres/gpu=48          0

# $ show_nodes -p dpart #vulcan
# NODELIST             CPUS       MEMORY     AVAIL_FEATURES            GRES                             STATE      PARTITION
# brigid[00-15]        64         257757     Opteron,6274,rhel7        (null)                           idle       dpart*
# vulcan[00-07]        32         257566     Xeon,E5-2683,rhel8        gpu:p6000:8                      mix        dpart*
# vulcan[08-23]        32         257566     Xeon,E5-2683,rhel8        gpu:gtx1080ti:8                  mix        dpart*
# vulcan24             32         128519     Zen,7282,rhel8            gpu:rtxa6000:4                   mix        dpart*

# $ show_nodes -p tron #nexus
# NODELIST             CPUS       MEMORY     AVAIL_FEATURES            GRES                             STATE      PARTITION
# tron[00-05]          32         257540     rhel8,AMD,EPYC-7302       gpu:rtxa6000:8                   idle       tron*
# tron[06-45]          16         128520     rhel8,AMD,EPYC-7302P      gpu:rtxa4000:4                   mix        tron*
# tron[46-61]          16         257539     rhel8,AMD,EPYC-7302       gpu:rtxa5000:8                   mix        tron*

# $ show_nodes -p dpart #cml
# NODELIST             CPUS       MEMORY     AVAIL_FEATURES            GRES                             STATE      PARTITION
# cml[00-16]           32         353837     Xeon,4216                 gpu:rtx2080ti:8                  alloc      dpart*
# cml[17-24]           32         257545     Zen,EPYC-7282             gpu:rtxa4000:8                   mix        dpart*
