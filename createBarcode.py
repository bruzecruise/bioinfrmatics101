#!/bin/python

# load libs
import sys
import pandas as pd

# script to turn CSV file into barcode file for demultiplex of ddRAD data
# input 1 = csv file with sampleID and barcode string in two columns ("ID" and "barcodeR1")
# input 2 = name of barcode file ("string")
# run with: python createBarcode.py input_csv output_fasta_name

# load in csv with ID and barcodeR1 columns
data = sys.argv[1]
df = pd.read_csv(data)

# open barcode fasta file
name = sys.argv[2]
#ecoR1_barcode = open("ecoR1_barcode_R1.fasta", "w")
ecoR1_barcode = open(f'{name}.ecoR1_barcode_R1.fasta', 'w')


# loop through and write fasta file in proper format
for index, row in df.iterrows():
    ecoR1_barcode.write(">" + row['ID'] + "\n" + row['barcodeR1'] + "\n")

# close barcode file
ecoR1_barcode.close()

print("done writing barcode file for " + name)
