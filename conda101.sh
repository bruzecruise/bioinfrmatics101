#!/bin/bash

# conda is an easy way to install programs and their dependencies 
# below are some standard commands used to manage conda enviroments

# list conda enviroments
conda info --env 

# remove installed enviroment 
conda env remove --name foo

# create new enviroment 
conda create --name foo

# activate an enviroment 
conda activate foo

# deactivate an enviroment 
conda deactivavte 

# install a package and its dependencies to your active enviroment 
conda activate foo
conda install -c bioconda bar 

