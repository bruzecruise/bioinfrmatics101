#1/bin/bash
## tips and tricks for the crc

quota . # asks how much space you have in the current afs space (your personal, or one of the lab ones)
pan_df -h # shows how much space you have - needs to be used in your scratch space
nano # text editor 
nano .bashrc # edits bash configuration file (needs to be done in home directory)
source .bashrc # reloads config file (needs to be done in home directory)
alias rhago="/afs/crc.nd.edu/group/rhago" # add this to your .bashrc file as a shortcut 
cd rhago # goes to the feder shared afs space
cd /scratch365/name # location of afs space



