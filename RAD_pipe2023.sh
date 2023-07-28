#!/bin/bash
#$ -M dbruzzes@nd.edu
#$ -m abe
#$ -r y
#$ -pe smp 24
#$ -q long
#$ -N DB3AL1


# dan bruzzese - cite upcoming paper
####### this pipeline trims sequencing adapters. quality filters. Trims again. Then demultiplex, map reads to ref genome, identifies optical duplicates and assigns RGs
# need to add SNP calling and filtering
# works with New 2023 ND RAD adatpers 
# need to have a barcode fasta file with the header containing no spaces



mamba activate fastp 

############################ variables to change ###########################################
THREAD="24"
REF_GENOME="/afs/crc.nd.edu/user/d/dbruzzes/rhago/Nanopore/Rhagoletis_pomonella_Dovetail_chicago_HiC_min1kb_noBegEndN_dedupe95_vecclean_min1kb_noWolb.fasta"
BARCODE1="/afs/crc.nd.edu/user/d/dbruzzes/dbruzzes/DanAndrewNichelleRADs/barcodes/DB3_Al4_ecoR1_barcode_R1.fasta"
# barcodes are in fasta format
READ1="/afs/crc.nd.edu/group/rhago/osmanthi/CMG_DanAndrewMichelle2023/ILMN_1734_Stephens_ND_DNAseq_May2023/GBCF-DB-1666_i7_UDP033_S4_L004_R1_001.fastq.gz"
READ2="/afs/crc.nd.edu/group/rhago/osmanthi/CMG_DanAndrewMichelle2023/ILMN_1734_Stephens_ND_DNAseq_May2023/GBCF-DB-1666_i7_UDP033_S4_L004_R2_001.fastq.gz"
NAME="DB3AL1"
############################################################################################################


######### start in current directory
DIR=$(pwd)
cd ${DIR}
######################


################## make adapter files for triming ###################################
# fastp_adapter.fasta

# UPD NEW v4 Read1 adapter readthrough and mesI and protector bases
printf ">Illumina_R1_adapterReadthru\nTTAGTAGATCGGAAGAGCACACGTCTGAACTCC\n" > fastp_adapter.fasta

# read2 adapter readthrough
printf ">truueseq_read2_adapterReadthru\nAGATCGGAAGAGCGTCGTGTAGGGAA\n" >> fastp_adapter.fasta 

# polyA tail 
printf ">polyA\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n" >> fastp_adapter.fasta


# flexbar adapter files 
# flexbar_adapter1.fasta (trim ecoR1 and protector base read2 readthrough)
printf ">tailcrop_read2\nGAATTG\n" > flexbar_adapter1.fasta

# flexbar_adapter2.fasta ( trims ecoR1 from R1 after demultiplex- C is padded follwing with ecoI cutsite)
printf ">headcrop_read1\nCAATTC\n" > flexbar_adapter2.fasta

###############********* 1- fastp trim raw rad reads ********************************

# do i trim with a sliding window - turning low q bases into N?
fastp --thread $THREAD -q 20 -l 35 -g --in1 ${READ1} --in2 ${READ2} --out1 trim1.${NAME}_READ1.fq.gz --out2 trim1.${NAME}_READ2.fq.gz --adapter_fasta fastp_adapter.fasta \
--html "${NAME}.fastpReport.html" --trim_front2 5
echo "***************quality filtered and removed adapter from raw reads***************************"

######################*********** 2 -flexbar trim and demultiplex ********************
mamba activate flexbar 

READ1="trim1.${NAME}_READ1.fq.gz"
READ2="trim1.${NAME}_READ2.fq.gz"

flexbar -n ${THREAD} -r ${READ1} -p ${READ2} -t ${NAME}.trim2 --adapters flexbar_adapter1.fasta -ao 2 -ae 0.2 --adapter-trim-end RTAIL --adapter-tail-length 16 --zip-output GZ
echo "***********************************flexbar trim1****************************************"

mkdir demux
cd demux 

flexbar -n ${THREAD} -r ../${NAME}.trim2_1.fastq.gz -p ../${NAME}.trim2_2.fastq.gz -t demux --barcodes ${BARCODE1} --barcode-trim-end LTAIL -be 0.2 --barcode-unassigned \
--adapters ../flexbar_adapter2.fasta -ao 2 -ae 0.2 --adapter-trim-end LTAIL --min-read-length 30 --zip-output GZ

echo "*********************************demux reads**************************************************"


############################ fastq reports for each trimmed and demultiplexed sample ###########

mamba activate fastp 
mkdir fastp_report

for FILE in $(find *_1.fastq.gz | sed 's/_1.fastq.gz//'| sed 's/demux_barcode_//');
do fastp --thread $THREAD --in1 demux_barcode_${FILE}_1.fastq.gz --in2 demux_barcode_${FILE}_2.fastq.gz --html "${FILE}.fastpReport.html" --disable_adapter_trimming --disable_quality_filtering --disable_length_filtering ; done

mv *.html ./fastp_report

########################********* 3 - map reads to ref **************************
mamba activate mapping

bwa-mem2 index ${REF_GENOME}
# loop to map all demux fastq files to ref genome and drop unmapped reads and dedup reads 
mkdir mapped_reads
cd mapped_reads
mkdir dedup
for FILE in $(find ../*_1.fastq.gz | sed 's/_1.fastq.gz//'| sed 's/\.\.\///' | sed 's/demux_barcode_//');
do bwa-mem2 mem -t ${THREAD} ${REF_GENOME} ../demux_barcode_${FILE}_1.fastq.gz ../demux_barcode_${FILE}_2.fastq.gz | samtools view -Sbh -q 20 -F 0x4 - --threads ${THREAD} | \
samtools fixmate --threads ${THREAD} -m - - | samtools sort --threads ${THREAD} - -o ${FILE}.mapped.sort.bam;
samtools markdup --threads ${THREAD} ${FILE}.mapped.sort.bam ${FILE}.mapped.sort.dedup.bam;
mv ${FILE}.mapped.sort.dedup.bam ./dedup;
done

echo "************************mapped reads to ref and deduplicated them****************************"

#############################************** 4- sticks on RG info *********************
cd ./dedup
mkdir RG
for FILE in $(find *.mapped.sort.dedup.bam | sed 's/.mapped.sort.dedup.bam//'| sed 's/demux_//'); 
do echo $FILE; 
RG="@RG\tID:${FILE}_${NAME}\tSM:${FILE}\tPL:ILLUMINA"; 
echo ${RG}; 
samtools addreplacerg ${FILE}.mapped.sort.dedup.bam -r ${RG} --threads ${THREAD} -o ${FILE}.rg.dd.map.bam; #works
samtools view -H ${FILE}.rg.dd.map.bam | grep "@RG";
mv ${FILE}.rg.dd.map.bam ./RG; done 

echo "*****************************added read group info to each bam file*************************************"
echo "DONE YEEES!!!!!!"





freebayes -b cat-RRG.bam -t mapped.$1.bed -v raw.$1.vcf -f reference.fasta -m 5 -q 5 -E 3 --min-repeat-entropy 1 -V --populations popmap -n 10 -F 0.1 &> fb.$1.error.log

# remove -t , -V 
# -n 10 reduces memory
# -F also reduces memory
